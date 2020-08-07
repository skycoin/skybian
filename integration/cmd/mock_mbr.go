package main

import (
	"errors"
	"flag"
	"net"

	"github.com/skycoin/dmsg/cipher"

	"github.com/skycoin/skybian/pkg/boot"
)

var (
	outFile string
	mode    int
)

func init() {
	flag.StringVar(&outFile, "of", "", "output file")
	flag.IntVar(&mode, "m", 0, "mode")
}

func main() {
	flag.Parse()

	_, sk := cipher.GenerateKeyPair()
	gwIP := net.ParseIP(boot.DefaultGatewayIP)

	var (
		bp  boot.Params
		err error
	)

	switch mode {
	case 0:
		// Hypervisor
		bp, err = boot.MakeHypervisorParams(gwIP, sk)
	case 1:
		// Visor.
		bp, err = boot.MakeVisorParams(gwIP, gwIP, sk, makeHvPKs(), "123456")
	default:
		err = errors.New("invalid mode")
	}
	if err != nil {
		panic(err)
	}

	// Don't set up networking in tests.
	bp.LocalIP = nil
	bp.GatewayIP = nil

	if err := boot.WriteParams(outFile, bp); err != nil {
		panic(err)
	}
}

func makeHvPKs() []cipher.PubKey {
	pk1, _ := cipher.GenerateKeyPair()
	pk2, _ := cipher.GenerateKeyPair()
	return []cipher.PubKey{pk1, pk2}
}
