package boot

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"strings"

	"github.com/skycoin/dmsg/cipher"
)

// Offset and size of boot parameters.
const (
	offset = int64(0xe0) // offset to where boot params are located.
	size   = 216         // size of boot param data.
	sep    = 0x1f        // unit separator to separate values of boot params.
)

// Errors.
var (
	ErrCannotReadParams = errors.New("failed to read params from bootloader")
	ErrParamsTooLarge   = errors.New("boot params for image is too large - max size is 216 bytes")
	ErrInvalidMode      = errors.New("invalid mode")
)

// ENV names.
const (
	ModeENV          = "MD"
	LocalIPENV       = "IP"
	GatewayIPENV     = "GW"
	LocalPKENV       = "PK"
	LocalSKENV       = "SK"
	HypervisorPKsENV = "HVS"
	SocksPassEnv     = "SS"
)

// Modes.
const (
	HypervisorMode = Mode(0x00)
	VisorMode      = Mode(0x01)
)

// Mode is the operating mode of the node.
// Currently, this can either be HYPERVISOR or VISOR.
type Mode byte

// String implements io.Stringer
func (m Mode) String() string {
	text, err := m.MarshalText()
	if err != nil {
		return fmt.Sprintf("<%v>", err)
	}
	return string(text)
}

// MarshalText implements encoding.TextMarshaller.
func (m *Mode) MarshalText() (text []byte, err error) {
	switch *m {
	case HypervisorMode:
		return []byte("HYPERVISOR"), nil
	case VisorMode:
		return []byte("VISOR"), nil
	default:
		return nil, ErrInvalidMode
	}
}

// UnmarshalText implements encoding.TextUnmarshaler
func (m *Mode) UnmarshalText(text []byte) (err error) {
	switch string(text) {
	case "HYPERVISOR":
		*m = HypervisorMode
	case "VISOR":
		*m = VisorMode
	default:
		err = ErrInvalidMode
	}
	return
}

// Params are the boot parameters for a given node.
type Params struct {
	Mode      Mode          `json:"mode"`
	LocalIP   net.IP        `json:"local_ip"`
	GatewayIP net.IP        `json:"gateway_ip"`
	LocalPK   cipher.PubKey `json:"local_pk"` // Not actually encoded to bps.
	LocalSK   cipher.SecKey `json:"local_sk"`

	// only valid if mode == "0x00" (hypervisor)
	HypervisorPKs    cipher.PubKeys `json:"hypervisor_pks,omitempty"`
	SkysocksPasscode string         `json:"skysocks_passcode,omitempty"`
}

// MakeHypervisorParams is a convenience function for creating boot parameters for a hypervisor.
func MakeHypervisorParams(gwIP net.IP, sk cipher.SecKey) (Params, error) {
	pk, err := sk.PubKey()
	if err != nil {
		return Params{}, err
	}
	hvIP, err := NextIP(gwIP)
	if err != nil {
		return Params{}, err
	}
	params := Params{
		Mode:      HypervisorMode,
		LocalIP:   hvIP,
		GatewayIP: gwIP,
		LocalPK:   pk,
		LocalSK:   sk,
	}
	_, err = params.Encode()
	return params, err
}

// MakeVisorParams is a convenience function for creating boot parameters for a visor.
func MakeVisorParams(prevIP net.IP, gwIP net.IP, sk cipher.SecKey, hvPKs []cipher.PubKey, socksPC string) (Params, error) {
	pk, err := sk.PubKey()
	if err != nil {
		return Params{}, err
	}
	vIP, err := NextIP(prevIP)
	if err != nil {
		return Params{}, err
	}
	params := Params{
		Mode:             VisorMode,
		LocalIP:          vIP,
		GatewayIP:        gwIP,
		LocalPK:          pk,
		LocalSK:          sk,
		HypervisorPKs:    hvPKs,
		SkysocksPasscode: socksPC,
	}
	_, err = params.Encode()
	return params, err
}

// MakeParams is a convenience function for creating a slice of boot parameters.
func MakeParams(mode Mode, lIP, gwIP, lSK string, hvPKs ...string) (Params, error) {
	var bp Params
	switch mode {
	case HypervisorMode:
		if hvPKs != nil {
			return bp, fmt.Errorf("mode '%s' should not contain 'hypervisor_pks'", mode)
		}
	case VisorMode:
		// Nothing extra to check.
	default:
		return bp, fmt.Errorf("mode is invalid, supported options: %v",
			[]string{HypervisorMode.String(), VisorMode.String()})
	}
	if bp.LocalIP = net.ParseIP(lIP); lIP != "" && bp.LocalIP == nil {
		return bp, &net.ParseError{Type: "Local IP Address", Text: lIP}
	}
	if bp.GatewayIP = net.ParseIP(gwIP); gwIP != "" && bp.GatewayIP == nil {
		return bp, &net.ParseError{Type: "Gateway IP Address", Text: gwIP}
	}
	if err := bp.LocalSK.UnmarshalText([]byte(lSK)); lSK != "" && err != nil {
		return bp, fmt.Errorf("failed to read Local Secret Key: %v", err)
	}
	if bp.HypervisorPKs = make(cipher.PubKeys, 0); len(hvPKs) > 0 {
		if err := bp.HypervisorPKs.Set(strings.Join(hvPKs, ",")); err != nil {
			return bp, fmt.Errorf("failed to read Hypervisor Public Keys: %v", err)
		}
	}
	return bp, nil
}

