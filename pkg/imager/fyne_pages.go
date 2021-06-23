package imager

import (
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/dialog"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
	"github.com/skycoin/dmsg/cipher"

	"github.com/skycoin/skybian/pkg/boot"
)

// Page1 returns the canvas that draws page 1 of the Fyne interface.
func (fg *FyneUI) Page1() fyne.CanvasObject {
	title := "Welcome to Skyimager!"
	body := "This tool will:\n\n" +
		"1. Download a base image of Skybian.\n" +
		"2. Prepare an array of boot parameters.\n" +
		"3. Generate final images with provided boot parameters.\n" +
		"4. Provide instructions on how to flash final images.\n"

	conf := pageConfig{
		I:    1,
		Name: "Introduction",
		Next: func() { fg.w.SetContent(fg.Page2()) },
	}
	return makePage(conf, container.NewVBox(
		widget.NewLabelWithStyle(title, fyne.TextAlignLeading, fyne.TextStyle{Bold: true}),
		widget.NewLabelWithStyle(body, fyne.TextAlignLeading, fyne.TextStyle{Monospace: true})))
}

func (fg *FyneUI) makeFilePicker() fyne.CanvasObject {
	fsImg := widget.NewEntry()
	fsImg.SetPlaceHolder("path to .img file")
	fsImg.OnChanged = func(s string) {
		fg.fsImg = s
		fg.log.Debugf("Set: fg.fsImg = %v", s)
	}
	fsImg.SetText(fg.fsImg)
	d := dialog.NewFileOpen(func(f fyne.URIReadCloser, err error) {
		if err != nil {
			fg.log.Error(err)
			return
		}
		if f == nil {
			return
		}
		uri := f.URI().String()
		// URI includes file:// scheme, and there is no other way to retrieve full file path
		filePath := strings.TrimPrefix(uri, "file://")
		fg.fsImg = filePath
		fsImg.SetText(filePath)
	}, fg.w)
	btn := widget.NewButton("Open", d.Show)
	box := container.NewHBox(btn, fsImg)
	return box
}

// remoteImgSelect is a wrapper around select widget with img type
// and label attached to it
type remoteImgSelect struct {
	imgType ImgType
	label   string
	widget  *widget.Select
}

func (fg *FyneUI) makeRemoteSelect(t ImgType, label string) remoteImgSelect {
	remImgs, latestImg := fg.listBaseImgs(t)
	fg.log.Debugf("type: %s, latest: %s", t, latestImg)
	widget := widget.NewSelect(remImgs, func(s string) {
		fg.remImg = s
		fg.log.Debugf("Set: fg.remImg = %v", s)
	})
	if len(widget.Options) > 0 {
		widget.SetSelected(widget.Options[0])
	}
	widget.Hide()
	return remoteImgSelect{t, label, widget}
}

// showRemoteSelect and update remote image value to the selected
// value of the widget to be shown
func (fg *FyneUI) showRemoteSelect(sel *widget.Select) {
	sel.Show()
	fg.remImg = sel.Selected
	fg.log.Debugf("remImg = %s", fg.remImg)
}

