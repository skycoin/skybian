package prepconf

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestGenCert(t *testing.T) {
	dir, err := ioutil.TempDir(os.TempDir(), "prepare_TestGenCert")
	require.NoError(t, err)
	defer func() { require.NoError(t, os.RemoveAll(dir)) }()

	cert := filepath.Join(dir, "cert.pem")
	key := filepath.Join(dir, "key.pem")
	require.NoError(t, GenCert(cert, key))
}
