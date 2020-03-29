package imager

import (
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"

	"github.com/SkycoinProject/skybian/pkg/bootparams"
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
	mx  sync.Mutex

	// Directories.
	baseDir  string
	finalDir string

	// Download progress values.
	dlTotal   int64
	dlCurrent int64

	// Meta data of extracted image(s).
	bImgs map[string]BaseImage
}

func NewBuilder(log logrus.FieldLogger, baseDir, finalDir string) *Builder {
	return &Builder{
		log: log,
		baseDir: baseDir,
		finalDir: finalDir,
		bImgs: make(map[string]BaseImage),
	}
}

func (b *Builder) DownloadPath() string {
	return filepath.Join(b.baseDir, "download"+ExtTarXz)
}

func (b *Builder) DownloadTotal() int64 {
	return atomic.LoadInt64(&b.dlTotal)
}

func (b *Builder) DownloadCurrent() int64 {
	return atomic.LoadInt64(&b.dlCurrent)
}

func (b *Builder) Download(url string) error {
	b.mx.Lock()
	defer b.mx.Unlock()

	return Download(b.log, url, b.DownloadPath(), &b.dlTotal, &b.dlCurrent)
}

func (b *Builder) ExtractArchive() (err error) {
	b.mx.Lock()
	defer b.mx.Unlock()

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
			img := b.bImgs[name]
			n, err := extractBaseImage(&img, f, b.baseDir)
			if err != nil {
				return err
			}
			b.bImgs[name] = img

			log.WithField("bytes", fmt.Sprintf("%dB", n)).
				WithField("dst", img.File.Name()).
				Info("Extracted file.")
			return nil
		}

		if name, ok := hasExtension(f.Name(), ExtMD5); ok {
			bImg := b.bImgs[name]
			if _, err := io.ReadFull(hex.NewDecoder(f), bImg.ExpectedMD5[:]); err != nil {
				return fmt.Errorf("failed to read %s within package: %v", f.Name(), err)
			}
			b.bImgs[name] = bImg

			log.WithField("MD5", hex.EncodeToString(bImg.ExpectedMD5[:])).
				Infof("Obtained expected MD5 hash for file %s%s", name, ExtImg)
			return nil
		}

		if name, ok := hasExtension(f.Name(), ExtSHA1); ok {
			bImg := b.bImgs[name]
			if _, err := io.ReadFull(hex.NewDecoder(f), bImg.ExpectedSHA1[:]); err != nil {
				return fmt.Errorf("failed to read %s within package: %v", f.Name(), err)
			}
			b.bImgs[name] = bImg

			log.WithField("SHA1", hex.EncodeToString(bImg.ExpectedMD5[:])).
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

	if verifyOrDelete(log, b.bImgs); len(b.bImgs) != 1 {
		return errors.New("failed to verify package contents")
	}

	return nil
}

func hasExtension(filename, ext string) (name string, ok bool) {
	name = strings.TrimSuffix(filename, ext)
	ok = len(name) < len(filename)
	return
}

func extractBaseImage(dstImg *BaseImage, srcF archiver.File, workDir string) (n int64, err error) {
	if err = dstImg.Init(filepath.Join(workDir, srcF.Name())); err != nil {
		return 0, err
	}
	if n, err = io.Copy(dstImg.Writer(), srcF); err != nil {
		return n, fmt.Errorf("failed to extract file %s from package: %v", srcF.Name(), err)
	}
	return n, err
}

func verifyOrDelete(log logrus.FieldLogger, bImgs map[string]BaseImage) {
	for name, bImg := range bImgs {
		log := log.WithField("img_file", name+ExtImg)

		if err := bImg.Verify(); err != nil {
			log.WithError(err).
				Error("Failed to verify base img file. Disregarding img...")
			delete(bImgs, name)
			continue
		}
		log.Info("Image verified.")
	}
}

func (b *Builder) MakeFinalImages(imgName string, bpsSlice []bootparams.BootParams) error {
	b.mx.Lock()
	defer b.mx.Unlock()

	bImg, ok := b.bImgs[imgName]
	if !ok {
		return fmt.Errorf("failed to find image '%s'", imgName)
	}

	var (
		fImgs   = make([]FinalImage, 0, len(bpsSlice))
		writers = make([]io.Writer, 0, len(bpsSlice))
	)
	for i, bp := range bpsSlice {
		name := filepath.Join(b.finalDir, fmt.Sprintf("image-%d.img", i))
		bps, err := bp.Encode()
		if err != nil {
			return fmt.Errorf("failed to decode boot_params[%d]: %v", i, err)
		}
		f, err := os.Create(name)
		if err != nil {
			return fmt.Errorf("failed to create %s: %v", name, err)
		}
		fImgs[i], writers[i] = FinalImage{f: f, bps: bps}, f
	}

	if _, err := bImg.File.Seek(0, 0); err != nil {
		return err
	}
	if _, err := io.Copy(io.MultiWriter(writers...), bImg.File); err != nil {
		return err
	}

	for i, fImg := range fImgs {
		if err := fImg.Finalize(); err != nil {
			return fmt.Errorf("failed to write boot params to final image %d (%s): %v", i, fImg.f.Name(), err)
		}
	}
	return nil
}

func (b *Builder) Images() []string {
	b.mx.Lock()
	defer b.mx.Unlock()

	out := make([]string, len(b.bImgs))
	for name := range b.bImgs {
		out = append(out, name)
	}
	return out
}