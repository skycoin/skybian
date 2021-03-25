package prepconf

import (
	"io/ioutil"
	"log"
	"net"
	"os"
	"path/filepath"
	"testing"

	"github.com/skycoin/dmsg/cipher"
	"github.com/stretchr/testify/require"

	"github.com/skycoin/skybian/pkg/boot"
)

func TestPrepare(t *testing.T) {
	logger := log.New(os.Stderr, "", log.LstdFlags)

	dir, err := ioutil.TempDir(os.TempDir(), "TestPrepare")
	require.NoError(t, err)
	defer func() { require.NoError(t, os.RemoveAll(dir)) }()
	pk, sk := cipher.GenerateKeyPair()
	vConf := Config{
		Filename: "vskyconf.json",
		TLSKey:   filepath.Join(dir, "key.pem"),
		TLSCert:  filepath.Join(dir, "cert.pem"),
		BootParams: boot.Params{
			Mode:             boot.VisorMode,
			LocalIP:          net.ParseIP(boot.DefaultGatewayIP),
			GatewayIP:        net.ParseIP(boot.DefaultGatewayIP),
			LocalPK:          pk,
			LocalSK:          sk,
			HypervisorPKs:    []cipher.PubKey{pk},
			SkysocksPasscode: "test",
		},
	}
	hConf := Config{
		Filename: "hvskyconf.json",
		TLSKey:   filepath.Join(dir, "key.pem"),
		TLSCert:  filepath.Join(dir, "cert.pem"),
		BootParams: boot.Params{
			Mode:             boot.HypervisorMode,
			LocalIP:          net.ParseIP(boot.DefaultGatewayIP),
			GatewayIP:        net.ParseIP(boot.DefaultGatewayIP),
			LocalPK:          pk,
			LocalSK:          sk,
			HypervisorPKs:    []cipher.PubKey{pk},
			SkysocksPasscode: "test",
		},
	}
	defer func() {
		os.Remove(vConf.Filename)
		os.Remove(hConf.Filename)
	}()
	require.NoError(t, GenerateConfigFile(vConf, logger))
	v1, err := ioutil.ReadFile(vConf.Filename)
	require.NoError(t, err)

	vConf.BootParams.LocalPK, vConf.BootParams.LocalSK = cipher.GenerateKeyPair()
	require.NoError(t, GenerateConfigFile(vConf, logger))
	v2, err := ioutil.ReadFile(vConf.Filename)
	require.NoError(t, err)

	require.NoError(t, GenerateConfigFile(hConf, logger))
	v3, err := ioutil.ReadFile(hConf.Filename)
	require.NoError(t, err)

	vConf.BootParams.LocalPK, vConf.BootParams.LocalSK = cipher.GenerateKeyPair()
	require.NoError(t, GenerateConfigFile(hConf, logger))
	v4, err := ioutil.ReadFile(hConf.Filename)
	require.NoError(t, err)

	require.Equal(t, v1, v2)
	require.Equal(t, v3, v4)
}
