package imager

import (
	"bytes"
	"errors"
	"fmt"
	"io/ioutil"
	"net/http"
	"sync"
	"unicode"

	"fyne.io/fyne"
	"fyne.io/fyne/dialog"
	"fyne.io/fyne/layout"
	"fyne.io/fyne/theme"
	"fyne.io/fyne/widget"
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

const nbsp = 0xA0

func wrapLines(s string, lim uint) string {
	// Initialize a buffer with a slightly larger size to account for breaks
	init := make([]byte, 0, len(s))
	buf := bytes.NewBuffer(init)

	var current uint
	var wordBuf, spaceBuf bytes.Buffer
	var wordBufLen, spaceBufLen uint

	for _, char := range s {
		if char == '\n' {
			if wordBuf.Len() == 0 {
				if current+spaceBufLen > lim {
					current = 0
				} else {
					current += spaceBufLen
					spaceBuf.WriteTo(buf)
				}
				spaceBuf.Reset()
				spaceBufLen = 0
			} else {
				current += spaceBufLen + wordBufLen
				spaceBuf.WriteTo(buf)
				spaceBuf.Reset()
				spaceBufLen = 0
				wordBuf.WriteTo(buf)
				wordBuf.Reset()
				wordBufLen = 0
			}
			buf.WriteRune(char)
			current = 0
		} else if unicode.IsSpace(char) && char != nbsp {
			if spaceBuf.Len() == 0 || wordBuf.Len() > 0 {
				current += spaceBufLen + wordBufLen
				spaceBuf.WriteTo(buf)
				spaceBuf.Reset()
				spaceBufLen = 0
				wordBuf.WriteTo(buf)
				wordBuf.Reset()
				wordBufLen = 0
			}

			spaceBuf.WriteRune(char)
			spaceBufLen++
		} else {
			wordBuf.WriteRune(char)
			wordBufLen++

			if current+wordBufLen+spaceBufLen > lim && wordBufLen < lim {
				buf.WriteRune('\n')
				current = 0
				spaceBuf.Reset()
				spaceBufLen = 0
			}
		}
	}

	if wordBuf.Len() == 0 {
		if current+spaceBufLen <= lim {
			spaceBuf.WriteTo(buf)
		}
	} else {
		spaceBuf.WriteTo(buf)
		wordBuf.WriteTo(buf)
	}

	return buf.String()
}

func showDialogErrMessage(errMessage string, fw fyne.Window) {
	dialog.ShowError(errors.New(wrapLines(errMessage, 80)), fw)
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
	makeButton := func(label string, icon fyne.Resource, fn func(), check bool) *widget.Button {
		b := widget.NewButtonWithIcon(label, icon, fn)
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
	footer := fyne.NewContainerWithLayout(layout.NewGridLayout(3),
		makeButton("Previous", theme.MediaSkipPreviousIcon(), conf.Prev, true),
		makeButton(resetText, theme.ViewRefreshIcon(), conf.Reset, false),
		makeButton(nextText, theme.MediaSkipNextIcon(), conf.Next, true),
	)
	pageTxt := fmt.Sprintf("%s (%d/%d)", conf.Name, conf.I, totalPages)
	cont := fyne.NewContainerWithLayout(
		layout.NewBorderLayout(nil, footer, nil, nil),
		widget.NewGroupWithScroller(pageTxt, append(objs, widget.NewLabel(""))...),
		footer)
	return cont
}
