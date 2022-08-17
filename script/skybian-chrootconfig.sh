#!/bin/bash
##/usr/bin/skybian-chrootconfig
#called by the postinstall script of the skybian .deb package
#################################################################
#meant to run when the skybian package is installed in chroot
if [[ $INSTALLFIRSTBOOT == "1" ]] ; then
	if [[ -f /etc/systemd/system/install-skywire.service ]] ; then
		systemctl enable install-skywire
	fi
fi
# Set environmental variables
if [[ ! -f /etc/profile.d/skyenv.sh && -d /etc/profile.d ]] ; then
	touch /etc/profile.d/skyenv.sh
fi
if [[ $(cat /etc/profile.d/skyenv.sh | grep SKYBIAN ) != *"SKYBIAN"* ]] ; then
	if [[ $(dpkg --print-architecture) == *"amd64"* ]] ; then
		echo "#SKYBIAN=true" | tee -a /etc/profile.d/skyenv.sh
	else
		echo "SKYBIAN=true" | tee -a /etc/profile.d/skyenv.sh
	fi
fi
if [[ $(cat /etc/profile.d/skyenv.sh | grep VPNSERVER ) != *"VPNSERVER"* ]] ; then
	if [[ $(dpkg --print-architecture) == *"amd64"* ]] ; then
		echo "#export VPNSERVER=1" | tee -a /etc/profile.d/skyenv.sh
	else
		echo "export VPNSERVER=1" | tee -a /etc/profile.d/skyenv.sh
	fi
fi

if [[ $(cat /etc/profile.d/skyenv.sh | grep VISORISPUBLIC ) != *"VISORISPUBLIC"* ]] ; then
	if [[ "${TESTDEPLOYMENT}" == "1" ]] ; then
		echo "export VISORISPUBLIC=1" | tee -a /etc/profile.d/skyenv.sh
	else
		echo "#export VISORISPUBLIC=1" | tee -a /etc/profile.d/skyenv.sh
	fi
fi
if [[ $(cat /etc/profile.d/skyenv.sh | grep NOAUTOCONNECT ) != *"NOAUTOCONNECT"* ]] ; then
	if [[ "${TESTDEPLOYMENT}" == "1" ]] ; then
		echo "export NOAUTOCONNECT=1" | tee -a /etc/profile.d/skyenv.sh
	else
		echo "#export NOAUTOCONNECT=1" | tee -a /etc/profile.d/skyenv.sh
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
