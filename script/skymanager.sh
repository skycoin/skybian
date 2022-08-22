#!/bin/bash
#script runs on first boot via skymanager.service
#expects CHROOTCONFIG=1 skybian-chrootconfig was run
#determines static ip configuration and adds the service configuration for autopeering
#check for root
if [[ $EUID -ne 0 ]]; then
	echo "root permissions required"
	exit 1
fi

#remove any previous config and exit
if [[ -f /etc/systemd/network/10-eth.network ]] ; then
	echo "removing static ip configuration"
	rm  /etc/systemd/network/10-eth.network
	systemctl restart systemd-networkd networking NetworkManager
	systemctl disable --now srvpk 2> /dev/null
	[[ -f /etc/systemd/system/skywire.conf.d/skywire.conf ]] && rm /etc/systemd/system/skywire.conf.d/skywire.conf
	 exit 0
 fi
 [[ -f /etc/systemd/system/skywire.conf.d/skywire.conf ]] && 	echo "removing /etc/systemd/system/skywire.conf.d/skywire.conf" && rm /etc/systemd/system/skywire.conf.d/skywire.conf && exit 0

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
if [[ $(ip neigh show | grep ${_ip} | grep -v "FAILED" | grep -v "INCOMPLETE") == "" ]]; then
# Set static ip if the .2 ip address is available
echo "[Match]
Name=eth*

[Network]
Address=${_ip}/24
Gateway=${_gateway}
DNS=${_gateway}" | tee /etc/systemd/network/10-eth.network
#refresh the networking to use the static configuration
systemctl restart systemd-networkd
#start the http endpoint for the hypervisor public key
systemctl enable --now srvpk 2> /dev/null
else
NOHV=1
##query remote node for pk
#_pubkey=$(curl ${_ip}:7998)
#rough errorcheck
#if [[ ("${_pubkey}" == *"FATAL"*) || ("${_pubkey}" == *"Failed"*) ]] ; then
#_pubkey="0"
#fi

fi

#configure skywire
#skywire-autoconfig ${_pubkey}

skywire-autoconfig $NOHV

if [[ -f /opt/skywire/skywire.json ]] ; then
#create the service conf
[[ ! -d /etc/systemd/system/skywire.service.d/ ]] && mkdir -p /etc/systemd/system/skywire.service.d
echo "[Service]
Environment=AUTOPEER=1
Environment=SKYBIAN=true" | sudo tee /etc/systemd/system/skywire.service.d/10-skywire_10.conf
systemctl daemon-reload
#disable this script's service
systemctl disable skymanager 2> /dev/null
#start skywire & enable the service
systemctl enable --now skywire 2> /dev/null
systemctl restart skywire 2> /dev/null
#the service will be disabled by the user upon satisfactory configuratiomn
fi
