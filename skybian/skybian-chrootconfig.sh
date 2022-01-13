#!/bin/bash
#/usr/bin/skybian-chrootconfig
#################################################################
#this script is run with the assumption
#that the skybian package is installed in chroot
#and that this script is being executed in chroot
#as called by the postinstall script of the skybian .deb package
#################################################################

#enable config gen on boot - calls `skywire-autoconfig`
if [[ -f /etc/systemd/system/skywire-autoconfig.service ]] ; then
   sudo systemctl enable skywire-autoconfig && echo "enabling skywire-autoconfig"
 else
   echo "error skywire-autoconfig service not found"
 fi

#disable the skywire systemd service;
#it will be enabled and started by the autoconfig script
if [[ -f /etc/systemd/system/skywire.service ]] ; then
  sudo systemctl disable skywire && echo "disabling skywire"
else
  echo "error skywire not installed or service not found"
fi

#the former skybian-firstrun script ;
#either sets ip for hypervisor and reboots; then configures hypervisor
#or starts the skywire-visor-firstboot
#to query hypervisor public key from rpc from the ip set on hypervisor
if [[ -f /etc/systemd/system/skymanager.service ]] ; then
  sudo systemctl enable skymanager
else
  echo "error skymanager service not found"
fi

#enable the wait online service
systemctl enable NetworkManager-wait-online
