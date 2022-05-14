#!/bin/bash
#Reset skybian for testing of autoconfig
[[ -f /etc/systemd/system/skywire.service ]] && systemctl disable --now skywire.service 2> /dev/null
[[ -f /etc/systemd/system/skywire-visor.service ]] && systemctl disable --now skywire-visor.service 2> /dev/null
[[ -f /etc/systemd/system/skywire-autoconfig.service ]] && systemctl disable --now skywire-autoconfig.service 2> /dev/null
[[ -f /etc/systemd/system/skywire-autoconfig-remote.service ]] && systemctl disable --now skywire-autoconfig-remote.service 2> /dev/null
[[ -f /etc/lib/systemd/system/skywire-hypervisor.service ]] && systemctl disable --now skywire-hypervisor.service 2> /dev/null
rm /opt/skywire/skywire*.json
