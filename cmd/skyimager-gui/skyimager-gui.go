package main

import (
	"context"
	"flag"
	"fmt"
	"net"
	"net/http"
	"os"

	"fyne.io/fyne"
	"github.com/SkycoinProject/dmsg/cmdutil"
	_ "github.com/SkycoinProject/skybian/cmd/skyimager-gui/statik"
	"github.com/SkycoinProject/skybian/pkg/imager"
	"github.com/SkycoinProject/skycoin/src/util/logging"
	"github.com/rakyll/statik/fs"
	"github.com/skratchdot/open-golang/open"
)

var log = logging.MustGetLogger("skyimager")

var debug bool

func init() {
	const defaultDebug = false
	const usage = "whether to enable debug logging"
	flag.BoolVar(&debug, "debug", defaultDebug, usage)
}

const (
	guiBrowser = "BROWSER"
	guiFyne    = "FYNE"
)

var guiType string

func init() {
	const defaultMode = guiFyne
	usage := fmt.Sprintf("GUI type to use %v", []string{guiBrowser, guiFyne})
	flag.StringVar(&guiType, "ui", defaultMode, usage)
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




	switch guiType {
	case guiFyne:
		imager.NewFyneGUI(log, assets).Run()
	case guiBrowser:
		runWebviewGUI(assets)
	default:
		log.Fatalf("'%s' is not a valid gui.")
	}
}

func runWebviewGUI(assets http.FileSystem) {
	ctx, cancel := cmdutil.SignalContext(context.Background(), log)
	defer cancel()

	lis, err := net.Listen("tcp", "127.0.0.1:")
	if err != nil {
		log.WithError(err).Fatal("Failed to listen TCP.")
	}
	defer func() {
		if err := lis.Close(); err != nil {
			log.WithError(err).Fatal("Failed to close TCP listener.")
		}
	}()
	log.WithField("net", lis.Addr().Network()).
		WithField("addr", lis.Addr().String()).
		Info("Listening...")

	mux := imager.MakeHTTPServeMux()
	mux.Handle("/", http.FileServer(assets))
	go func() {
		if err := http.Serve(lis, mux); err != nil {
			log.WithError(err).Debug("Stopped serving HTTP.")
		}
	}()

	if err := open.Run("http://" + lis.Addr().String() + "/index.html"); err != nil {
		log.WithError(err).Error("Failed to open browser.")
	}

	<-ctx.Done()
}

// https://godoc.org/github.com/skratchdot/open-golang/open
