package boot

import (
	"encoding/hex"
	"fmt"
	"io/ioutil"
	"net"
	"os"
	"testing"

	"github.com/SkycoinProject/dmsg/cipher"
	"github.com/stretchr/testify/require"
)

// mocks data within a master boot record.
var mockMBR = []byte{
	0xfa, 0xb8, 0x00, 0x10, 0x8e, 0xd0, 0xbc, 0x00, 0xb0, 0xb8, 0x00, 0x00, 0x8e, 0xd8, 0x8e, 0xc0,
	0xfb, 0xbe, 0x00, 0x7c, 0xbf, 0x00, 0x06, 0xb9, 0x00, 0x02, 0xf3, 0xa4, 0xea, 0x21, 0x06, 0x00,
	0x00, 0xbe, 0xbe, 0x07, 0x38, 0x04, 0x75, 0x0b, 0x83, 0xc6, 0x10, 0x81, 0xfe, 0xfe, 0x07, 0x75,
	0xf3, 0xeb, 0x16, 0xb4, 0x02, 0xb0, 0x01, 0xbb, 0x00, 0x7c, 0xb2, 0x80, 0x8a, 0x74, 0x01, 0x8b,
	0x4c, 0x02, 0xcd, 0x13, 0xea, 0x00, 0x7c, 0x00, 0x00, 0xeb, 0xfe, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xe4, 0x25, 0x6d, 0xe1, 0x00, 0x00, 0x00, 0x00,
	0x01, 0x40, 0x83, 0x03, 0xe0, 0xff, 0x00, 0x20, 0x00, 0x00, 0x00, 0x80, 0x29, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x55, 0xaa,
}

// genMockMBR generates the 'mockMBR'.
func genMockMBR(filename string) {
	inF, err := os.Open(filename)
	if err != nil {
		panic(err)
	}

	bs := make([]byte, 512)
	if _, err = inF.ReadAt(bs, 0); err != nil {
		panic(err)
	}

	s := "var mockMBR = []byte{"
	for i, b := range bs {
		if i%16 == 0 {
			s += "\n    "
		}
		s += "0x" + hex.EncodeToString([]byte{b}) + ", "
	}
	s += "}"
	fmt.Println(s)
}

func prepareMockImg(t *testing.T) (filename string) {
	f, err := ioutil.TempFile(os.TempDir(), "*.img")
	require.NoError(t, err)
	filename = f.Name()

	n, err := f.Write(mockMBR)
	require.NoError(t, err)
	require.Equal(t, len(mockMBR), n)

	require.NoError(t, f.Close())
	return filename
}

func generatePKs(n int) cipher.PubKeys {
	out := make(cipher.PubKeys, n)
	for i := range out {
		out[i], _ = cipher.GenerateKeyPair()
	}
	return out
}

func TestBootParams(t *testing.T) {
	imgName := prepareMockImg(t)
	defer func() { require.NoError(t, os.Remove(imgName)) }()

	_, err := ReadParams(imgName)
	require.EqualError(t, err, ErrCannotReadParams.Error())

	pk, sk := cipher.GenerateKeyPair()
	fmt.Println("pk =", pk) // pk = 027c823e9e183f3a89c5c200705f2017c0df253a66bdfae5aa0755d191713b7520
	fmt.Println("sk =", sk) // sk = 34992ada3a6daa4fbb5ad8b5b958d993ad4e5ed0f51b5ba822c8370212030826

	params := Params{
		Mode:          VisorMode,
		LocalIP:       net.ParseIP("192.168.0.2"),
		GatewayIP:     net.ParseIP("192.168.0.1"),
		LocalSK:       sk,
		HypervisorPKs: generatePKs(4),
		SkysocksPasscode: "testcode",
	}

	raw, err := params.Encode()
	require.NoError(t, err)
	require.Len(t, raw, size)

	require.NoError(t, WriteParams(imgName, params))

	readParams, err := ReadParams(imgName)
	require.NoError(t, err)
	require.Equal(t, params, readParams)
}
