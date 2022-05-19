#!/bin/bash
#script runs on first boot via skymanager.service
#determines visor or hypervisor mode and enable the correct service
#generate the config for static IP address on the hypervisor
#192.168.xxx.1
_gateway="$(ip route show | grep -i 'default via'| awk '{print $3 }')"
#192.168.xxx.2
_ip=${_gateway%.*}.2
_fullip="${_ip}/24"
[[ ${_gateway} == "" ]] && echo "gateway ip unknown" &&  exit 1 #exit if no gateway
#Set hostname to hypervisor based on the existance of /dev/sda - detected drive used as switch, not written to
[[ $(lsblk) == *"sda"* ]] && echo "hypervisor" | tee /etc/hostname

if [[ $(hostname) == "hypervisor" ]]; then
	echo "[Match]
Name=eth*

[Network]
Address=${_ip}
Gateway=${_gateway}
DNS=${_gateway}" | tee /etc/systemd/network/eth.network
	systemctl disable skymanager 2> /dev/null
	skywire-autoconfig
	#systemctl enable skywire 2> /dev/null
	systemctl reboot
fi

if [[ $(hostname) != "hypervisor" ]]; then
	#set the ssh key which was generated during image modifications to access the hypervisor without a password
	echo "	Host ${_ip}
Hostname hypervisor
IdentityFile ~/.ssh/id_rsa
User root" | tee /root/.ssh/config
	# debug
	#check if 192.168.xxx.2 is occupied
	# [[ "$(ip neigh show 192.168.2.2)" == "" ]] && echo "no match"
	_pubkey=$(ssh -t root@${_ip} "skywire-cli visor pk" | head -n1)
	#query remote node for pk
	if [[ "${_pubkey}" != *"FATAL"* ]] ; then
 		skywire-autoconfig ${_pubkey}
		#systemctl enable skywire-visor 2> /dev/null
		systemctl disable skymanager 2> /dev/null
		systemctl reboot
	fi
fi
