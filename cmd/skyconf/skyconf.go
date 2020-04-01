package main

import (
	"flag"
	"log"
	"os"

	"github.com/SkycoinProject/skybian/pkg/boot"
)

var filename string

func init() {
	const filenameDefault = "/dev/mmcblk0"
	flag.StringVar(&filename, "if", filenameDefault, "input file to read from")
}

func main() {
	flag.Parse()
	logger := log.New(os.Stderr, "", log.LstdFlags)

	params, err := boot.ReadParams(filename)
	if err != nil {
		logger.Println("failed to read params:", err)
		os.Exit(1)
	}
	if err := params.EnsureConfigFile(); err != nil {
		logger.Println("failed to ensure config file:", err)
		os.Exit(1)
	}
	if err := params.PrintEnvs(os.Stdout); err != nil {
		logger.Println("failed to print params:", err)
		os.Exit(1)
	}
	os.Exit(0)
}
