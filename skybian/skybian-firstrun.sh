#!/bin/bash
NET_NAME="Wired connection 1"
WIFI_NAME="Wireless connection 1"
_gateway=$(ip route show | grep -i 'default via'| awk '{print $3 }')
_ip=$(ip route show | grep -i 'default via'| awk '{print $3 }' | /usr/bin/sed 's/\.[^.]*$//').2


setup_network()
{
  echo "Setting up network $NET_NAME..."

if [[ arp -a ${_ip} == *no match found* ]] ; then
    echo "Setting manual IP to $_ip for $NET_NAME."
    sudo nmcli con mod "$NET_NAME" ipv4.addresses "${_ip}/24" ipv4.method "manual"
  fi

    echo "Setting manual Gateway IP to $_gateway for $NET_NAME."
    sudo nmcli con mod "$NET_NAME" ipv4.gateway "${_gateway}"
  fi

  sudo nmcli con mod "$NET_NAME" ipv4.dns "1.0.0.1, 1.1.1.1"
  sudo sleep 3
  sudo nmcli con up "$NET_NAME"
}

  setup_network || exit 1
