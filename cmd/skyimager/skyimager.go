package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/SkycoinProject/skybian/pkg/bootparams"
	"github.com/SkycoinProject/skybian/pkg/imager"
	"github.com/sirupsen/logrus"
)

// TODO
var log = logrus.New()

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
	const defaultDlURL = "https://todo.com/todo.tar.xz"
	flag.StringVar(&dlURL, "url", defaultDlURL,
		"url of skybian image archive")
}

func main() {
	flag.Parse()

	var bpsSlice []bootparams.BootParams
	if err := json.NewDecoder(os.Stdin).Decode(&bpsSlice); err != nil {
		log.WithError(err).Fatal("Failed to read boot params from STDIN.")
	}

	builder := imager.NewBuilder(log,
		filepath.Join(root, "base"),
		filepath.Join(root, "final"))

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
				fmt.Printf("DOWNLOAD: %d/%dB\n", current, total)
			}
		}
	}()

	if err := builder.Download(dlURL); err != nil {
		log.WithError(err).Fatal("Download failed.")
	}
	close(dlDone)

	if err := builder.ExtractArchive(); err != nil {
		log.WithError(err).Fatal("Failed to extract archive.")
	}

	imgs := builder.Images()
	fmt.Println("IMAGES:", imgs)

	if len(imgs) == 0 {
		log.Fatal("No valid images in archive.")
	}

	img := imgs[0]
	if err := builder.MakeFinalImages(img, bpsSlice); err != nil {
		log.WithError(err).Fatal("Failed to make final images.")
	}

	fmt.Println("Done!")
}
