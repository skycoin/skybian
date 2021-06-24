package imager

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"time"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/dialog"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/widget"
	"github.com/sirupsen/logrus"
	"github.com/skratchdot/open-golang/open"
	"github.com/skycoin/dmsg/cipher"

	"github.com/skycoin/skybian/pkg/boot"
	"github.com/skycoin/skybian/pkg/imager/widgets"
)

// ImgType indicates the OS the timage is being built for
type ImgType string

const (
	// TypeSkybian represents the OS skybian for orange prime
	TypeSkybian ImgType = "skybian"
	// TypeRaspbian represents the OS raspbian
	TypeRaspbian = "raspbian"
	// TypeRaspbian64 represents the 64-bit OS raspbian64
	TypeRaspbian64 = "raspbian64"
	// TypeSkybianOPi3 represents the OS skybian for orange pi 3
	TypeSkybianOPi3 = "skybian-opi3"
)

// DefaultImgNumber is the default number of visor boot parameters to generate.
const DefaultImgNumber = 1

// FyneUI is a UI to handle the image creation process (using Fyne).
type FyneUI struct {
	log logrus.FieldLogger

	// Fyne parts.
	app fyne.App
	w   fyne.Window

	releases  map[ImgType][]Release
	locations []string

	imgType   ImgType
	wkDir     string
	imgLoc    string
	remImg    string
	fsImg     string
	gwIP      net.IP
	wifiName  string
	wifiPass  string
	socksPC   string
	imgNumber int
	hvImg     bool
	hvPKs     []cipher.PubKey
	bps       []boot.Params
}

// NewFyneUI creates a new Fyne UI.
func NewFyneUI(log logrus.FieldLogger, icon *fyne.StaticResource) *FyneUI {
	fg := new(FyneUI)
	fg.log = log
	// fg.assets = assets

	fg.locations = []string{
		"From remote server",
		"From local filesystem",
	}
	fg.resetPage2Values()

	fa := app.New()
	fa.SetIcon(icon)
	fg.app = fa

	w := fa.NewWindow("skyimager-gui")
	w.SetMaster()
	w.SetContent(fg.Page1())
	w.Resize(fyne.Size{Width: 800, Height: 600})
	fg.w = w
	fg.releases = make(map[ImgType][]Release)

	return fg
}

// Run shows and runs the Fyne interface.
func (fg *FyneUI) Run() {
	fg.w.ShowAndRun()
}

func (fg *FyneUI) listBaseImgs(t ImgType) ([]string, string) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
	defer cancel()

	title := "Please Wait"
	msg := "Obtaining base image releases from GitHub..."
	d := dialog.NewCustom(title, msg, widget.NewProgressBarInfinite(), fg.w)

	d.Show()
	rs, lr, err := ListReleases(ctx, t, fg.log)
	d.Hide()

	if err != nil {
		var message string
		if errors.Is(err, ErrNetworkConn) {
			message = "Network connection error. Please ensure that you are connected to the internet correctly."
		} else {
			message = err.Error()
		}
		widgets.ShowError(message, fg.w)
		return nil, ""
	}

	fg.releases[t] = rs
	return releaseStrings(rs), lr.String()
}

func (fg *FyneUI) generateBPS() (string, error) {
	prevIP := fg.gwIP
	bpsSlice := make([]boot.Params, 0, fg.imgNumber)
	hvPKs := fg.hvPKs
	visorsNumber := fg.imgNumber
	if fg.hvImg {
		visorsNumber--
		hvPK, hvSK := cipher.GenerateKeyPair()
		hvBps, err := boot.MakeHypervisorParams(fg.gwIP, hvSK, fg.wifiName, fg.wifiPass)
		if err != nil {
			return "", fmt.Errorf("boot_params[%d]: failed to generate for hypervisor: %v", len(bpsSlice), err)
		}
		prevIP = hvBps.LocalIP
		bpsSlice = append(bpsSlice, hvBps)
		hvPKs = append(hvPKs, hvPK)
	}
	for i := 0; i < visorsNumber; i++ {
		_, vSK := cipher.GenerateKeyPair()
		vBps, err := boot.MakeVisorParams(prevIP, fg.gwIP, vSK, hvPKs, fg.socksPC, fg.wifiName, fg.wifiPass)
		if err != nil {
			return "", fmt.Errorf("boot_params[%d]: failed to generate for visor: %v", len(bpsSlice), err)
		}
		prevIP = vBps.LocalIP
		bpsSlice = append(bpsSlice, vBps)
	}
	fg.bps = bpsSlice
	jsonStr, _ := json.MarshalIndent(bpsSlice, "", "    ") //nolint
	return string(jsonStr), nil
}

