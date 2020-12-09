package prepconf

import (
	"encoding/json"
	"io/ioutil"
	"log"
	"os"

	"github.com/skycoin/dmsg/cipher"
	"github.com/skycoin/skywire/pkg/app/launcher"
	"github.com/skycoin/skywire/pkg/restart"
	"github.com/skycoin/skywire/pkg/routing"
	"github.com/skycoin/skywire/pkg/skyenv"
	"github.com/skycoin/skywire/pkg/visor/visorconfig"

	"github.com/skycoin/skybian/pkg/boot"
)

// Config configures how hypervisor and visor images are to be generated.
type Config struct {
	BootParams boot.Params
	Filename   string
	TLSCert    string
	TLSKey     string
}

func GenerateConfigFile(conf Config, logger *log.Logger) error {
	name := conf.Filename
	if _, err := os.Stat(name); err == nil {
		conf, err := ioutil.ReadFile(name) //nolint:gosec
		if err == nil {
			logger.Printf("Contents of %q: %q", name, string(conf))
		}

		if len(conf) != 0 {
			logger.Printf("Config file %q already exists and is not empty", name)
			return nil
		}
	}
	// Create file.
	f, err := os.OpenFile(name, os.O_WRONLY|os.O_CREATE, 0644) //nolint:gosec
	if err != nil {
		return err
	}
	// Generate and write config to file.
	out, err := generateConfig(conf)
	if err != nil {
		return err
	}
	raw, err := json.MarshalIndent(out, "", "\t")
	if err != nil {
		return err
	}
	_, err = f.Write(raw)
	if err1 := f.Close(); err == nil {
		err = err1
	}
	return err
}

func genKeyPair(bp boot.Params) (pk cipher.PubKey, sk cipher.SecKey, err error) {
	if sk = bp.LocalSK; sk.Null() {
		pk, sk = cipher.GenerateKeyPair()
	} else {
		pk, err = sk.PubKey()
	}
	return
}

func generateConfig(conf Config) (*visorconfig.V1, error) {
	bp := conf.BootParams
	skysocksArgs := func() (args []string) {
		if bp.SkysocksPasscode != "" {
			args = []string{"-passcode", bp.SkysocksPasscode}
		}
		return args
	}

	_, sk, err := genKeyPair(bp)
	if err != nil {
		return nil, err
	}
	isHypervisor := bp.Mode == boot.HypervisorMode
	out, err := visorconfig.MakeDefaultConfig(nil, "", &sk, isHypervisor)
	if err != nil {
		return nil, err
	}
	if isHypervisor {
		out.Hypervisor.DBPath = "/var/skywire-hypervisor/users.db"
		out.Hypervisor.EnableAuth = true
		out.Hypervisor.Cookies.BlockKey = cipher.RandByte(32)
		out.Hypervisor.Cookies.HashKey = cipher.RandByte(64)
		out.Hypervisor.Cookies.FillDefaults()
		out.Hypervisor.DmsgDiscovery = skyenv.DefaultDmsgDiscAddr
		out.Hypervisor.DmsgPort = skyenv.DmsgHypervisorPort
		out.Hypervisor.HTTPAddr = ":8000"
		out.Hypervisor.EnableTLS = false // TODO(evanlinjin): TLS is disabled due to a bug in the skyminer Router.
		out.Hypervisor.TLSCertFile = conf.TLSCert
		out.Hypervisor.TLSKeyFile = conf.TLSKey
		err = GenCert(out.Hypervisor.TLSCertFile, out.Hypervisor.TLSKeyFile)
	}

	// TODO(evanlinjin): We need to handle STCP properly.
	//if out.STCP, err = visor.DefaultSTCPConfig(); err != nil {
	//	return nil, err
	//}
	out.Dmsgpty.AuthFile = "/var/skywire-visor/dsmgpty/whitelist.json"
	out.Dmsgpty.CLIAddr = "/run/skywire-visor/dmsgpty/cli.sock"
	out.Transport.LogStore.Type = "file"
	out.Transport.LogStore.Location = "/var/skywire-visor/transports"
	out.Hypervisors = bp.HypervisorPKs
	out.LogLevel = skyenv.DefaultLogLevel
	out.ShutdownTimeout = visorconfig.DefaultTimeout
	out.RestartCheckDelay = visorconfig.Duration(restart.DefaultCheckDelay)
	out.Launcher = &visorconfig.V1Launcher{
		Discovery: &visorconfig.V1AppDisc{
			ServiceDisc:    skyenv.DefaultServiceDiscAddr,
			UpdateInterval: visorconfig.Duration(skyenv.AppDiscUpdateInterval),
		},
		Apps: []launcher.AppConfig{
			{
				Name:      skyenv.SkychatName,
				AutoStart: true,
				Port:      routing.Port(skyenv.SkychatPort),
				Args:      []string{"-addr", skyenv.SkychatAddr},
			},
			{
				Name:      skyenv.SkysocksName,
				AutoStart: true,
				Port:      routing.Port(skyenv.SkysocksPort),
				Args:      skysocksArgs(),
			},
			{
				Name:      skyenv.SkysocksClientName,
				AutoStart: false,
				Port:      routing.Port(skyenv.SkysocksClientPort),
				Args:      []string{"-addr", skyenv.SkysocksClientAddr},
			},
			{
				Name:      "vpn-server",
				AutoStart: false,
				Port:      routing.Port(44),
			},
			{
				Name:      "vpn-client",
				AutoStart: false,
				Port:      routing.Port(43),
			},
		},
		ServerAddr: skyenv.DefaultAppSrvAddr,
		BinPath:    "/usr/bin/apps",
		LocalPath:  "/var/skywire-visor/apps",
	}
	return out, nil
}