// Page2 returns the canvas that draws page 2 of the Fyne interface.
func (fg *FyneUI) Page2() fyne.CanvasObject {
	wkDir := newLinkedEntry(&fg.wkDir)

	fsImgPicker := fg.makeFilePicker()
	fsImgPicker.Hide()

	remSky := fg.makeRemoteSelect(TypeSkybian, "Skybian 64 bit (Orange Pi Prime)")
	remSky3 := fg.makeRemoteSelect(TypeSkybianOPi3, "Skybian 64 bit (Orange Pi 3)")
	remRasp32 := fg.makeRemoteSelect(TypeRaspbian, "SkyRaspbian 32 bit (Raspberry Pi)")
	remRasp64 := fg.makeRemoteSelect(TypeRaspbian64, "SkyRaspbian 64 bit (Raspberry Pi)")
	remotes := []remoteImgSelect{remSky, remSky3, remRasp32, remRasp64}
	var labels []string
	for _, rem := range remotes {
		labels = append(labels, rem.label)
	}

	remoteTypeSelect := widget.NewSelect(labels, func(s string) {
		for _, rem := range remotes {
			if s == rem.label {
				fg.showRemoteSelect(rem.widget)
				fg.imgType = rem.imgType
			} else {
				rem.widget.Hide()
			}
		}
	})
	remoteTypeSelect.SetSelected(labels[0])
	imgLoc := widget.NewRadioGroup(fg.locations, func(s string) {
		switch fg.imgLoc = s; s {
		case fg.locations[0]:
			fsImgPicker.Hide()
			remoteTypeSelect.Show()
		case fg.locations[1]:
			fsImgPicker.Show()
			for _, rem := range remotes {
				rem.widget.Hide()
			}
			remoteTypeSelect.Hide()
		}
	})
	imgLoc.SetSelected(fg.imgLoc)
	imgLoc.OnChanged(fg.imgLoc)

	// Gateway IP:
	gwIP := newEntry(fg.gwIP.String(), func(s string) {
		fg.gwIP = net.ParseIP(s)
		fg.log.Debugf("Set: fg.gwIP = %v", s)
	})

	wifiName := newEntry(fg.wifiName, func(s string) {
		fg.wifiName = s
		fg.log.Debugf("Set: fg.gwIP = %v", s)
	})
	wifiPass := newEntry(fg.wifiPass, func(s string) {
		fg.wifiPass = s
		fg.log.Debugf("Set: fg.wifiPass = %v", s)
	})

	wifiWidgets := container.New(layout.NewVBoxLayout(), widget.NewLabel("Wifi access point name:"),
		wifiName, widget.NewLabel("Wifi passcode:"), wifiPass)
	wifiWidgets.Hide()

	enableWifi := widget.NewCheck("Generate wi-fi connection", func(b bool) {
		if b {
			fg.wifiName = wifiName.Text
			fg.wifiPass = wifiPass.Text
			wifiWidgets.Show()
		} else {
			fg.wifiName = ""
			fg.wifiPass = ""
			wifiWidgets.Hide()
		}
	})
	enableWifi.SetChecked(false)

	socksPC := newLinkedEntry(&fg.socksPC)
	socksPC.SetPlaceHolder("passcode")

	imgNumber := newEntry(strconv.Itoa(fg.imgNumber), func(s string) {
		fg.imgNumber, _ = strconv.Atoi(s) //nolint
		fg.log.Debugf("Set: fg.visors = %v", s)
	})

	genHvImg := widget.NewCheck("Generate Hypervisor Image.", func(b bool) {
		fg.hvImg = b
		fg.log.Debugf("Set: fg.genHvImg = %v", b)
	})
	genHvImg.SetChecked(fg.hvImg)

	hvPKs := container.NewVBox()
	hvPKs.Hide()
	hvPKsRefresh := func() {
		hvPKs.Objects = nil
		for _, pk := range fg.hvPKs {
			hvPKs.Add(widget.NewLabelWithStyle(pk.String(),
				fyne.TextAlignLeading, fyne.TextStyle{Monospace: true}))
		}
	}

	hvPKsAdd := widget.NewButtonWithIcon("", theme.ContentAddIcon(), func() {
		title := "Trusted Hypervisors"
		confirm := "Add"
		dismiss := "Cancel"
		input := widget.NewEntry()
		input.SetPlaceHolder("public key")
		cont := container.New(layout.NewVBoxLayout(),
			widget.NewLabel("Add trusted hypervisor public key:"), input)
		dialog.ShowCustomConfirm(title, confirm, dismiss, cont, func(b bool) {
			if !b {
				return
			}
			var pk cipher.PubKey
			if err := pk.Set(input.Text); err != nil {
				showErr(fg, fmt.Errorf("failed to add public key: %v", err))
				return
			}
			for _, oldPK := range fg.hvPKs {
				if pk == oldPK {
					showErr(fg, fmt.Errorf("public key '%s' is already added", pk))
					return
				}
			}
			fg.hvPKs = append(fg.hvPKs, pk)
			hvPKsRefresh()
		}, fg.w)
	})
	hvPKsAdd.Hide()

	enableHvPKs := widget.NewCheck("Manually Add Trusted Hypervisors.", func(b bool) {
		if b {
			hvPKsRefresh()
			hvPKs.Show()
			hvPKsAdd.Show()
		} else {
			fg.hvPKs = nil
			hvPKs.Hide()
			hvPKsAdd.Hide()
		}
	})
	enableHvPKs.SetChecked(len(fg.hvPKs) > 0)

	conf := pageConfig{
		I:    2,
		Name: "Prepare Boot Parameters",
		Reset: func() {
			fg.resetPage2Values()
			fg.w.SetContent(fg.Page2())
		},
		Prev: func() { fg.w.SetContent(fg.Page1()) },
		Next: func() {
			if !checkPage2Inputs(fg, imgNumber.Text) {
				return
			}
			proceed := func() {
				os.Mkdir(fg.wkDir, os.FileMode(0755)) //nolint
				bpsStr, err := fg.generateBPS()
				if err != nil {
					dialog.ShowError(err, fg.w)
					return
				}
				fg.w.SetContent(fg.Page3(bpsStr))
			}
			if _, err := os.Stat(fg.wkDir); err == nil {
				clearWorkDirDialog(fg, fg.wkDir, proceed)
			} else {
				proceed()
			}
		},
	}
	return makePage(conf,
		widget.NewLabel("Work Directory:"), wkDir,
		widget.NewLabel("Base Image:"), imgLoc, fsImgPicker, remoteTypeSelect,
		remSky.widget, remSky3.widget, remRasp32.widget, remRasp64.widget,
		widget.NewLabel("Gateway IP:"), gwIP,
		enableWifi,
		wifiWidgets,
		widget.NewLabel("Skysocks Passcode:"), socksPC,
		widget.NewLabel("Number of images:"), imgNumber,
		genHvImg, enableHvPKs, hvPKs, hvPKsAdd)
}

