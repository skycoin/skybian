package imager

import (
	"bytes"
	"crypto/md5"  // nolint
	"crypto/sha1" // nolint
	"errors"
	"fmt"
	"hash"
	"io"
	"os"

	"github.com/skycoin/skybian/pkg/boot"
)

// BaseImage represents a base image file extracted from the downloaded archive.
type BaseImage struct {
	File         *os.File
	MD5          hash.Hash
	SHA1         hash.Hash
	ExpectedMD5  [md5.Size]byte
	ExpectedSHA1 [sha1.Size]byte
}

// Init initializes BaseImage from a given filename.
func (bi *BaseImage) Init(filename string) error {
	if bi.File == nil {
		osF, err := os.Create(filename)
		if err != nil {
			return fmt.Errorf("failed to create img file: %v", err)
		}
		bi.File = osF
		bi.MD5 = md5.New()   // nolint
		bi.SHA1 = sha1.New() // nolint
	}
	return nil
}

// Writer returns an io.Writer implementation which writes to BaseImage.
func (bi *BaseImage) Writer() io.Writer {
	return io.MultiWriter(bi.File, bi.MD5, bi.SHA1)
}

// Verify verifies the validity of the BaseImage.
func (bi *BaseImage) Verify() error {
	if !bytes.Equal(bi.ExpectedMD5[:], bi.MD5.Sum(nil)) {
		return errors.New("MD5 hash does not match expected")
	}
	if !bytes.Equal(bi.ExpectedSHA1[:], bi.SHA1.Sum(nil)) {
		return errors.New("SHA1 hash does not match expected")
	}
	return nil
}

// FinalImage represents a final image.
type FinalImage struct {
	f   *os.File
	bps []byte
}

// Finalize writes the boot parameters to the final image.
func (fi FinalImage) Finalize() error {
	if err := boot.WriteRawToFile(fi.f, fi.bps); err != nil {
		return err
	}
	return fi.f.Close()
}
