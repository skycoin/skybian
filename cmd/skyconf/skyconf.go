package main

import (
	"flag"
	"io/ioutil"
	"log"
	"os"

	"github.com/SkycoinProject/skybian/pkg/boot"
	"github.com/SkycoinProject/skybian/pkg/prepconf"
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

const (
	paramSuccess = "SUCCESS"
	paramLogFile = "LOGFILE"
)

func main() {
	flag.Parse()

	f, err := ioutil.TempFile(os.TempDir(), "skyconf-log-")
	if err != nil {
		log.New(os.Stderr, "", log.LstdFlags).
			Fatalf("failed to create temporary log file: %v", err)
	}
	defer func() {
		if err := f.Close(); err != nil {
			log.New(os.Stderr, "", log.LstdFlags).
				Fatalf("failed to close temporary log file: %v", err)
		}
	}()
	fileLog := log.New(f, "", log.LstdFlags)
	fileLog.Printf("Started!")

	params, err := boot.ReadParams(filename)
	if err != nil {
		fileLog.Fatalf("failed to read params: %v", err)
	}
	conf := prepconf.Config{
		VisorConf:      vName,
		HypervisorConf: hvName,
		TLSKey:         keyFile,
		TLSCert:        certFile,
	}
	if err := prepconf.Prepare(conf, params); err != nil {
		fileLog.Fatalf("failed to ensure config file: %v", err)
	}
	if err := params.PrintEnvs(os.Stdout); err != nil {
		fileLog.Fatalf("failed to print params: %v", err)
	}
	if err := boot.PrintEnv(os.Stdout, paramSuccess, "1"); err != nil {
		fileLog.Fatalf("failed to print %s param: %v", paramSuccess, err)
	}
	if err := boot.PrintEnv(os.Stdout, paramLogFile, f.Name()); err != nil {
		fileLog.Fatalf("failed to print %s param: %v", paramLogFile, err)
	}
	fileLog.Printf("Done!")
}
