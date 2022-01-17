#!/bin/bash
#script edit hypervisor config to allow rpc and restart skywire
if [[ $EUID -ne 0 ]]; then
   echo -e "Root permissions required" 1>&2
   exit 100
fi
[[ ! -f /opt/skywire/skywire.json ]] && echo "error: skywire config not found" && exit 1
systemctl disable skybian-patch-config 2> /dev/null && echo "disabling skybian-patch-config"
systemctl disable --now skywire 2> /dev/null && echo "stopping skywire for a moment"
sed -i 's/"cli_addr": "localhost:3435",/"cli_addr": ":3435",/g' /opt/skywire/skywire.json && echo "setting cli_addr in skywire config file to ':3435'"
systemctl enable --now skywire 2> /dev/null && echo "starting skywire"
