#!/bin/bash
##/usr/bin/skybian-chrootconfig
#called by the postinstall script of the skybian .deb package
#################################################################
#meant to run when the skybian package is installed in chroot

# Set environmental variables for skywire-autoconfig to consume on first run.
# The skywire-bin postinst writes /etc/skywire.conf from these defaults if no
# config file already exists, so what we set here becomes the bootstrap.
if [[ ! -f /etc/profile.d/skyenv.sh && -d /etc/profile.d ]] ; then
	touch /etc/profile.d/skyenv.sh
fi
if [[ $(cat /etc/profile.d/skyenv.sh | grep SKYBIAN ) != *"SKYBIAN"* ]] ; then
	echo "SKYBIAN=true" | tee -a /etc/profile.d/skyenv.sh
fi
if [[ $(cat /etc/profile.d/skyenv.sh | grep VPNSERVER ) != *"VPNSERVER"* ]] ; then
	echo "export VPNSERVER=1" | tee -a /etc/profile.d/skyenv.sh
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

# install-skywire.service is now provided and enabled by the skyrepo deb
# (skyrepo's /usr/bin/skywire-chrootconfig handles it under INSTALLFIRSTBOOT=1).
# We do not enable it here to avoid duplicate work.

#limit the ip setting / autopeering to only if CHROOTCONFIG env has been passed to the script
if [[ -z $CHROOTCONFIG ]] ; then
  exit 0
fi
if [[ -f /etc/systemd/system/skymanager.service ]] ; then
	sudo systemctl enable skymanager
	#enable the wait online service - required for skymanager
	systemctl enable NetworkManager-wait-online 2>/dev/null || true
	systemctl enable systemd-networkd 2>/dev/null || true
	systemctl enable systemd-networkd-wait-online 2>/dev/null || true
else
  echo "error skymanager service not found"
fi
