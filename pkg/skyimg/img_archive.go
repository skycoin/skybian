package skyimg

import (
	"encoding/hex"
	"fmt"
	"io"
	"path/filepath"
	"strings"

	"github.com/mholt/archiver"
	"github.com/sirupsen/logrus"
)

// File extensions which we expect to see in the archive.
const (
	ExtImg  = ".img"
	ExtMD5  = ".img.md5"
	ExtSHA1 = ".img.sha1"
)

type ImgArchive struct {
	log      logrus.Logger
	dlDir    string
	workDir  string
	finalDir string
	images   map[string]ImgFile
}

func (a *ImgArchive) Images() []string {
	out := make([]string, len(a.images))
	for name := range a.images {
		out = append(out, name)
	}
	return out
}

func (a *ImgArchive) AvailableDownloads() []string {
	return []string{}
}

func (a *ImgArchive) Download(url string) error {
}

func (a *ImgArchive) Extract(pkgFile string) (err error) {
	log := a.log.WithField("func", "ExtractPackage")

	tarXz := archiver.NewTarXz()
	defer func() {
		if err := tarXz.Close(); err != nil {
			log.WithError(err).Error("Failed to close archiver.")
		}
		a.verifyOrDelete()
	}()

	return tarXz.Walk(pkgFile, func(f archiver.File) error {
		if f.IsDir() {
			return nil
		}

		if name, ok := hasExtension(f.Name(), ExtImg); ok {
			img := a.images[name]
			n, err := extractImgFile(&img, f, a.workDir)
			if err != nil {
				return err
			}
			a.images[name] = img

			log.WithField("bytes", fmt.Sprintf("%dB", n)).
				WithField("dst", img.File.Name()).
				Info("Extracted file.")
			return nil
		}

		if name, ok := hasExtension(f.Name(), ExtMD5); ok {
			img := a.images[name]
			if _, err := io.ReadFull(hex.NewDecoder(f), img.ExpectedMD5[:]); err != nil {
				return fmt.Errorf("failed to read %s within package: %v", f.Name(), err)
			}
			a.images[name] = img

			log.WithField("MD5", hex.EncodeToString(img.ExpectedMD5[:])).
				Infof("Obtained expected MD5 hash for file %s%s", name, ExtImg)
			return nil
		}

		if name, ok := hasExtension(f.Name(), ExtSHA1); ok {
			img := a.images[name]
			if _, err := io.ReadFull(hex.NewDecoder(f), img.ExpectedSHA1[:]); err != nil {
				return fmt.Errorf("failed to read %s within package: %v", f.Name(), err)
			}
			a.images[name] = img

			log.WithField("SHA1", hex.EncodeToString(img.ExpectedMD5[:])).
				Infof("Obtained expected SHA1 hash for file %s%s", name, ExtImg)
			return nil
		}

		log.WithField("file_name", f.Name()).Debug("Skipping file...")
		return nil
	})
}

func (a *ImgArchive) SetupBootLoader() {

}

func (a *ImgArchive) verifyOrDelete() {
	log := a.log.WithField("func", "VerifyOrDelete")

	for name, img := range a.images {
		log := log.WithField("img_file", name+ExtImg)

		if err := img.Verify(); err != nil {
			log.WithError(err).
				Error("Failed to verify img file. Disregarding img...")
			delete(a.images, name)
			continue
		}
		log.Info("Image verified.")
	}
}

func hasExtension(filename, ext string) (name string, ok bool) {
	name = strings.TrimSuffix(filename, ext)
	ok = len(name) < len(filename)
	return
}

func extractImgFile(dstImg *ImgFile, srcF archiver.File, workDir string) (n int64, err error) {
	if err = dstImg.Init(filepath.Join(workDir, srcF.Name())); err != nil {
		return 0, err
	}
	if n, err = io.Copy(dstImg.Writer(), srcF); err != nil {
		return n, fmt.Errorf("failed to extract file %s from package: %v", srcF.Name(), err)
	}
	return n, err
}
