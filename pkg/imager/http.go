package imager

import (
	"encoding/json"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/SkycoinProject/dmsg/httputil"
	"github.com/SkycoinProject/skybian/pkg/boot"
	"github.com/SkycoinProject/skycoin/src/util/logging"
	"github.com/sirupsen/logrus"
	"github.com/skratchdot/open-golang/open"
	"nhooyr.io/websocket"
)

func MakeHTTPServeMux() *http.ServeMux {
	latestDlURL := func(w http.ResponseWriter, r *http.Request) {
		httputil.WriteJSON(w, r, http.StatusOK, DefaultDlURL)
	}
	defaultWorkDir := func(w http.ResponseWriter, r *http.Request) {
		homeDir, _ := os.UserHomeDir()
		httputil.WriteJSON(w, r, http.StatusOK, filepath.Join(homeDir, "skyimager"))
	}
	bpsTemplate := func(w http.ResponseWriter, r *http.Request) {
		var (
			n   = 3
			gw  = ""
			hvs = make([]string, 0)
		)
		if nRaw := r.URL.Query().Get("n"); nRaw != "" {
			var err error
			if n, err = strconv.Atoi(nRaw); err != nil {
				httputil.WriteJSON(w, r, http.StatusBadRequest, err)
				return
			}
		}
		if gwRaw := r.URL.Query().Get("gw"); gwRaw != "" {
			gw = gwRaw
		}
		if hvsRaw := append(r.URL.Query()["hv"], r.URL.Query()["hvs"]...); len(hvsRaw) > 0 {
			for _, hvRaw := range hvsRaw {
				if len(hvRaw) == 0 {
					continue
				}
				hvs = append(hvs, strings.TrimSpace(hvRaw))
			}
		}
		bpsSlice, err := GenerateBootParams(n, gw, hvs)
		if err != nil {
			httputil.WriteJSON(w, r, http.StatusBadRequest, err)
			return
		}
		r.URL.Query().Set("pretty", "true")
		httputil.WriteJSON(w, r, http.StatusOK, bpsSlice)
	}
	downloadAndBuild := func(w http.ResponseWriter, r *http.Request) {
		var (
			wd  = r.URL.Query().Get("wd")
			url = r.URL.Query().Get("url")
			bps []boot.Params
		)

		ws, err := websocket.Accept(w, r, nil)
		if err != nil {
			return
		}
		conn := websocket.NetConn(r.Context(), ws, websocket.MessageText)

		// Read boot params from ws.
		if err := json.NewDecoder(conn).Decode(&bps); err != nil {
			logrus.WithError(err).Error("Failed to parse boot parameters.")
			_ = ws.Close(websocket.StatusUnsupportedData, "")
			return
		}

		// Write build logs to ws.
		log := (&logrus.Logger{
			Out: io.MultiWriter(conn, os.Stderr),
			Formatter: &logging.TextFormatter{
				FullTimestamp:      true,
				AlwaysQuoteStrings: true,
				QuoteEmptyFields:   true,
				ForceFormatting:    true,
				DisableColors:      false,
				ForceColors:        false,
			},
			Hooks: make(logrus.LevelHooks),
			Level: logrus.DebugLevel,
		}).WithField("_module", "skyimager")

		if err := Build(log, wd, url, bps); err != nil {
			log.WithError(err).Error()
			_ = ws.Close(websocket.StatusInternalError, "")
			return
		}

		_ = open.Run(filepath.Join(wd, "final"))
		_ = ws.Close(websocket.StatusNormalClosure, "")
	}
	quit := func(w http.ResponseWriter, r *http.Request) {
		os.Exit(0)
	}
	mux := http.NewServeMux()
	mux.Handle("/api/latest-dl-url", http.HandlerFunc(latestDlURL))
	mux.Handle("/api/work-dir", http.HandlerFunc(defaultWorkDir))
	mux.Handle("/api/bps-template", http.HandlerFunc(bpsTemplate))
	mux.Handle("/api/build", http.HandlerFunc(downloadAndBuild))
	mux.Handle("/api/quit", http.HandlerFunc(quit))
	return mux
}
