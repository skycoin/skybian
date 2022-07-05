#!/bin/bash
##/usr/bin/skybian-chrootconfig
#called by the postinstall script of the skybian .deb package
#################################################################
#meant to run when the skybian package is installed in chroot
if [[ $INSTALLFIRSTBOOT == "1" ]] ; then
	if [[ -f /etc/systemd/system/ install-skywire.service ]] ; then
		systemctl enable install-skywire
	fi
fi
#limit the ip setting / autopeering to only if CHROOTCONFIG env has been passed to the script
if [[ -z $CHROOTCONFIG ]] ; then 
  exit 0
fi
if [[ -f /etc/systemd/system/skymanager.service ]] ; then
	sudo systemctl enable skymanager
	#enable the wait online service - required for skymanager
	systemctl enable NetworkManager-wait-online
	systemctl enable systemd-networkd
	systemctl enable systemd-networkd-wait-online
else
  echo "error skymanager service not found"
fi
