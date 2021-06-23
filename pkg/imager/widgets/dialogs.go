package widgets

import (
	"image/color"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
)

// This package has been mostly copied from fyne/dialog
// The reason of this was that fyne/dialog doesn't provide any easy
// way to extend its widgets and to add custom content

// Another solution would be to write our own widget from scratch,
// but there isn't much point in it since fyne/dialog implementation
// covers the basic functionality of showing/hiding a window already

const (
	padWidth    = 32
	padHeight   = 16
	dialogWidth = 400
)

type skydialog struct {
	callback func(bool)
	title    string
	icon     fyne.Resource

	win            *widget.PopUp
	bg             *canvas.Rectangle
	content, label fyne.CanvasObject
	dismiss        *widget.Button

	response  chan bool
	responded bool
	parent    fyne.Window
}

func (d *skydialog) wait() {
	// select {
	// case response := <-d.response:
	// 	d.responded = true
	// 	d.win.Hide()
	// 	if d.callback != nil {
	// 		d.callback(response)
	// 	}
	// }
	for response := range d.response {
		d.responded = true
		d.win.Hide()
		if d.callback != nil {
			d.callback(response)
		}

	}
}

func (d *skydialog) setButtons(buttons fyne.CanvasObject) {
	d.bg = canvas.NewRectangle(theme.BackgroundColor())
	d.label = widget.NewLabelWithStyle(d.title, fyne.TextAlignLeading, fyne.TextStyle{Bold: true})

	var content fyne.CanvasObject
	if d.icon == nil {
		content = container.New(d,
			&canvas.Image{},
			d.bg,
			d.content,
			buttons,
			d.label,
		)
	} else {
		bgIcon := canvas.NewImageFromResource(d.icon)
		content = container.New(d,
			bgIcon,
			d.bg,
			d.content,
			buttons,
			d.label,
		)
	}

	d.win = widget.NewModalPopUp(content, d.parent.Canvas())
	// fixed width is required to make word-wrapping work correctly
	// if needed, add new method to set dialog width programmatically, for now it's a constant
	d.win.Resize(fyne.NewSize(dialogWidth, d.win.MinSize().Height))
	d.applyTheme()
}

func (d *skydialog) Layout(obj []fyne.CanvasObject, size fyne.Size) {
	d.bg.Move(fyne.NewPos(-theme.Padding(), -theme.Padding()))
	d.bg.Resize(size.Add(fyne.NewSize(theme.Padding()*2, theme.Padding()*2)))

	textMin := obj[2].MinSize()
	btnMin := obj[3].MinSize().Max(obj[3].Size())

	// icon
	iconHeight := padHeight*2 + textMin.Height + d.label.MinSize().Height - theme.Padding()
	obj[0].Resize(fyne.NewSize(iconHeight, iconHeight))
	obj[0].Move(fyne.NewPos(size.Width-iconHeight+theme.Padding(), -theme.Padding()))

	// content (text)
	obj[2].Move(fyne.NewPos(size.Width/2-(textMin.Width/2), size.Height-padHeight-btnMin.Height-textMin.Height-theme.Padding()))
	obj[2].Resize(fyne.NewSize(textMin.Width, textMin.Height))
	if d.win != nil {
		obj[2].Move(fyne.NewPos(theme.Padding(), size.Height-padHeight-btnMin.Height-textMin.Height-theme.Padding()))
		obj[2].Resize(fyne.NewSize(size.Width, size.Height+theme.Padding()))
	}

	// buttons
	obj[3].Resize(btnMin)
	obj[3].Move(fyne.NewPos(size.Width/2-(btnMin.Width/2), size.Height-padHeight-btnMin.Height))
}

func (d *skydialog) MinSize(obj []fyne.CanvasObject) fyne.Size {
	textMin := obj[2].MinSize()
	btnMin := obj[3].MinSize().Max(obj[3].Size())

	width := fyne.Max(fyne.Max(textMin.Width, btnMin.Width), obj[4].MinSize().Width) + padWidth*2
	height := textMin.Height + btnMin.Height + d.label.MinSize().Height + theme.Padding() + padHeight*2

	return fyne.NewSize(width, height)
}

