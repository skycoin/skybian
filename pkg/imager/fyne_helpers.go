package imager

import (
	"fmt"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/dialog"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
)

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
	content := container.NewVScroll(container.NewVBox(objs...))
	if len(objs) == 1 {
		content = container.NewVScroll(container.NewGridWithRows(len(objs), objs...))
	}
	cont := container.New(
		layout.NewBorderLayout(header, footer, nil, nil),
		content, footer, header,
	)
	return cont
}
