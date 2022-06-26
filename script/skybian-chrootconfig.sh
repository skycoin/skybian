#!/bin/bash
##/usr/bin/skybian-chrootconfig
#called by the postinstall script of the skybian .deb package
#################################################################
#this script is meant to run when the skybian package is installed in an arm chroot
if [[ -z $CHROOTCONFIG ]] ; then
  exit 0
fi
# only do on ARM architectures
if [[ $(dpkg --print-architecture) != "amd64" ]]; then
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
