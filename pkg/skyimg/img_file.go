package skyimg

import (
	"bytes"
	"crypto/md5"
	"crypto/sha1"
	"errors"
	"fmt"
	"hash"
	"io"
	"os"
)

type ImgFile struct {
	File         *os.File
	MD5          hash.Hash
	SHA1         hash.Hash
	ExpectedMD5  [md5.Size]byte
	ExpectedSHA1 [sha1.Size]byte
}

func (img *ImgFile) Init(filename string) error {
	if img.File == nil {
		f, err := os.Create(filename)
		if err != nil {
			return fmt.Errorf("failed to create img file: %v", err)
		}
		img.File = f
		img.MD5 = md5.New()
		img.SHA1 = sha1.New()
	}
	return nil
}

func (img *ImgFile) Writer() io.Writer {
	return io.MultiWriter(img.File, img.MD5, img.SHA1)
}

func (img *ImgFile) Verify() error {
	if !bytes.Equal(img.ExpectedMD5[:], img.MD5.Sum(nil)) {
		return errors.New("MD5 hashes do not match")
	}
	if !bytes.Equal(img.ExpectedSHA1[:], img.SHA1.Sum(nil)) {
		return errors.New("SHA1 hashes do not match")
	}
	return nil
}
