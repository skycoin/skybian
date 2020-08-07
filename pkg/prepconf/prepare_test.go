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

	conf := Config{
		VisorConf:      filepath.Join(dir, "visor.json"),
		HypervisorConf: filepath.Join(dir, "hypervisor.json"),
		TLSKey:         filepath.Join(dir, "key.pem"),
		TLSCert:        filepath.Join(dir, "cert.pem"),
	}
	pk, sk := cipher.GenerateKeyPair()
	vParams := boot.Params{
		Mode:             boot.VisorMode,
		LocalIP:          net.ParseIP(boot.DefaultGatewayIP),
		GatewayIP:        net.ParseIP(boot.DefaultGatewayIP),
		LocalPK:          pk,
		LocalSK:          sk,
		HypervisorPKs:    []cipher.PubKey{pk},
		SkysocksPasscode: "test",
	}
	hvParams := boot.Params{
		Mode:             boot.HypervisorMode,
		LocalIP:          net.ParseIP(boot.DefaultGatewayIP),
		GatewayIP:        net.ParseIP(boot.DefaultGatewayIP),
		LocalPK:          pk,
		LocalSK:          sk,
		HypervisorPKs:    []cipher.PubKey{pk},
		SkysocksPasscode: "test",
	}
	require.NoError(t, Prepare(logger, conf, vParams))
	v1, err := ioutil.ReadFile(conf.VisorConf)
	require.NoError(t, err)

	vParams.LocalPK, vParams.LocalSK = cipher.GenerateKeyPair()
	require.NoError(t, Prepare(logger, conf, vParams))
	v2, err := ioutil.ReadFile(conf.VisorConf)
	require.NoError(t, err)

	require.NoError(t, Prepare(logger, conf, hvParams))
	v3, err := ioutil.ReadFile(conf.HypervisorConf)
	require.NoError(t, err)

	hvParams.LocalPK, hvParams.LocalSK = cipher.GenerateKeyPair()
	require.NoError(t, Prepare(logger, conf, hvParams))
	v4, err := ioutil.ReadFile(conf.HypervisorConf)
	require.NoError(t, err)

	require.Equal(t, v1, v2)
	require.Equal(t, v3, v4)
}
