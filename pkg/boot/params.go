package boot

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

// Errors.
var (
	ErrCannotReadParams = errors.New("failed to read params from bootloader")
	ErrParamsTooLarge   = errors.New("params too large")
	ErrInvalidMode      = errors.New("invalid mode")
)

// URLs.
const (
	dmsgDiscURL = "http://dmsg.discovery.skywire.skycoin.com"
	tpDiscURL   = "http://transport.discovery.skywire.skycoin.com"
	rfURL       = "http://routefinder.skywire.skycoin.com"
	uptimeURL   = "uptime-tracker.skywire.skycoin.com"
)

// Keys (Hex String).
const (
	setupPKHex = "026c5a07de617c5c488195b76e8671bf9e7ee654d0633933e202af9e111ffa358d"
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

// Defaults.
const (
	ipPattern           = "192.168.0.%d"
	DefaultGatewayIP    = "192.168.0.1"
	DefaultHypervisorIP = "192.168.0.2"
)

// Modes.
const (
	HypervisorMode = Mode(0x00)
	VisorMode      = Mode(0x01)
)

type Mode byte

func (m Mode) String() string {
	text, err := m.MarshalText()
	if err != nil {
		return fmt.Sprintf("<%v>", err)
	}
	return string(text)
}

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

func MakeHypervisorParams(sk cipher.SecKey) Params {
	pk, _ := sk.PubKey()
	return Params{
		Mode:      HypervisorMode,
		LocalIP:   net.ParseIP(DefaultHypervisorIP),
		GatewayIP: net.ParseIP(DefaultGatewayIP),
		LocalPK:   pk,
		LocalSK:   sk,
	}
}

func MakeVisorParams(i int, gwIP net.IP, sk cipher.SecKey, hvPKs []cipher.PubKey, socksPC string) Params {
	pk, _ := sk.PubKey()
	return Params{
		Mode:             VisorMode,
		LocalIP:          net.ParseIP(fmt.Sprintf(ipPattern, i+3)),
		GatewayIP:        gwIP,
		LocalPK:          pk,
		LocalSK:          sk,
		HypervisorPKs:    hvPKs,
		SkysocksPasscode: socksPC,
	}
}

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

func (bp Params) PrintEnvs(w io.Writer) error {
	printEnv := func(key, val string) error {
		_, err := fmt.Fprintf(w, "%s=%s\n", key, val)
		return err
	}
	if err := printEnv(ModeENV, bp.Mode.String()); err != nil {
		return err
	}
	if len(bp.LocalIP) > 0 {
		if err := printEnv(LocalIPENV, bp.LocalIP.String()); err != nil {
			return err
		}
	}
	if len(bp.GatewayIP) > 0 {
		if err := printEnv(GatewayIPENV, bp.GatewayIP.String()); err != nil {
			return err
		}
	}
	if !bp.LocalSK.Null() {
		pk, err := bp.LocalSK.PubKey()
		if err != nil {
			return err
		}
		if err := printEnv(LocalPKENV, pk.String()); err != nil {
			return err
		}
		if err := printEnv(LocalSKENV, bp.LocalSK.String()); err != nil {
			return err
		}
	}
	if len(bp.HypervisorPKs) > 0 {
		list := "("
		for _, pk := range bp.HypervisorPKs {
			list += "'" + pk.String() + "' "
		}
		list = list[:len(list)-1] + ")"
		if err := printEnv(HypervisorPKsENV, list); err != nil {
			return err
		}
	}
	if len(bp.SkysocksPasscode) > 0 {
		if err := printEnv(SocksPassEnv, bp.SkysocksPasscode); err != nil {
			return err
		}
	}
	return nil
}

func (bp Params) genKeyPair() (pk cipher.PubKey, sk cipher.SecKey, err error) {
	if sk = bp.LocalSK; sk.Null() {
		pk, sk = cipher.GenerateKeyPair()
	} else {
		pk, err = sk.PubKey()
	}
	return
}

func (bp Params) Encode() ([]byte, error) {
	keys := bp.LocalSK[:]
	for _, hvPK := range bp.HypervisorPKs {
		keys = append(keys, hvPK[:]...)
	}
	raw := bytes.Join([][]byte{bp.LocalIP, bp.GatewayIP, []byte(bp.SkysocksPasscode), keys}, []byte{sep})
	if len(raw) > size {
		return nil, ErrParamsTooLarge
	}
	// Ensure we always have len of 'size'.
	out := make([]byte, size)
	copy(out, raw)
	return out, nil
}

func (bp *Params) Decode(raw []byte) error {
	split := bytes.SplitN(raw, []byte{sep}, 4)
	if len(split) != 4 {
		return ErrCannotReadParams
	}

	bp.LocalIP, bp.GatewayIP, bp.SkysocksPasscode = split[0], split[1], string(split[2])

	keys := split[3]
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

func ReadParams(filename string) (params Params, err error) {
	var f *os.File
	if f, err = os.Open(filename); err != nil {
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

func WriteRawToFile(f *os.File, raw []byte) (err error) {
	_, err = f.WriteAt(raw, offset)
	return err
}

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
