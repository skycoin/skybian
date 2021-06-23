package imager

import (
	"fmt"
	"io/ioutil"
	"net/http"
	"sync"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/dialog"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
)

// fyne resource mutex
var frMx = new(sync.Mutex)

type fyneResource struct {
	f http.File
}

func (fr fyneResource) Name() string {
	fi, err := fr.f.Stat()
	if err != nil {
		panic(err)
	}
	return fi.Name()
}

func (fr fyneResource) Content() []byte {
	frMx.Lock()
	defer frMx.Unlock()

	if _, err := fr.f.Seek(0, 0); err != nil {
		panic(err)
	}
	b, err := ioutil.ReadAll(fr.f)
	if err != nil {
		panic(err)
	}
	return b
}

func loadResource(assets http.FileSystem, name string) fyne.Resource {
	f, err := assets.Open(name)
	if err != nil {
		panic(err)
	}
	return &fyneResource{f: f}
}

func newEntry(s string, fn func(s string)) *widget.Entry {
	entry := widget.NewEntry()
	entry.SetText(s)
	entry.OnChanged = fn
	return entry
}

func newLinkedEntry(p *string) *widget.Entry {
	return newEntry(*p, func(s string) { *p = s })
}

// Display error message (if any) and does not advance to next page.
func showErr(fg *FyneUI, err ...error) bool {
	for _, e := range err {
		dialog.ShowError(e, fg.w)
	}
	return false
}

type pageConfig struct {
	I         int
	Name      string
	Reset     func()
	ResetText string
	Prev      func()
	Next      func()
	NextText  string
}

func makePage(conf pageConfig, objs ...fyne.CanvasObject) fyne.CanvasObject {
	const totalPages = 3
	makeButton := func(label string, icon fyne.Resource, fn func(), _ bool) *widget.Button {
		b := widget.NewButtonWithIcon(label, icon, fn)
		// maybe bool should be doing this
		if fn == nil {
			b.Disable()
			return b
		}
		return b
	}
	resetText := "Reset"
	if conf.ResetText != "" {
		resetText = conf.ResetText
	}
	nextText := "Next"
	if conf.NextText != "" {
		nextText = conf.NextText
	}
	footer := container.New(layout.NewGridLayout(3),
		makeButton("Previous", theme.MediaSkipPreviousIcon(), conf.Prev, true),
		makeButton(resetText, theme.ViewRefreshIcon(), conf.Reset, false),
		makeButton(nextText, theme.MediaSkipNextIcon(), conf.Next, true),
	)
	pageTxt := fmt.Sprintf("%s (%d/%d)", conf.Name, conf.I, totalPages)
	header := container.New(layout.NewGridLayout(1),
		widget.NewLabel(pageTxt),
	)

	cont := container.New(
		layout.NewBorderLayout(header, footer, nil, nil),
		container.NewScroll(container.NewVBox(objs...)),
		footer, header,
	)
	return cont
}
