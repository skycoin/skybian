package main

import (
	"crypto/rand"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"time"

	"github.com/skycoin/skybian/pkg/boot"
	"github.com/skycoin/skybian/pkg/prepconf"
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

	logger, logF := makeLogger()
	if logF != nil {
		if err := boot.PrintEnv(os.Stdout, paramLogFile, logF.Name()); err != nil {
			logger.Fatalf("failed to print %s param: %v", paramLogFile, err)
		}
		defer func() {
			if err := logF.Close(); err != nil {
				logger.Printf("failed to close log file: %v", err)
			}
		}()
	}

	logger.Printf("Started!")

	params, err := boot.ReadParams(filename)
	if err != nil {
		logger.Fatalf("failed to read params: %v", err)
	}
	conf := prepconf.Config{
		VisorConf:      vName,
		HypervisorConf: hvName,
		TLSKey:         keyFile,
		TLSCert:        certFile,
	}
	if err := prepconf.Prepare(logger, conf, params); err != nil {
		logger.Fatalf("failed to ensure config file: %v", err)
	}
	if err := params.PrintEnvs(os.Stdout); err != nil {
		logger.Fatalf("failed to print boot params: %v", err)
	}
	if err := boot.PrintEnv(os.Stdout, paramSuccess, "1"); err != nil {
		logger.Fatalf("failed to print %s env: %v", paramSuccess, err)
	}

	logger.Printf("Done!")
}

func tempFile() (*os.File, error) {
	b := make([]byte, 5)
	if _, err := rand.Read(b); err != nil {
		return nil, err
	}
	name := filepath.Join(os.TempDir(), fmt.Sprintf("skyconf-%d-%d.log", os.Getpid(), time.Now().Unix()))
	return os.OpenFile(name, os.O_WRONLY|os.O_CREATE, 0644) //nolint:gosec
}

func makeLogger() (*log.Logger, *os.File) {
	logger := log.New(os.Stderr, "[skyconf] ", log.LstdFlags)
	f, err := tempFile()
	if err != nil {
		logger.Printf("failed to create temp log file: %v", err)
		return logger, nil
	}
	logger = log.New(io.MultiWriter(os.Stderr, f), "[skyconf] ", log.LstdFlags)
	return logger, f
}
