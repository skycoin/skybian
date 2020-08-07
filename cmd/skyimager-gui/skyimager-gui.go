package main //nolint:typecheck

import (
	"flag"
	"fmt"
	"os"

	"fyne.io/fyne"
	"github.com/rakyll/statik/fs"
	"github.com/skycoin/skycoin/src/util/logging"

	_ "github.com/skycoin/skybian/cmd/skyimager-gui/statik"
	"github.com/skycoin/skybian/pkg/imager"
)

var log = logging.MustGetLogger("skyimager")

var debug bool

func init() {
	const defaultDebug = false
	const usage = "whether to enable debug logging"
	flag.BoolVar(&debug, "debug", defaultDebug, usage)
}

var uiScale float64

func init() {
	const defaultUIScale = float64(fyne.SettingsScaleAuto)
	usage := fmt.Sprintf("Scale of FYNE interface. If set to %v, FYNE will scale according to DPI.", defaultUIScale)
	flag.Float64Var(&uiScale, "scale", defaultUIScale, usage)
}

func main() {
	flag.Parse()

	_ = os.Setenv("FYNE_SCALE", fmt.Sprint(uiScale))

	assets, err := fs.New()
	if err != nil {
		log.WithError(err).Fatal("Failed to init statik filesystem.")
	}
	imager.NewFyneUI(log, assets).Run()
}

// https://godoc.org/github.com/skratchdot/open-golang/open
