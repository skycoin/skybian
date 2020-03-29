package imager

import (
	"bytes"
	"crypto/md5"
	"crypto/sha1"
	"errors"
	"fmt"
	"hash"
	"io"
	"os"

	"github.com/SkycoinProject/skybian/pkg/bootparams"
)

type BaseImage struct {
	File         *os.File
	MD5          hash.Hash
	SHA1         hash.Hash
	ExpectedMD5  [md5.Size]byte
	ExpectedSHA1 [sha1.Size]byte
}

func (bi *BaseImage) Init(filename string) error {
	if bi.File == nil {
		osF, err := os.Create(filename)
		if err != nil {
			return fmt.Errorf("failed to create img file: %v", err)
		}
		bi.File = osF
		bi.MD5 = md5.New()
		bi.SHA1 = sha1.New()
	}
	return nil
}

func (bi *BaseImage) Writer() io.Writer {
	return io.MultiWriter(bi.File, bi.MD5, bi.SHA1)
}

func (bi *BaseImage) Verify() error {
	if !bytes.Equal(bi.ExpectedMD5[:], bi.MD5.Sum(nil)) {
		return errors.New("MD5 hash does not match expected")
	}
	if !bytes.Equal(bi.ExpectedSHA1[:], bi.SHA1.Sum(nil)) {
		return errors.New("SHA1 hash does not match expected")
	}
	return nil
}

type FinalImage struct {
	f   *os.File
	bps []byte
}

func (fi FinalImage) Finalize() error {
	if err := bootparams.WriteToFile(fi.f, fi.bps); err != nil {
		return err
	}
	return fi.f.Close()
}