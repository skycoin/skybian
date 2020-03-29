package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/SkycoinProject/skycoin/src/util/logging"

	"github.com/SkycoinProject/skybian/pkg/bootparams"
	"github.com/SkycoinProject/skybian/pkg/imager"
)

// TODO
var log = logging.MustGetLogger("skyimager")

var root string

func init() {
	defaultWorkDir := func() string {
		home, _ := os.UserHomeDir()
		return filepath.Join(home, "./skyimager")
	}()
	flag.StringVar(&root, "root", defaultWorkDir,
		"root directory used by skyimager")
}

var dlURL string

func init() {
	const defaultDlURL = "https://github.com/evanlinjin/skybian/releases/download/v0.1.1-alpha.1/Skybian-v0.1.1.tar.xz"
	flag.StringVar(&dlURL, "url", defaultDlURL,
		"url of skybian image archive")
}

func main() {
	flag.Parse()

	var bpsSlice []bootparams.BootParams
	if err := json.NewDecoder(os.Stdin).Decode(&bpsSlice); err != nil {
		log.WithError(err).Fatal("Failed to read boot params from STDIN.")
	}

	log.Info("Initializing builder...")

	var (
		baseDir  = filepath.Join(root, "base")
		finalDir = filepath.Join(root, "final")
	)

	builder, err := imager.NewBuilder(log, baseDir, finalDir)
	if err != nil {
		log.WithError(err).Fatal("Failed to init builder.")
	}

	dlDone := make(chan struct{})
	ticker := time.NewTicker(time.Second)
	go func() {
		for {
			select {
			case <-dlDone:
				ticker.Stop()
				return
			case <-ticker.C:
			}
			total := builder.DownloadTotal()
			current := builder.DownloadCurrent()
			if total > 0 || current > 0 {
				fmt.Printf("Downloading... %d%% (%d bytes)\r", current*100/total, current)
			}
		}
	}()

	log.WithField("url", dlURL).Info("Downloading base image archive...")
	if err := builder.Download(dlURL); err != nil {
		log.WithError(err).Fatal("Download failed.")
	}
	close(dlDone)

	if err := builder.ExtractArchive(); err != nil {
		log.WithError(err).Fatal("Failed to extract archive.")
	}

	imgs := builder.Images()
	log.WithField("n", len(imgs)).
		WithField("imgs", imgs).
		Info("Obtained base images.")

	if len(imgs) == 0 {
		log.Fatal("No valid images in archive.")
	}

	if err := builder.MakeFinalImages(imgs[0], bpsSlice); err != nil {
		log.WithError(err).Fatal("Failed to make final images.")
	}

	log.WithField("final_dir", finalDir).Info("Final images are created!")
}
