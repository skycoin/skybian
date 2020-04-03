package prepare

import (
	"io/ioutil"
	"net"
	"os"
	"path/filepath"
	"testing"

	"github.com/SkycoinProject/dmsg/cipher"
	"github.com/stretchr/testify/require"

	"github.com/SkycoinProject/skybian/pkg/boot"
)

func TestPrepare(t *testing.T) {
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
	visorParams := boot.Params{
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
	require.NoError(t, Prepare(conf, visorParams))
	require.Error(t, Prepare(conf, visorParams))
	require.NoError(t, Prepare(conf, hvParams))
	require.Error(t, Prepare(conf, hvParams))
}
