package boot

import (
	"errors"
	"net"
)

var (
	ErrOnlyIPv4 = errors.New("only IPv4 addresses are supported")
)

const DefaultGatewayIP = "192.168.0.1"

func NextIP(prevIP net.IP) (net.IP, error) {

	ip := make(net.IP, len(prevIP))
	copy(ip, prevIP)

	if ip = ip.To4(); ip == nil {
		return nil, ErrOnlyIPv4
	}
	for {
		if ip[3]++; ip[3] == 0 || ip[3] == 255 {
			continue
		}
		return ip, nil
	}
}
