package main

import (
	_ "embed"

	"fyne.io/fyne/v2"
	"github.com/skycoin/skycoin/src/util/logging"

	"github.com/skycoin/skybian/pkg/imager"
)

//go:embed static/icon.png
var icon []byte
var staticIcon = &fyne.StaticResource{
	StaticName:    "icon.png",
	StaticContent: icon,
}
var log = logging.MustGetLogger("skyimager")

func main() {
	imager.NewFyneUI(log, staticIcon).Run()
}

// https://godoc.org/github.com/skratchdot/open-golang/open
