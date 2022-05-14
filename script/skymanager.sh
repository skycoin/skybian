#!/bin/bash
#script runs on first boot via skymanager.service
#determines visor or hypervisor mode and enable the correct service
#generate the config for static IP address on the hypervisor
#192.168.xxx.1
_gateway="$(ip route show | grep -i 'default via'| awk '{print $3 }')"
#192.168.xxx.2
_ip="$(ip route show | grep -i 'default via'| awk '{print $3 }' | /usr/bin/sed 's/\.[^.]*$//').2"
_fullip="${_ip}/24"
# debug
# [[ "$(ip neigh show 192.168.2.2)" == "" ]] && echo "no match"
#check if 192.168.xxx.2 is occupied
[[ ${_gateway} == "" ]] && echo "gateway ip unknown" &&  exit 1 #exit if no gateway
if [[ "$(ip neigh show ${_ip})" == "" ]] ; then
  #further check - the above was insufficient in practice
  #be sure this machine isn't already on the given IP
  if [[ "$(ip addr show | grep ${_fullip})" != *"${_fullip}"* ]] ; then
    #check to see if we can get a reply from the visor there when we ask it's public key
    if [[ "$(skywire-cli --rpc ${_ip}:3435 visor pk)" == *"FATAL"* ]] ; then
      echo "configuring hypervisor"

      #create static IP configuration - systemd-networkd - works on arch
      if [[ ! -f /etc/systemd/network/eth.network ]] ; then
echo "[Match]
Name=eth*

[Network]
Address=${_ip}
Gateway=${_gateway}
DNS=${_gateway}" | tee /etc/systemd/network/eth.network
      fi
#
      ##static ip configuration - uses networking.service - possibly deprecated
#      if [[ ! -f /etc/network/interfaces.d/eth0 ]] ; then
#        echo "auto eth0
#iface eth0 inet static
#        address ${_ip}
#        netmask 255.255.255.0
#        gateway ${_gateway}
#        dns-nameservers ${_gateway}" | tee  /etc/network/interfaces.d/eth0
        #set hostname
        echo "hypervisor" | tee /etc/hostname
      #remove any undesired configuration
      [[ -f /opt/skywire/skywire-visor.json ]] && rm /opt/skywire/skywire-visor.json && echo "removed a visor configuration"
      systemctl disable skymanager 2> /dev/null && echo "disabling skymanager.service"
      systemctl enable skywire-autoconfig 2> /dev/null && echo "enabling skywire-autoconfig.service"
      echo "REBOOT"
      reboot now
    fi
  fi
fi
  #Leave the IP setting as DHCP and run the skywire-visor-firstboot.service
  echo "configuring visor"
  systemctl enable skywire-autoconfig-remote 2> /dev/null && echo "enabling skywire-autoconfig-remote.service"
  systemctl disable skymanager 2> /dev/null && echo "disabling the skymanager service"
  echo "REBOOT"
  reboot now
#reboot happens either way and was the least painful option to easily address potential network race conditions
