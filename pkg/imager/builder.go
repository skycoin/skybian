package imager

import (
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"path/filepath"
	"strings"
	"sync/atomic"

	"github.com/mholt/archiver"
	"github.com/sirupsen/logrus"
)

// File extensions which we expect to see in the archive.
const (
	ExtTmp   = ".tmp"
	ExtTarXz = ".tar.xz"
	ExtImg   = ".img"
	ExtMD5   = ".img.md5"
	ExtSHA1  = ".img.sha1"
)

type Builder struct {
	log logrus.FieldLogger

	// Directories.
	workDir  string
	finalDir string

	// Download progress values.
	dlTotal   int64
	dlCurrent int64

	// Meta data of extracted image(s).
	images map[string]File
}

func (b *Builder) DownloadPath() string {
	return filepath.Join(b.workDir, "download"+ExtTarXz)
}

func (b *Builder) DownloadTotal() int64 {
	return atomic.LoadInt64(&b.dlTotal)
}

func (b *Builder) DownloadCurrent() int64 {
	return atomic.LoadInt64(&b.dlCurrent)
}

func (b *Builder) Download(url string) error {
	return Download(b.log, url, b.DownloadPath(), &b.dlTotal, &b.dlCurrent)
}

func (b *Builder) ExtractArchive() (err error) {
	log := b.log.WithField("func", "ExtractPackage")

	pkgFile := b.DownloadPath()
	log.WithField("file", pkgFile).Info("Extracting...")

	tarXz := archiver.NewTarXz()
	defer func() {
		if err := tarXz.Close(); err != nil {
			log.WithError(err).Error("Failed to close archiver.")
		}
	}()

	walkFn := func(f archiver.File) error {
		if _, ok := hasExtension(f.Name(), ExtTarXz); ok || f.IsDir() {
			log.WithField("file_name", f.Name()).
				Debug("Skipping...")
			return nil
		}

		if name, ok := hasExtension(f.Name(), ExtImg); ok {
			img := b.images[name]
			n, err := extractImgFile(&img, f, b.workDir)
			if err != nil {
				return err
			}
			b.images[name] = img

			log.WithField("bytes", fmt.Sprintf("%dB", n)).
				WithField("dst", img.File.Name()).
				Info("Extracted file.")
			return nil
		}

		if name, ok := hasExtension(f.Name(), ExtMD5); ok {
			img := b.images[name]
			if _, err := io.ReadFull(hex.NewDecoder(f), img.ExpectedMD5[:]); err != nil {
				return fmt.Errorf("failed to read %s within package: %v", f.Name(), err)
			}
			b.images[name] = img

			log.WithField("MD5", hex.EncodeToString(img.ExpectedMD5[:])).
				Infof("Obtained expected MD5 hash for file %s%s", name, ExtImg)
			return nil
		}

		if name, ok := hasExtension(f.Name(), ExtSHA1); ok {
			img := b.images[name]
			if _, err := io.ReadFull(hex.NewDecoder(f), img.ExpectedSHA1[:]); err != nil {
				return fmt.Errorf("failed to read %s within package: %v", f.Name(), err)
			}
			b.images[name] = img

			log.WithField("SHA1", hex.EncodeToString(img.ExpectedMD5[:])).
				Infof("Obtained expected SHA1 hash for file %s%s", name, ExtImg)
			return nil
		}

		log.WithField("file_name", f.Name()).
			Warn("Skipping unexpected file...")
		return nil
	}

	if err = tarXz.Walk(pkgFile, walkFn); err != nil {
		return err
	}

	if verifyOrDelete(log, b.images); len(b.images) != 1 {
		return errors.New("failed to verify package contents")
	}

	return nil
}

func hasExtension(filename, ext string) (name string, ok bool) {
	name = strings.TrimSuffix(filename, ext)
	ok = len(name) < len(filename)
	return
}

func extractImgFile(dstImg *File, srcF archiver.File, workDir string) (n int64, err error) {
	if err = dstImg.Init(filepath.Join(workDir, srcF.Name())); err != nil {
		return 0, err
	}
	if n, err = io.Copy(dstImg.Writer(), srcF); err != nil {
		return n, fmt.Errorf("failed to extract file %s from package: %v", srcF.Name(), err)
	}
	return n, err
}

func verifyOrDelete(log logrus.FieldLogger, images map[string]File) {
	for name, img := range images {
		log := log.WithField("img_file", name+ExtImg)

		if err := img.Verify(); err != nil {
			log.WithError(err).
				Error("Failed to verify img file. Disregarding img...")
			delete(images, name)
			continue
		}
		log.Info("Image verified.")
	}
}

func (b *Builder) FinalizeImage() {

}

func (b *Builder) Images() []string {
	out := make([]string, len(b.images))
	for name := range b.images {
		out = append(out, name)
	}
	return out
}
