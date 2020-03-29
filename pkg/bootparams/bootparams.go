package bootparams

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"strings"

	"github.com/SkycoinProject/dmsg/cipher"
)

// Offset and size of boot parameters.
const (
	offset = int64(0xe0) // offset to where boot params are located.
	size   = 216         // size of boot param data.
	sep    = 0x1f        // unit separator to separate values of boot params.
)

var (
	ErrCannotReadParams = errors.New("failed to read params from bootloader")
	ErrParamsTooLarge   = errors.New("params too large")
)

type BootParams struct {
	LocalIP       net.IP         `json:"local_ip"`
	GatewayIP     net.IP         `json:"gateway_ip"`
	LocalSK       cipher.SecKey  `json:"local_sk"`
	HypervisorPKs cipher.PubKeys `json:"hypervisor_pks"`
}

func MakeBootParams(localIP, gatewayIP, localSK string, hypervisorPKs []string) (BootParams, error) {
	var bp BootParams

	if bp.LocalIP = net.ParseIP(localIP); localIP != "" && bp.LocalIP == nil {
		return bp, &net.ParseError{Type: "Local IP Address", Text: localIP}
	}
	if bp.GatewayIP = net.ParseIP(gatewayIP); gatewayIP != "" && bp.GatewayIP == nil {
		return bp, &net.ParseError{Type: "Gateway IP Address", Text: gatewayIP}
	}
	if err := bp.LocalSK.UnmarshalText([]byte(localSK)); localSK != "" && err != nil {
		return bp, fmt.Errorf("failed to read Local Secret Key: %v", err)
	}
	if err := bp.HypervisorPKs.Set(strings.Join(hypervisorPKs, ",")); err != nil {
		return bp, fmt.Errorf("failed to read Hypervisor Public Keys: %v", err)
	}
	return bp, nil
}

func (bp BootParams) PrintEnvs(w io.Writer) error {
	printEnv := func(key, val string) error {
		_, err := fmt.Fprintf(w, "%s=%s\n", key, val)
		return err
	}
	if len(bp.LocalIP) > 0 {
		if err := printEnv("IP", bp.LocalIP.String()); err != nil {
			return err
		}
	}
	if len(bp.GatewayIP) > 0 {
		if err := printEnv("GW", bp.GatewayIP.String()); err != nil {
			return err
		}
	}
	if !bp.LocalSK.Null() {
		if err := printEnv("SK", bp.LocalSK.String()); err != nil {
			return err
		}
	}
	if len(bp.HypervisorPKs) > 0 {
		list := "("
		for _, pk := range bp.HypervisorPKs {
			list += "'" + pk.String() + "' "
		}
		list = list[:len(list)-1] + ")"
		if err := printEnv("HVS", list); err != nil {
			return err
		}
	}
	return nil
}

func (bp BootParams) Encode() ([]byte, error) {
	keys := bp.LocalSK[:]
	for _, hvPK := range bp.HypervisorPKs {
		keys = append(keys, hvPK[:]...)
	}
	raw := bytes.Join([][]byte{bp.LocalIP, bp.GatewayIP, keys}, []byte{sep})
	if len(raw) > size {
		return nil, ErrParamsTooLarge
	}
	// Ensure we always have len of 'size'.
	out := make([]byte, size)
	copy(out, raw)
	return out, nil
}

func (bp *BootParams) Decode(raw []byte) error {
	split := bytes.SplitN(raw, []byte{sep}, 3)
	if len(split) != 3 {
		return ErrCannotReadParams
	}

	bp.LocalIP, bp.GatewayIP = split[0], split[1]

	keys := split[2]
	keys = keys[copy(bp.LocalSK[:], keys):]
	for {
		var pk cipher.PubKey
		if keys = keys[copy(pk[:], keys):]; pk.Null() {
			break
		}
		bp.HypervisorPKs = append(bp.HypervisorPKs, pk)
	}
	return nil
}

// Write
func Write(filename string, params BootParams) (err error) {
	var rawParams []byte
	if rawParams, err = params.Encode(); err != nil {
		return err
	}
	var f *os.File
	if f, err = os.OpenFile(filename, os.O_WRONLY, os.FileMode(0660)); err != nil {
		return err
	}
	defer func() {
		if closeErr := f.Close(); closeErr != nil && err == nil {
			err = closeErr
		}
	}()
	return WriteToFile(f, rawParams)
}

func WriteToFile(f *os.File, rawParams []byte) (err error) {
	_, err = f.WriteAt(rawParams, offset)
	return err
}

// Read
func Read(filename string) (params BootParams, err error) {
	var f *os.File
	if f, err = os.Open(filename); err != nil {
		return params, err
	}
	defer func() {
		if closeErr := f.Close(); closeErr != nil && err == nil {
			err = closeErr
		}
	}()
	return ReadFromFile(f)
}

func ReadFromFile(f *os.File) (params BootParams, err error) {
	raw := make([]byte, size)
	if _, err = f.ReadAt(raw, offset); err != nil {
		return params, err
	}
	if bytes.Equal(raw, make([]byte, size)) {
		return params, ErrCannotReadParams
	}
	err = params.Decode(raw)
	return params, err
}
