package imager

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"fyne.io/fyne"
	"fyne.io/fyne/app"
	"fyne.io/fyne/dialog"
	"fyne.io/fyne/theme"
	"fyne.io/fyne/widget"
	"github.com/sirupsen/logrus"
	"github.com/skratchdot/open-golang/open"

	"github.com/SkycoinProject/skybian/pkg/bootparams"
)

type FyneGUI struct {
	log    logrus.FieldLogger
	assets http.FileSystem

	// main app
	app fyne.App

	// main window
	mainW   fyne.Window
	mainMx  sync.RWMutex
	bpsE    *widget.Entry
	baseURL string
	hvPKs   string
	gwIP    string
	finalN  string
	wkDir   string
}

func NewFyneGUI(log logrus.FieldLogger, assets http.FileSystem) *FyneGUI {
	fg := new(FyneGUI)
	fg.log = log
	fg.assets = assets

	// set defaults
	fg.baseURL = DefaultDlURL
	fg.hvPKs = ""
	fg.gwIP = DefaultGwIP
	fg.finalN = "1"
	fg.wkDir = DefaultRootDir()

	fg.initMainApp()
	fg.initMainWindow()
	return fg
}

func (fg *FyneGUI) initMainApp() {
	_ = os.Setenv("FYNE_SCALE", "0.75")

	fa := app.New()
	fa.SetIcon(loadResource(fg.assets, "/skyimager.png"))
	fa.Settings().SetTheme(theme.LightTheme())
	fg.app = fa
}

func (fg *FyneGUI) initMainWindow() {
	w := fg.app.NewWindow("skyimager-gui")
	w.SetMaster()
	w.Resize(fyne.NewSize(800, 800))
	fg.mainW = w

	bpsE := widget.NewMultiLineEntry()
	bpsGen := makeBpsGenerator(fg, bpsE)
	callback := func(v *string) func(newV string) {
		return func(newV string) {
			fg.mainMx.Lock()
			*v = newV
			bpsGen()
			fg.mainMx.Unlock()
		}
	}
	fg.bpsE = bpsE

	bpsB := widget.NewButton("Regenerate", nil)
	bpsB.OnTapped = func() {
		fg.mainMx.Lock()
		bpsGen()
		fg.mainMx.Unlock()
	}

	baseUrlE := widget.NewEntry()
	baseUrlE.SetText(fg.baseURL)
	baseUrlE.OnChanged = callback(&fg.baseURL)
	baseURLB := widget.NewButton("Use Latest", func() {
		baseUrlE.SetText(fg.baseURL)
	})

	hvPKsE := widget.NewEntry()
	hvPKsE.SetPlaceHolder("public keys separated with commas")
	hvPKsE.OnChanged = callback(&fg.hvPKs)

	gwIPE := widget.NewEntry()
	gwIPE.SetText(fg.gwIP)
	gwIPE.SetPlaceHolder("IP address")
	gwIPE.OnChanged = callback(&fg.gwIP)

	finalCountOpts := genNumStrSlice(1, 10)
	finalCountS := widget.NewSelect(finalCountOpts, nil)
	finalCountS.SetSelected(fg.finalN)
	finalCountS.OnChanged = callback(&fg.finalN)

	wkDirE := widget.NewEntry()
	wkDirE.SetText(fg.wkDir)

	buildB := widget.NewButton("Download and Build", func() {
		go fg.build()
	})

	vBox := widget.NewVBox(
		widget.NewLabel("Base Image URL:"),
		baseUrlE,
		baseURLB,
		widget.NewLabel("Trusted Hypervisors:"),
		hvPKsE,
		widget.NewLabel("Gateway IP:"),
		gwIPE,
		widget.NewLabel("Number of Final Images to Generate:"),
		finalCountS,
		widget.NewLabel("Configure Final Images:"),
		bpsE,
		bpsB,
		widget.NewLabel("Work directory (created if nonexistent):"),
		wkDirE,
		widget.NewLabel("Start:"),
		buildB)
	w.SetContent(widget.NewScrollContainer(vBox))
}

