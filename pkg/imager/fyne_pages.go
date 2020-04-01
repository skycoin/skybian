package imager

import (
	"fmt"
	"net"
	"net/url"
	"path/filepath"
	"strconv"

	"fyne.io/fyne"
	"fyne.io/fyne/dialog"
	"fyne.io/fyne/widget"
)

func (fg *FyneGUI) Page1() fyne.CanvasObject {
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
	return makePage(fg.w, conf, widget.NewVBox(
		widget.NewLabelWithStyle(title, fyne.TextAlignLeading, fyne.TextStyle{Bold: true}),
		widget.NewLabelWithStyle(body, fyne.TextAlignLeading, fyne.TextStyle{Monospace: true})))
}

func (fg *FyneGUI) Page2() fyne.CanvasObject {
	wkDir := newLinkedEntry(&fg.wkDir)
	baseUrl := newLinkedEntry(&fg.baseURL)
	gwIP := newEntry(fg.gwIP.String(), func(s string) { fg.gwIP = net.ParseIP(s) })
	socksPC := newLinkedEntry(&fg.socksPC)
	socksPC.SetPlaceHolder("passcode")
	visors := newEntry(strconv.Itoa(fg.visors), func(s string) { fg.visors, _ = strconv.Atoi(s) })
	hv := widget.NewCheck("Generate Hypervisor Image.", func(b bool) { fg.hv = b })
	hv.SetChecked(fg.hv)

	conf := pageConfig{
		I:    2,
		Name: "Prepare Boot Parameters",
		Reset: func() {
			wkDir.SetText(DefaultRootDir())
			baseUrl.SetText(DefaultDlURL)
			gwIP.SetText(DefaultGwIP)
			socksPC.SetText("")
			visors.SetText(strconv.Itoa(DefaultVCount))
			hv.SetChecked(true)
		},
		Check: func() error {
			if _, err := filepath.Abs(fg.wkDir); err != nil {
				return fmt.Errorf("invalid Work Directory: %v", err)
			}
			if _, err := url.Parse(fg.baseURL); err != nil {
				return fmt.Errorf("invalid Base Image URL: %v", err)
			}
			if fg.gwIP == nil {
				return fmt.Errorf("invalid Gateway IP")
			}
			if _, err := strconv.Atoi(visors.Text); err != nil {
				return fmt.Errorf("invalid Number of Visor Images: %v", err)
			}
			if fg.visors < 0 {
				return fmt.Errorf("cannot create %d Visor Images", fg.visors)
			}
			return nil
		},
		Prev: func() { fg.w.SetContent(fg.Page1()) },
		Next: func() { fg.w.SetContent(fg.Page3()) },
	}
	return makePage(fg.w, conf,
		widget.NewLabel("Work Directory:"), wkDir,
		widget.NewLabel("Base Image URL:"), baseUrl,
		widget.NewLabel("Gateway IP:"), gwIP,
		widget.NewLabel("Skysocks Passcode:"), socksPC,
		widget.NewLabel("Number of Visor Images:"), visors, hv)
}

func (fg *FyneGUI) Page3() fyne.CanvasObject {
	bps := widget.NewMultiLineEntry()
	bps.SetText(fg.generateBPS())
	conf := pageConfig{
		I:    3,
		Name: "Finalize Boot Parameters",
		Prev: func() { fg.w.SetContent(fg.Page2()) },
		ResetText: "Regenerate",
		Reset: func() { bps.SetText(fg.generateBPS()) },
		NextText: "Download and Build",
		Next: func() {
			dialog.ShowConfirm("Confirmation", "Start download and build?", func(b bool) {
				if b {
					fg.build()
				}
			}, fg.w)
		},
	}
	return makePage(fg.w, conf, bps)
}