func (fg *FyneUI) build() {
	bpsSlice := fg.bps

	baseURL, err := releaseURL(fg.releases[fg.imgType], fg.remImg)
	if err != nil {
		err = fmt.Errorf("failed to find download URL for base image: %v", err)
		dialog.ShowError(err, fg.w)
		return
	}

	// Prepare builder.
	builder, err := NewBuilder(fg.log, fg.wkDir)
	if err != nil {
		dialog.ShowError(err, fg.w)
		return
	}

	// Final images to obtain.
	var imgs []string

	switch fg.imgLoc {
	case fg.locations[0]:
		ctx, cancel := context.WithCancel(context.Background())
		dlTitle := "Downloading Base Image"
		dlMsg := fg.remImg + "\n" + baseURL
		dlDialog := widgets.NewProgress(dlTitle, dlMsg, fg.w, cancel, "Cancel")

		dlDialog.Show()

		// Download section.
		dlDone := make(chan struct{})
		go func() {
			t := time.NewTicker(time.Second)
			for {
				select {
				case <-t.C:
					dlC, dlT := float64(builder.DownloadCurrent()), float64(builder.DownloadTotal())
					if pc := dlC / dlT; pc > 0 && pc <= 1 {
						dlDialog.SetValue(pc)
					}
				case <-dlDone:
					t.Stop()
					return
				}
			}
		}()
		err = builder.Download(ctx, baseURL)
		close(dlDone)
		dlDialog.Hide()
		if err != nil {
			if !errors.Is(err, errDownloadCanceled) {
				fg.log.Errorf("Error when downloading image %v", err)
				dialog.ShowError(err, fg.w)
			} else {
				fg.log.Info("Download canceled by user")
			}
			return
		}

		// Extract section.

		extDialog := dialog.NewCustom("Extracting Archive", builder.DownloadPath(), widget.NewProgressBarInfinite(), fg.w)
		extDialog.Show()
		err = builder.ExtractArchive()
		extDialog.Hide()
		if err != nil {
			dialog.ShowError(err, fg.w)
			return
		}

		imgs = builder.Images()
		fg.log.
			WithField("n", len(imgs)).
			WithField("imgs", imgs).
			Info("Obtained base images.")

		if len(imgs) == 0 {
			dialog.ShowError(errors.New("no valid images in archive"), fg.w)
			return
		}

	case fg.locations[1]:
		// TODO(evanlinjin): The following is very hacky. Please fix.
		f, err := os.Open(fg.fsImg)
		if err != nil {
			dialog.ShowError(fmt.Errorf("failed to open base image: %v", err), fg.w)
			return
		}
		imgs = append(imgs, fg.fsImg)
		builder.bImgs[fg.fsImg] = BaseImage{
			File:         f,
			MD5:          nil,
			SHA1:         nil,
			ExpectedMD5:  [16]byte{},
			ExpectedSHA1: [20]byte{},
		}

	default:
		err := errors.New("no base image selected")
		dialog.ShowError(err, fg.w)
		return
	}

	// Finalize section.
	finDialog := dialog.NewCustom("Building Final Images", builder.finalDir, widget.NewProgressBarInfinite(), fg.w)
	finDialog.Show()
	err = builder.MakeFinalImages(imgs[0], bpsSlice)
	finDialog.Hide()
	if err != nil {
		dialog.ShowError(err, fg.w)
		return
	}

	// Inform user of completion.
	createREADME(fg.log, filepath.Join(builder.finalDir, "README.txt"))
	cont := container.New(layout.NewVBoxLayout(),
		widget.NewLabel("Successfully built images!"),
		widget.NewLabel("Images are built to: "+builder.finalDir),
		widget.NewButton("Open Folder", func() { _ = open.Run(builder.finalDir) }), //nolint
		widget.NewLabel("To flash the images, use a tool such as balenaEtcher:"),
		widget.NewButton("Open URL", func() { _ = open.Run("https://www.balena.io/etcher") }), //nolint
	)
	dialog.ShowCustom("Success", "Close", cont, fg.w)
}