func (fg *FyneGUI) build() {
	fg.mainMx.RLock()
	defer fg.mainMx.RUnlock()

	// Check boot params.
	fg.bpsE.RLock()
	bpsTxt := fg.bpsE.Text
	fg.bpsE.RUnlock()

	var bpsSlice []bootparams.BootParams
	if err := json.Unmarshal([]byte(bpsTxt), &bpsSlice); err != nil {
		dialog.NewInformation("Error", "invalid boot parameters: "+err.Error(), fg.mainW).Show()
		return
	}

	// Confirm to continue.
	confirmCh := make(chan bool, 1)
	confirmAction := func(ok bool) {
		confirmCh <- ok
		close(confirmCh)
	}
	confirm := dialog.NewConfirm("Confirmation", "Start download and build?", confirmAction, fg.mainW)
	confirm.Show()
	if ok := <-confirmCh; !ok {
		return
	}

	// Prepare builder.
	builder, err := NewBuilder(fg.log, fg.wkDir)
	if err != nil {
		dialog.NewInformation("Error", err.Error(), fg.mainW).Show()
		return
	}

	// Download section.
	dlDialog := dialog.NewProgress("Downloading Base Archive", fg.baseURL, fg.mainW)
	dlDialog.Show()
	dlDone := make(chan struct{})
	go func() {
		t := time.NewTicker(time.Second)
		for {
			select {
			case <-t.C:
				total := float64(builder.DownloadTotal())
				current := float64(builder.DownloadCurrent())
				dlDialog.SetValue(current / total)
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
		dialog.NewInformation("Error", err.Error(), fg.mainW).Show()
		return
	}

	// Extract section.
	extDialog := dialog.NewProgressInfinite("Extracting Archive", builder.DownloadPath(), fg.mainW)
	extDialog.Show()
	err = builder.ExtractArchive()
	extDialog.Hide()
	if err != nil {
		dialog.NewInformation("Error", err.Error(), fg.mainW).Show()
		return
	}

	imgs := builder.Images()
	fg.log.
		WithField("n", len(imgs)).
		WithField("imgs", imgs).
		Info("Obtained base images.")

	if len(imgs) == 0 {
		dialog.NewInformation("Error", "no valid images in archive", fg.mainW).Show()
		return
	}

	// Finalize section.
	finDialog := dialog.NewProgressInfinite("Building Final Images", builder.finalDir, fg.mainW)
	finDialog.Show()
	err = builder.MakeFinalImages(imgs[0], bpsSlice)
	finDialog.Hide()
	if err != nil {
		dialog.NewInformation("Error", err.Error(), fg.mainW).Show()
		return
	}

	// Inform user of completion.
	createREADME(fg.log, filepath.Join(builder.finalDir, "README.txt"))

	box := fyne.NewContainer(
		widget.NewLabel("Successfully built images!"),
		widget.NewLabel("Images are built to: "+builder.finalDir),
		widget.NewButton("Open Folder", func() { _ = open.Run(builder.finalDir) }),
		widget.NewLabel("To flash the images, use a tool such as balenaEtcher:"),
		widget.NewButton("Open URL", func() { _ = open.Run("https://www.balena.io/etcher") }),
	)
	dialog.ShowCustom("Success", "Close", box, fg.mainW)
}

func makeBpsGenerator(fg *FyneGUI, finalBpsE *widget.Entry) func() {
	genBps := func() {
		var hvs []string
		split := strings.Split(fg.hvPKs, ",")
		for _, hv := range split {
			if hv := strings.TrimSpace(hv); len(hv) != 0 {
				hvs = append(hvs, hv)
			}
		}
		n, _ := strconv.Atoi(fg.finalN)
		bps, err := GenerateBootParams(n, fg.gwIP, hvs)
		if err != nil {
			finalBpsE.SetText(fmt.Sprintf("error: %v", err))
			return
		}
		j, _ := json.MarshalIndent(bps, "", "    ")
		finalBpsE.SetText(string(j))
	}
	genBps()
	return genBps
}

func (fg *FyneGUI) Run() {
	fg.mainW.ShowAndRun()
}

func genNumStrSlice(first int, last int) []string {
	out := make([]string, 0, last-first+1)
	for i := first; i <= last; i++ {
		out = append(out, strconv.Itoa(i))
	}
	return out
}