// PrintEnv prints env to provided writer with format: <key>=<value>\n
func PrintEnv(w io.Writer, key, val string) error {
	_, err := fmt.Fprintf(w, "%s=%s\n", key, val)
	return err
}

// PrintEnvs generates a set of environment variables from the boot parameters.
// Each environment variable is wrote on a different line.
func (bp Params) PrintEnvs(w io.Writer) error {
	if err := PrintEnv(w, ModeENV, bp.Mode.String()); err != nil {
		return err
	}
	if len(bp.LocalIP) > 0 {
		if err := PrintEnv(w, LocalIPENV, bp.LocalIP.String()); err != nil {
			return err
		}
	}
	if len(bp.GatewayIP) > 0 {
		if err := PrintEnv(w, GatewayIPENV, bp.GatewayIP.String()); err != nil {
			return err
		}
	}
	if !bp.LocalSK.Null() {
		pk, err := bp.LocalSK.PubKey()
		if err != nil {
			return err
		}
		if err := PrintEnv(w, LocalPKENV, pk.String()); err != nil {
			return err
		}
		// TODO(evanlinjin): We may need to re-enable this in the future.
		//if err := PrintEnv(w, LocalSKENV, bp.LocalSK.String()); err != nil {
		//	return err
		//}
	}
	if len(bp.HypervisorPKs) > 0 {
		list := "("
		for _, pk := range bp.HypervisorPKs {
			list += "'" + pk.String() + "' "
		}
		list = list[:len(list)-1] + ")"
		if err := PrintEnv(w, HypervisorPKsENV, list); err != nil {
			return err
		}
	}
	if len(bp.SkysocksPasscode) > 0 {
		if err := PrintEnv(w, SocksPassEnv, bp.SkysocksPasscode); err != nil {
			return err
		}
	}
	return nil
}

// Encode encodes the boot parameters in a concise format to be wrote to the MBR.
func (bp Params) Encode() ([]byte, error) {
	keys := bp.LocalSK[:]
	for _, hvPK := range bp.HypervisorPKs {
		keys = append(keys, hvPK[:]...)
	}
	raw := bytes.Join([][]byte{{byte(bp.Mode)}, bp.LocalIP, bp.GatewayIP, []byte(bp.SkysocksPasscode), keys}, []byte{sep})
	if len(raw) > size {
		return nil, ErrParamsTooLarge
	}
	// Ensure we always have len of 'size'.
	out := make([]byte, size)
	copy(out, raw)
	return out, nil
}

// Decode decodes the boot parameters from the given raw bytes.
func (bp *Params) Decode(raw []byte) error {
	split := bytes.SplitN(raw, []byte{sep}, 5)
	if len(split) != 5 {
		return ErrCannotReadParams
	}

	bp.Mode, bp.LocalIP, bp.GatewayIP, bp.SkysocksPasscode =
		Mode(split[0][0]), split[1], split[2], string(split[3])

	keys := split[4]
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

// WriteParams writes boot parameters to a given filename at the expected MBR
// position.
func WriteParams(filename string, params Params) (err error) {
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
	return WriteRawToFile(f, rawParams)
}

// ReadParams reads boot parameters from a given file at the expected MBR
// position.
func ReadParams(filename string) (params Params, err error) {
	var f *os.File
	if f, err = os.Open(filename); err != nil { //nolint:gosec
		return params, err
	}
	defer func() {
		if closeErr := f.Close(); closeErr != nil && err == nil {
			err = closeErr
		}
	}()
	var raw []byte
	if raw, err = ReadRawFromFile(f); err != nil {
		return params, err
	}
	err = params.Decode(raw)
	return params, err
}

// WriteRawToFile writes raw bytes to a file at the expected MBR offset.
func WriteRawToFile(f *os.File, raw []byte) (err error) {
	_, err = f.WriteAt(raw, offset)
	return err
}

// ReadRawFromFile reads raw bytes from a file at the expected MBR offset.
func ReadRawFromFile(f *os.File) (raw []byte, err error) {
	raw = make([]byte, size)
	if _, err = f.ReadAt(raw, offset); err != nil {
		return raw, err
	}
	if bytes.Equal(raw, make([]byte, size)) {
		return raw, ErrCannotReadParams
	}
	return raw, err
}
