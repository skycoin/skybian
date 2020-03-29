package imager

import (
	"encoding/hex"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestBuilder_FinalizeImage(t *testing.T) {
	switch runtime.GOOS {
	case "linux", "darwin":
	default:
		t.SkipNow()
	}

	const (
		inF    = "/dev/sdb"
		outFdd = "/tmp/dd1234567890"
		dStart = 0 //49152
		dSize  = 512 //256
	)

	ddCmd := exec.Command(
		"/usr/bin/dd",
		"if="+inF,
		"of="+outFdd,
		"bs="+strconv.Itoa(dSize),
		"count=1",
		"skip="+strconv.Itoa(dStart))

	ddOut, err := ddCmd.CombinedOutput()
	fmt.Println(string(ddOut))
	require.NoError(t, err)

	in, err := os.Open(inF)
	require.NoError(t, err)

	inB := make([]byte, dSize)
	n, err := in.ReadAt(inB, dStart * dSize)
	require.NoError(t, err)
	require.Equal(t, dSize, n)

	outB, err := ioutil.ReadFile(outFdd)
	require.NoError(t, err)

	img, err := os.Open("/home/evanlinjin/git/skybian/output/parts/armbian/Armbian_20.02.1_Orangepiprime_stretch_current_5.4.20.img")
	require.NoError(t, err)

	imgB := make([]byte, dSize)
	n, err = img.ReadAt(imgB, dStart * dSize)
	require.NoError(t, err)
	require.Equal(t, dSize, n)


	fmt.Println(hex.EncodeToString(inB))
	fmt.Println(hex.EncodeToString(outB))
	fmt.Println(hex.EncodeToString(imgB))
	require.Equal(t, inB, outB)
	require.Equal(t, inB, imgB)
}

func TestBuilder_FinalizeImage2(t *testing.T) {
	bs := []byte{0xfa, 0xb8, 0x00}
	fmt.Println(bs)
}