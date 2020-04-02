package imager

import (
	"encoding/json"
	"net"
	"net/http"
	"path/filepath"
	"time"

	"fyne.io/fyne"
	"fyne.io/fyne/app"
	"fyne.io/fyne/dialog"
	"fyne.io/fyne/layout"
	"fyne.io/fyne/widget"
	"github.com/SkycoinProject/dmsg/cipher"
	"github.com/sirupsen/logrus"
	"github.com/skratchdot/open-golang/open"

	"github.com/SkycoinProject/skybian/pkg/boot"
)

const (
	DefaultVCount = 7
	DefaultHVIP   = "192.168.0.2"
)

type FyneGUI struct {
	log    logrus.FieldLogger
	assets http.FileSystem

	app fyne.App
	w   fyne.Window

	wkDir   string
	baseURL string
	gwIP    net.IP
	socksPC string
	hv      bool
	visors  int

	bps []boot.Params
}

func NewFyneGUI(log logrus.FieldLogger, assets http.FileSystem) *FyneGUI {
	fg := new(FyneGUI)
	fg.log = log
	fg.assets = assets

	fg.wkDir = DefaultRootDir()
	fg.baseURL = ""
	fg.gwIP = net.ParseIP(DefaultGwIP)
	fg.hv = true
	fg.visors = DefaultVCount

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

func (fg *FyneGUI) Run() {
	fg.w.ShowAndRun()
}

func (fg *FyneGUI) generateBPS() string {
	bpsSlice := make([]boot.Params, 0, fg.visors+1)
	var hvPKs []cipher.PubKey
	if fg.hv {
		hvPK, hvSK := cipher.GenerateKeyPair()
		bpsSlice = append(bpsSlice, boot.MakeHypervisorParams(hvSK))
		hvPKs = append(hvPKs, hvPK)
	}
	for i := 0; i < fg.visors; i++ {
		_, vSK := cipher.GenerateKeyPair()
		bpsSlice = append(bpsSlice, boot.MakeVisorParams(i, fg.gwIP, vSK, hvPKs, fg.socksPC))
	}
	fg.bps = bpsSlice
	jsonStr, _ := json.MarshalIndent(bpsSlice, "", "    ")
	return string(jsonStr)
}

func (fg *FyneGUI) build() {
	bpsSlice := fg.bps

	// Prepare builder.
	builder, err := NewBuilder(fg.log, fg.wkDir)
	if err != nil {
		dialog.NewInformation("Error", err.Error(), fg.w).Show()
		return
	}

	// Download section.
	dlDialog := dialog.NewProgress("Downloading Base Archive", fg.baseURL, fg.w)
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
	err = builder.Download(fg.baseURL)
	close(dlDone)
	dlDialog.Hide()
	if err != nil {
		dialog.NewInformation("Error", err.Error(), fg.w).Show()
		return
	}

	// Extract section.
	extDialog := dialog.NewProgressInfinite("Extracting Archive", builder.DownloadPath(), fg.w)
	extDialog.Show()
	err = builder.ExtractArchive()
	extDialog.Hide()
	if err != nil {
		dialog.NewInformation("Error", err.Error(), fg.w).Show()
		return
	}

	imgs := builder.Images()
	fg.log.
		WithField("n", len(imgs)).
		WithField("imgs", imgs).
		Info("Obtained base images.")

	if len(imgs) == 0 {
		dialog.NewInformation("Error", "no valid images in archive", fg.w).Show()
		return
	}

	// Finalize section.
	finDialog := dialog.NewProgressInfinite("Building Final Images", builder.finalDir, fg.w)
	finDialog.Show()
	err = builder.MakeFinalImages(imgs[0], bpsSlice)
	finDialog.Hide()
	if err != nil {
		dialog.NewInformation("Error", err.Error(), fg.w).Show()
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
