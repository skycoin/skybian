package boot

import (
	"fmt"
	"io/ioutil"
	"net"
	"os"
	"testing"

	"github.com/skycoin/dmsg/cipher"
	"github.com/stretchr/testify/require"
)

func prepareMockImg(t *testing.T) (filename string) {
	// todo: consider using in-memory fs?
	f, err := ioutil.TempFile(os.TempDir(), "*.img")
	require.NoError(t, err)
	filename = f.Name()

	mockData := make([]byte, size+offset)
	n, err := f.Write(mockData)
	require.NoError(t, err)
	require.Equal(t, len(mockData), n)

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

func TestBootParamsWifi(t *testing.T) {
	imgName := prepareMockImg(t)
	defer func() { require.NoError(t, os.Remove(imgName)) }()

	_, err := ReadParams(imgName)
	require.EqualError(t, err, ErrCannotReadParams.Error())

	pk, sk := cipher.GenerateKeyPair()
	fmt.Println("pk =", pk)
	fmt.Println("sk =", sk)

	params := Params{
		Mode:             VisorMode,
		LocalIP:          net.ParseIP("192.168.0.2"),
		GatewayIP:        net.ParseIP("192.168.0.1"),
		LocalSK:          sk,
		HypervisorPKs:    generatePKs(4),
		SkysocksPasscode: "",
		WifiEndpointName: "testName",
		WifiEndpointPass: "pass",
	}

	raw, err := params.Encode()
	require.NoError(t, err)
	require.Len(t, raw, size)

	require.NoError(t, WriteParams(imgName, params))

	readParams, err := ReadParams(imgName)
	require.NoError(t, err)
	require.Equal(t, params, readParams)
}

func TestBootParamsNoWifi(t *testing.T) {
	imgName := prepareMockImg(t)
	defer func() { require.NoError(t, os.Remove(imgName)) }()

	_, err := ReadParams(imgName)
	require.EqualError(t, err, ErrCannotReadParams.Error())

	pk, sk := cipher.GenerateKeyPair()
	fmt.Println("pk =", pk)
	fmt.Println("sk =", sk)

	params := Params{
		Mode:             VisorMode,
		LocalIP:          net.ParseIP("192.168.0.2"),
		GatewayIP:        net.ParseIP("192.168.0.1"),
		LocalSK:          sk,
		HypervisorPKs:    generatePKs(4),
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
