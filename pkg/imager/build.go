package imager

import (
	"errors"
	"fmt"
	"path/filepath"
	"time"

	"github.com/sirupsen/logrus"

	"github.com/SkycoinProject/skybian/pkg/bootparams"
)

func Build(log logrus.FieldLogger, root, dlURL string, bpsSlice []bootparams.BootParams) error {
	var (
		baseDir  = filepath.Join(root, "base")
		finalDir = filepath.Join(root, "final")
	)

	log.Info("Initializing builder...")

	builder, err := NewBuilder(log, baseDir, finalDir)
	if err != nil {
		return fmt.Errorf("failed to init builder: %v", err)
	}

	log.WithField("url", dlURL).Info("Downloading base image archive...")

	dlErr := make(chan error, 1)
	dlT := time.NewTicker(time.Second)
	go func() {
		dlErr <- builder.Download(dlURL)
		close(dlErr)
	}()
	for {
		select {
		case <-dlT.C:
			total := builder.DownloadTotal()
			current := builder.DownloadCurrent()
			if total > 0 || current > 0 {
				fmt.Printf("Downloading... %d%% (%d bytes)\r", current*100/total, current)
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

	log.WithField("dir", finalDir).Info("Final images are created!")
	return nil
}