func (fg *FyneUI) resetPage2Values() {
	fg.wkDir = DefaultRootDir()
	fg.remImg = ""
	fg.gwIP = net.ParseIP(boot.DefaultGatewayIP)
	fg.socksPC = ""
	fg.imgNumber = DefaultImgNumber
	fg.hvImg = true
	fg.hvPKs = nil
}

func checkPage2Inputs(fg *FyneUI, imgNumText string) bool {
	if _, err := filepath.Abs(fg.wkDir); err != nil {
		return showErr(fg, fmt.Errorf("invalid Work Directory: %v", err))
	}
	switch fg.imgLoc {
	case fg.locations[0]:
		if strings.TrimSpace(fg.remImg) == "" {
			return showErr(fg, errors.New("invalid Base Image URL: cannot be empty"))
		}
	case fg.locations[1]:
		if !strings.HasSuffix(fg.fsImg, ".img") {
			return showErr(fg, errors.New("invalid Base Image Path: file needs to have .img extension"))
		}
		if _, err := os.Stat(fg.fsImg); err != nil {
			return showErr(fg, fmt.Errorf("cannot access Base Image: %v", err))
		}
	default:
		return showErr(fg, errors.New("no base image selected"))
	}

	if fg.gwIP == nil {
		return showErr(fg, fmt.Errorf("invalid Gateway IP"))
	}
	if n, err := strconv.Atoi(imgNumText); err != nil || n <= 0 {
		return showErr(fg, fmt.Errorf("Number of images should be a positive integer, got: %s",
			imgNumText))
	}
	return true
}

func clearWorkDirDialog(fg *FyneUI, wkDir string, next func()) {
	cTitle := "Work Directory Already Exists"
	cMsg := fmt.Sprintf("Directory %s already exists.\nDelete everything and continue?", wkDir)
	dialog.ShowConfirm(cTitle, cMsg, func(b bool) {
		if !b {
			showErr(fg)
			return
		}
		if err := os.RemoveAll(wkDir); err != nil {
			showErr(fg, fmt.Errorf("failed to clear work directory: %v", err))
			return
		}
		dialog.ShowInformation("Information", "Work directory cleared.", fg.w)
		next()
	}, fg.w)
}

// Page3 returns a canvas that draws page 3 of the Fyne interface.
func (fg *FyneUI) Page3(bpsStr string) fyne.CanvasObject {
	bps := widget.NewMultiLineEntry()
	bps.SetText(bpsStr)

	conf := pageConfig{
		I:         3,
		Name:      "Finalize Boot Parameters",
		Prev:      func() { fg.w.SetContent(fg.Page2()) },
		ResetText: "Regenerate",
		Reset: func() {
			bpsStr, err := fg.generateBPS()
			if err != nil {
				dialog.ShowError(err, fg.w)
				return
			}
			bps.SetText(bpsStr)
		},
		NextText: "Build",
		Next: func() {
			// Decode bps entry text to ensure changes are recorded.
			dec := json.NewDecoder(strings.NewReader(bps.Text))
			if err := dec.Decode(&fg.bps); err != nil {
				dialog.ShowError(fmt.Errorf("invalid boot parameters: %v", err), fg.w)
				return
			}
			dialog.ShowConfirm("Confirmation", "Start build?", func(b bool) {
				if b {
					fg.build()
				}
			}, fg.w)
		},
	}
	return makePage(conf, bps)
}
