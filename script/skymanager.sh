#!/bin/bash
#script runs on first boot via skymanager.service
#determines visor or hypervisor mode and enable the correct service
#generate the config for static IP address on the hypervisor
#or query the rpc of the hypervisor at the designated .2 static ip for its public key
#192.168.xxx.1	expected generally
_gateway="$(ip route show | grep -i 'default via'| awk '{print $3 }')"
#192.168.xxx.2 default value
_ip=${_gateway%.*}.2
#exit if no gateway
[[ ${_gateway} == "" ]] && echo "gateway ip unknown" &&  exit 1
#need to try to make a connection for `ip neigh` to work
skywire-cli visor pk --rpc ${_ip}:3435 &> /dev/null
#Set hostname to hypervisor and..
[[ $(ip neigh show | grep ${_ip} | grep -v "FAILED" | grep -v "INCOMPLETE") == "" ]] && echo "hypervisor" | tee /etc/hostname && hostname hypervisor
# Set static ip if the .2 ip address is available
if [[ $(hostname) == "hypervisor" ]]; then
	echo "[Match]
Name=eth*

[Network]
Address=${_ip}
Gateway=${_gateway}
DNS=${_gateway}" | tee /etc/systemd/network/eth.network
	#refresh the networking to use the static configuration
	systemctl restart systemd-networkd
	#disable this script's service
	systemctl disable skymanager 2> /dev/null
	#configure skywire
	skywire-autoconfig
	# start skywire & enable the service
	systemctl enable --now skywire 2> /dev/null
fi
#Visor configuration
if [[ $(hostname) != "hypervisor" ]]; then
	#query remote node for pk
	_pubkey=$(skywire-cli visor pk --rpc ${_ip}:3435)
	#rough errorcheck
	if [[ "${_pubkey}" != *"FATAL"* ]] ; then
		#disable this script's service
		systemctl disable skymanager 2> /dev/null
		#configure skywire with remote hypervisor
 		skywire-autoconfig ${_pubkey}
		#start the visor mode
		systemctl enable --now skywire-visor 2> /dev/null
		#systemctl reboot
	fi
fi
#the service will not be disabled if the script completes without generating the configuration
