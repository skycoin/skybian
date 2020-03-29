package main

import (
	"flag"
	"log"
	"os"

	"github.com/SkycoinProject/skybian/pkg/bootparams"
)

var filename string

func init() {
	const filenameDefault = "/dev/mmcblk0"
	flag.StringVar(&filename, "if", filenameDefault, "input file to read from")
}

var l = log.New(os.Stderr, "", log.LstdFlags)

func main() {
	flag.Parse()

	params, err := bootparams.Read(filename)
	if err != nil {
		l.Println("failed to read params:", err)
		os.Exit(1)
	}
	if err := params.PrintEnvs(os.Stdout); err != nil {
		l.Println("failed to print params:", err)
		os.Exit(1)
	}
	os.Exit(0)
}
