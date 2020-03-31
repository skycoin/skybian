package main

import (
	"flag"
	"fmt"
	"net"
	"net/http"

	"github.com/SkycoinProject/skycoin/src/util/logging"
	"github.com/rakyll/statik/fs"
	"github.com/zserge/webview"

	_ "github.com/SkycoinProject/skybian/cmd/skyimager-gui/statik"
	"github.com/SkycoinProject/skybian/pkg/imager"
)

var log = logging.MustGetLogger("skyimager")

var debug bool

func init() {
	const defaultDebug = false
	const usage = "whether to enable debug logging"
	flag.BoolVar(&debug, "debug", defaultDebug, usage)
}

const (
	guiWebView = "WEBVIEW"
	guiFyne    = "FYNE"
)

var guiType string

func init() {
	const defaultMode = guiFyne
	usage := fmt.Sprintf("GUI type to use %v", []string{guiWebView, guiFyne})
	flag.StringVar(&guiType, "ui", defaultMode, usage)
}

func main() {
	flag.Parse()

	assets, err := fs.New()
	if err != nil {
		log.WithError(err).Fatal("Failed to init statik filesystem.")
	}

	switch guiType {
	case guiFyne:
		imager.NewFyneGUI(log, assets).Run()
	case guiWebView:
		runWebviewGUI(assets)
	default:
		log.Fatalf("'%s' is not a valid gui.")
	}
}

func runWebviewGUI(assets http.FileSystem) {
	lis, err := net.Listen("tcp", "127.0.0.1:8080")
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

	w := webview.New(debug)
	defer w.Destroy()

	w.SetTitle("skyimager")
	w.SetSize(1200, 1100, webview.HintNone)
	w.Navigate("http://" + lis.Addr().String() + "/index.html")
	w.Run()
}

// https://godoc.org/github.com/skratchdot/open-golang/open