func (d *skydialog) applyTheme() {
	r, g, b, _ := theme.BackgroundColor().RGBA()
	bg := &color.RGBA{R: uint8(r), G: uint8(g), B: uint8(b), A: 230}
	d.bg.FillColor = bg
}

func newDialog(title, message string, icon fyne.Resource, callback func(bool), parent fyne.Window) *skydialog {
	d := &skydialog{content: newLabel(message), title: title, icon: icon, parent: parent}

	d.response = make(chan bool, 1)
	d.callback = callback

	return d
}

func newLabel(message string) fyne.CanvasObject {
	return widget.NewLabelWithStyle(message, fyne.TextAlignCenter, fyne.TextStyle{})
}

func (d *skydialog) Show() {
	go d.wait()
	d.win.Show()
}

func (d *skydialog) Hide() {
	d.win.Hide()

	if !d.responded && d.callback != nil {
		d.callback(false)
	}
}

// SetDismissText allows custom text to be set in the confirmation button
func (d *skydialog) SetDismissText(label string) {
	d.dismiss.SetText(label)
	d.win.Refresh()
}

// ShowCustom shows a dialog over the specified application using custom
// content. The button will have the dismiss text set.
// The MinSize() of the CanvasObject passed will be used to set the size of the window.
func ShowCustom(title, dismiss string, content fyne.CanvasObject, parent fyne.Window) {
	d := &skydialog{content: content, title: title, icon: nil, parent: parent}
	d.response = make(chan bool, 1)

	d.dismiss = &widget.Button{Text: dismiss,
		OnTapped: func() {
			d.response <- false
		},
	}
	d.setButtons(container.NewHBox(layout.NewSpacer(), d.dismiss, layout.NewSpacer()))
	d.Show()
}

// ShowError displays an error dialog with a single OK button, that displays given text
// The text is word wrapped
func ShowError(text string, parent fyne.Window) {
	label := widget.NewLabelWithStyle(text, fyne.TextAlignLeading, fyne.TextStyle{})
	label.Wrapping = fyne.TextWrapWord
	ShowCustom("Error", "Ok", label, parent)
}

// ShowCustomConfirm shows a dialog over the specified application using custom
// content. The cancel button will have the dismiss text set and the "OK" will use
// the confirm text. The response callback is called on user action.
// The MinSize() of the CanvasObject passed will be used to set the size of the window.
func ShowCustomConfirm(title, confirm, dismiss string, content fyne.CanvasObject,
	callback func(bool), parent fyne.Window) {
	d := &skydialog{content: content, title: title, icon: nil, parent: parent}
	d.response = make(chan bool, 1)
	d.callback = callback

	d.dismiss = &widget.Button{Text: dismiss, Icon: theme.CancelIcon(),
		OnTapped: func() {
			d.response <- false
		},
	}
	ok := &widget.Button{Text: confirm, Icon: theme.ConfirmIcon(), Importance: widget.HighImportance,
		OnTapped: func() {
			d.response <- true
		},
	}
	d.setButtons(container.NewHBox(layout.NewSpacer(), d.dismiss, ok, layout.NewSpacer()))

	d.Show()
}

// ProgressDialog is a simple dialog window that displays text and a progress bar.
type ProgressDialog struct {
	*skydialog

	bar *widget.ProgressBar
}

// SetValue updates the value of the progress bar - this should be between 0.0 and 1.0.
func (p *ProgressDialog) SetValue(v float64) {
	p.bar.SetValue(v)
}

// NewProgress creates a progress dialog and returns the handle.
// Using the returned type you should call Show() and then set its value through SetValue()
// cancelF will be called upon pressing the cancel button
// cancelText will be shown on the cancel button
func NewProgress(title, message string, parent fyne.Window, cancelF func(), cancelText string) *ProgressDialog {
	d := newDialog(title, message, theme.InfoIcon(), nil /*cancel?*/, parent)
	bar := widget.NewProgressBar()
	cancelBtn := &widget.Button{Text: cancelText, Icon: theme.CancelIcon(),
		OnTapped: func() {
			cancelF()
			d.response <- false
		}}
	content := container.NewVBox(bar, cancelBtn)
	d.setButtons(content)
	return &ProgressDialog{d, bar}
}
