package imager

import (
	"io/ioutil"
	"net/http"
	"sync"

	"fyne.io/fyne"
)

// fyne resource mutex
var frMx = new(sync.Mutex)

type fyneResource struct {
	f http.File
}

func (fr fyneResource) Name() string {
	fi, err := fr.f.Stat()
	if err != nil {
		panic(err)
	}
	return fi.Name()
}

func (fr fyneResource) Content() []byte {
	frMx.Lock()
	defer frMx.Unlock()

	if _, err := fr.f.Seek(0, 0); err != nil {
		panic(err)
	}
	b, err := ioutil.ReadAll(fr.f)
	if err != nil {
		panic(err)
	}
	return b
}

func loadResource(assets http.FileSystem, name string) fyne.Resource {
	f, err := assets.Open(name)
	if err != nil {
		panic(err)
	}
	return &fyneResource{f: f}
}
