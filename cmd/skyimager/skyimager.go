package main //nolint:typecheck

import (
	"context"
	"encoding/json"
	"flag"
	"os"
	"path/filepath"

	"github.com/skycoin/skycoin/src/util/logging"

	"github.com/skycoin/skybian/pkg/boot"
	"github.com/skycoin/skybian/pkg/imager"
)

// TODO
var log = logging.MustGetLogger("skyimager")

var root string

func init() {
	defaultWorkDir := func() string {
		home, _ := os.UserHomeDir()
		return filepath.Join(home, "./skyimager")
	}()
	flag.StringVar(&root, "root", defaultWorkDir, "root directory used by skyimager")
}

var dlURL string

func init() {
	defaultDlURL, _ := imager.LatestBaseImgURL(context.Background(), imager.TypeSkybian, log)
	flag.StringVar(&dlURL, "url", defaultDlURL, "url of skybian image archive")
}

func main() {
	flag.Parse()

	var bpsSlice []boot.Params
	if err := json.NewDecoder(os.Stdin).Decode(&bpsSlice); err != nil {
		log.WithError(err).Fatal("Failed to read boot params from STDIN.")
	}

	if err := imager.CLIBuild(log, root, dlURL, bpsSlice); err != nil {
		log.WithError(err).Fatal("Build failed.")
	}

	log.Info("You can now flash your images using a tools such as balenaEtcher: https://www.balena.io/etcher/")
	log.Info("Bye bye!")
}
