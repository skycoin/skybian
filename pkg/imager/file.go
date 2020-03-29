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
)

type File struct {
	File         *os.File
	MD5          hash.Hash
	SHA1         hash.Hash
	ExpectedMD5  [md5.Size]byte
	ExpectedSHA1 [sha1.Size]byte
}

func (f *File) Init(filename string) error {
	if f.File == nil {
		osF, err := os.Create(filename)
		if err != nil {
			return fmt.Errorf("failed to create img file: %v", err)
		}
		f.File = osF
		f.MD5 = md5.New()
		f.SHA1 = sha1.New()
	}
	return nil
}

func (f *File) Writer() io.Writer {
	return io.MultiWriter(f.File, f.MD5, f.SHA1)
}

func (f *File) Verify() error {
	if !bytes.Equal(f.ExpectedMD5[:], f.MD5.Sum(nil)) {
		return errors.New("MD5 hash does not match expected")
	}
	if !bytes.Equal(f.ExpectedSHA1[:], f.SHA1.Sum(nil)) {
		return errors.New("SHA1 hash does not match expected")
	}
	return nil
}
