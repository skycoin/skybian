package imager

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"fyne.io/fyne"
	"fyne.io/fyne/app"
	"fyne.io/fyne/dialog"
	"fyne.io/fyne/layout"
	"fyne.io/fyne/widget"
	"github.com/sirupsen/logrus"
	"github.com/skratchdot/open-golang/open"
	"github.com/skycoin/dmsg/cipher"

	"github.com/skycoin/skybian/pkg/boot"
)

// DefaultVisors is the default number of visor boot parameters to generate.
const DefaultVisors = 7

// FyneUI is a UI to handle the image creation process (using Fyne).
type FyneUI struct {
	log    logrus.FieldLogger
	assets http.FileSystem

	// Fyne parts.
	app fyne.App
	w   fyne.Window

	releases  []Release
	locations []string

	wkDir   string
	imgLoc  string
	remImg  string
	fsImg   string
	gwIP    net.IP
	socksPC string
	visors  int
	hvImg   bool
	hvPKs   []cipher.PubKey
	bps     []boot.Params
}

// NewFyneUI creates a new Fyne UI.
func NewFyneUI(log logrus.FieldLogger, assets http.FileSystem) *FyneUI {
	fg := new(FyneUI)
	fg.log = log
	fg.assets = assets

	fg.locations = []string{
		"From remote server.",
		"From local filesystem.",
	}
	fg.resetPage2Values()

	fa := app.New()
	fa.SetIcon(loadResource(fg.assets, "/icon.png"))
	fg.app = fa

	w := fa.NewWindow("skyimager-gui")
	w.SetMaster()
	w.SetContent(fg.Page1())
	w.Resize(fyne.Size{Width: 800, Height: 600})
	fg.w = w

	return fg
}

// Run shows and runs the Fyne interface.
func (fg *FyneUI) Run() {
	fg.w.ShowAndRun()
}

func (fg *FyneUI) listBaseImgs() ([]string, string) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
	defer cancel()

	title := "Please Wait"
	msg := "Obtaining base image releases from GitHub..."
	d := dialog.NewProgressInfinite(title, msg, fg.w)

	d.Show()
	rs, lr, err := ListReleases(ctx, fg.log)
	d.Hide()

	if err != nil {
		dialog.ShowError(err, fg.w)
		return nil, ""
	}

	fg.releases = rs
	return releaseStrings(rs), lr.String()
}

func (fg *FyneUI) generateBPS() (string, error) {
	prevIP := fg.gwIP
	bpsSlice := make([]boot.Params, 0, fg.visors+1)
	hvPKs := fg.hvPKs
	if fg.hvImg {
		hvPK, hvSK := cipher.GenerateKeyPair()
		hvBps, err := boot.MakeHypervisorParams(fg.gwIP, hvSK)
		if err != nil {
			return "", fmt.Errorf("boot_params[%d]: failed to generate for hypervisor: %v", len(bpsSlice), err)
		}
		prevIP = hvBps.LocalIP
		bpsSlice = append(bpsSlice, hvBps)
		hvPKs = append(hvPKs, hvPK)
	}
	for i := 0; i < fg.visors; i++ {
		_, vSK := cipher.GenerateKeyPair()
		vBps, err := boot.MakeVisorParams(prevIP, fg.gwIP, vSK, hvPKs, fg.socksPC)
		if err != nil {
			return "", fmt.Errorf("boot_params[%d]: failed to generate for visor: %v", len(bpsSlice), err)
		}
		prevIP = vBps.LocalIP
		bpsSlice = append(bpsSlice, vBps)
	}
	fg.bps = bpsSlice
	jsonStr, _ := json.MarshalIndent(bpsSlice, "", "    ")
	return string(jsonStr), nil
}

func (fg *FyneUI) build() {
	bpsSlice := fg.bps

	baseURL, err := releaseURL(fg.releases, fg.remImg)
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

		// Download section.
		dlTitle := "Downloading Base Image"
		dlMsg := fg.remImg + "\n" + baseURL
		dlDialog := dialog.NewProgress(dlTitle, dlMsg, fg.w)
		dlDialog.Show()
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
		err = builder.Download(baseURL)
		close(dlDone)
		dlDialog.Hide()
		if err != nil {
			dialog.ShowError(err, fg.w)
			return
		}

		// Extract section.
		extDialog := dialog.NewProgressInfinite("Extracting Archive", builder.DownloadPath(), fg.w)
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
	finDialog := dialog.NewProgressInfinite("Building Final Images", builder.finalDir, fg.w)
	finDialog.Show()
	err = builder.MakeFinalImages(imgs[0], bpsSlice)
	finDialog.Hide()
	if err != nil {
		dialog.ShowError(err, fg.w)
		return
	}

	// Inform user of completion.
	createREADME(fg.log, filepath.Join(builder.finalDir, "README.txt"))
	cont := fyne.NewContainerWithLayout(layout.NewVBoxLayout(),
		widget.NewLabel("Successfully built images!"),
		widget.NewLabel("Images are built to: "+builder.finalDir),
		widget.NewButton("Open Folder", func() { _ = open.Run(builder.finalDir) }),
		widget.NewLabel("To flash the images, use a tool such as balenaEtcher:"),
		widget.NewButton("Open URL", func() { _ = open.Run("https://www.balena.io/etcher") }),
	)
	dialog.ShowCustom("Success", "Close", cont, fg.w)
}
