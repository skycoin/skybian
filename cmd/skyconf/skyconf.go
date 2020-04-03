package main

import (
	"flag"
	"log"
	"os"

	"github.com/SkycoinProject/skybian/pkg/boot"
	"github.com/SkycoinProject/skybian/pkg/prepare"
)

var filename string

func init() {
	const filenameDefault = "/dev/mmcblk0"
	flag.StringVar(&filename, "if", filenameDefault, "input file to read from")
}

var hvName string

func init() {
	const hvNameDefault = "/etc/skywire-hypervisor.json"
	flag.StringVar(&hvName, "hvf", hvNameDefault, "hypervisor config output file")
}

var vName string

func init() {
	const vNameDefault = "/etc/skywire-visor.json"
	flag.StringVar(&vName, "vf", vNameDefault, "visor config output file")
}

var keyFile string

func init() {
	const keyFileDefault = "/etc/skywire-hypervisor/key.pem"
	flag.StringVar(&keyFile, "keyf", keyFileDefault, "hypervisor tls key file")
}

var certFile string

func init() {
	const certFileDefault = "/etc/skywire-hypervisor/cert.pem"
	flag.StringVar(&certFile, "certf", certFileDefault, "hypervisor tls cert file")
}

func main() {
	flag.Parse()
	logger := log.New(os.Stderr, "", log.LstdFlags)

	params, err := boot.ReadParams(filename)
	if err != nil {
		logger.Println("failed to read params:", err)
		os.Exit(1)
	}
	conf := prepare.Config{
		VisorConf:      vName,
		HypervisorConf: hvName,
		TLSKey:         keyFile,
		TLSCert:        certFile,
	}
	if err := prepare.Prepare(conf, params); err != nil {
		logger.Println("failed to ensure config file:", err)
		os.Exit(1)
	}
	if err := params.PrintEnvs(os.Stdout); err != nil {
		logger.Println("failed to print params:", err)
		os.Exit(1)
	}
	os.Exit(0)
}
