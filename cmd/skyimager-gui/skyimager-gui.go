package main

import (
	"flag"
	"net"
	"net/http"

	"github.com/SkycoinProject/skycoin/src/util/logging"
	"github.com/rakyll/statik/fs"
	"github.com/zserge/webview"

	"github.com/SkycoinProject/skybian/pkg/imager"

	_ "github.com/SkycoinProject/skybian/cmd/skyimager-gui/statik"
)

var log = logging.MustGetLogger("skyimager")

var debug bool

func init() {
	const defaultDebug = false
	const usage = "whether to enable debug logging"
	flag.BoolVar(&debug, "debug", defaultDebug, usage)
	flag.BoolVar(&debug, "d", defaultDebug, "shorthand for 'debug'")
}

func main() {
	flag.Parse()

	assets, err := fs.New()
	if err != nil {
		log.WithError(err).Fatal("Failed to init statik filesystem.")
	}

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

	mux := imager.MakeServeMux()
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
