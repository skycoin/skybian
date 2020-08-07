package imager

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/sirupsen/logrus"

	"github.com/skycoin/skybian/pkg/boot"
)

const readmeTxt = `These skybian images are ready to be flashed to disk!

Use a tool such as balenaEtcher: https://www.balena.io/etcher/

Enjoy!
`

// CLIBuild is used by the CLI to download and build images.
func CLIBuild(log logrus.FieldLogger, root, dlURL string, bpsSlice []boot.Params) error {
	log.Info("Initializing builder...")

	builder, err := NewBuilder(log, root)
	if err != nil {
		return fmt.Errorf("failed to init builder: %v", err)
	}

	log.WithField("url", dlURL).Info("Downloading base image archive...")

	dlErr := make(chan error, 1)
	dlT := time.NewTicker(time.Second * 1)
	go func() {
		dlErr <- builder.Download(dlURL)
		close(dlErr)
	}()

	var lastPC string // last dl progress %

	for {
		select {
		case <-dlT.C:
			total := builder.DownloadTotal()
			current := builder.DownloadCurrent()
			if total > 0 || current > 0 {
				pc := fmt.Sprintf("%d%%", current*100/total)
				if pc == lastPC {
					continue
				}
				lastPC = pc
				log.WithField("progress", pc).
					WithField("downloaded", fmt.Sprintf("%dB", current)).
					Info("Downloading base image.")
			}
		case err := <-dlErr:
			if dlT.Stop(); err != nil {
				return fmt.Errorf("download failed: %v", err)
			}
			goto DownloadDone
		}
	}
DownloadDone:

	if err := builder.ExtractArchive(); err != nil {
		return fmt.Errorf("failed to extract archive: %v", err)
	}

	imgs := builder.Images()
	log.WithField("n", len(imgs)).
		WithField("imgs", imgs).
		Info("Obtained base images.")

	if len(imgs) == 0 {
		return errors.New("no valid images in archive")
	}

	if err := builder.MakeFinalImages(imgs[0], bpsSlice); err != nil {
		return fmt.Errorf("failed to make final images: %v", err)
	}

	log.WithField("dir", builder.finalDir).Info("Final images are created!")

	createREADME(log, filepath.Join(builder.finalDir, "README.txt"))
	return nil
}

func createREADME(log logrus.FieldLogger, path string) {
	readme, err := os.Create(path)
	if err != nil {
		log.WithError(err).Error("Failed to create README.txt")
		return
	}
	if _, err := readme.WriteString(readmeTxt); err != nil {
		log.WithError(err).Error("Failed to write README.txt")
	}
	if err := readme.Close(); err != nil {
		log.WithError(err).Error("Failed to close README.txt")
	}
}
