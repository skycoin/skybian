#!/bin/bash
##/usr/bin/skybian-chrootconfig
#################################################################
#this script is run with the assumption
#that the skybian package is installed in chroot
#and that this script is being executed in chroot
#as called by the postinstall script of the skybian .deb package
#################################################################

if [[ -z $CHROOTCONFIG ]] ; then
  exit 0
fi
# only do on ARM architectures
if [[ $(dpkg --print-architecture) != "amd64" ]]; then
#skymanager substituites for the former skybian-firstrun script ;
#skymanager either sets ip for hypervisor and reboots; then configures hypervisor
#or starts the skywire-visor-firstboot
#to query hypervisor public key from rpc from the ip set on hypervisor
#skywire-install installs skywire if skywire is not installed
if [[ -f /etc/systemd/system/skymanager.service ]] ; then
	sudo systemctl enable skymanager
else
  echo "error skymanager service not found"
fi

#enable the wait online service
systemctl enable NetworkManager-wait-online
systemctl enable systemd-networkd
systemctl enable systemd-networkd-wait-online
fi
