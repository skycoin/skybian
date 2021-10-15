package imager

import (
	"io"
	"net/http"
	"os"
	"sync"
	"sync/atomic"

	"github.com/sirupsen/logrus"
	"golang.org/x/net/context"
)

func download(ctx context.Context, log logrus.FieldLogger, url, dst string, total, current *int64) error {
	log = log.WithField("func", "Download")

	// Prepare temp destination file.
	f, err := os.Create(dst + ExtTmp)
	if err != nil {
		return err
	}
	closeF := makeOnceCloser(log, f)
	defer closeF()

	// Prepare download response.
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return err
	}

	resp, err := http.DefaultClient.Do(request)
	if err != nil {
		return err
	}
	defer func() {
		if err := resp.Body.Close(); err != nil {
			log.WithError(err).Error("Failed to close http.Response body.")
		}
	}()

	// Set atomic 'total' value.
	atomic.StoreInt64(total, resp.ContentLength)

	// Write to temp destination.
	// Also record progress in 'current' via writeCounter{}.
	w := io.MultiWriter(f, &writeCounter{current: current})
	if _, err := io.Copy(w, resp.Body); err != nil {
		log.WithError(err).Error("Failed to write file.")
		return err
	}

	// On success, close file to mv to final file.
	closeF()
	return os.Rename(dst+ExtTmp, dst)
}

func makeOnceCloser(log logrus.FieldLogger, c io.Closer) func() {
	once := new(sync.Once)
	return func() {
		once.Do(func() {
			if err := c.Close(); err != nil {
				log.WithError(err).Error("Close returned non-nil error.")
			}
		})
	}
}

type writeCounter struct {
	current *int64
}

func (wc writeCounter) Write(p []byte) (int, error) {
	n := len(p)
	atomic.AddInt64(wc.current, int64(n))
	return n, nil
}
