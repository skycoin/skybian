#!/bin/bash
# Created by @evanlinjin

# TODO(evanlinjin): Write documentation for the following:
# - Where we are placing the boot params.
# - Values of the boot params.

DEV_FILE=/dev/mmcblk0
CONFIG_FILE=/etc/skywire-config.json

TLS_KEY=/etc/skywire-hypervisor/key.pem
TLS_CERT=/etc/skywire-hypervisor/cert.pem

NET_NAME="Wired connection 1"
WIFI_NAME="Wireless connection 1"

# Stop here if config files are already generated.
if [[ -f "$CONFIG_FILE" ]]; then
  echo "Nothing to be done here."
  sudo systemctl disable skybian-firstrun.service
  exit 0
fi

# 'setup_skywire' extracts boot parameters.
# These parameters are stored in the MBR (Master Boot Record) Bootstrap code
# area of the boot device. This starts at position +0E0(hex) and has 216 bytes.
setup_skywire()
{
  if ! readonly BOOT_PARAMS=$(/usr/bin/skyconf -if=$DEV_FILE -c=$CONFIG_FILE -keyf=$TLS_KEY -certf=$TLS_CERT); then
    echo "Failed to setup skywire environment."
    return 1
  fi

  # Obtains the following ENVs from boot params:
  # MD IP GW PK SK HVS SS SUCCESS LOGFILE
  echo "-----BEGIN BOOT PARAMS-----"
  echo "$BOOT_PARAMS"
  echo "-----END BOOT PARAMS-----"
  if ! eval "$BOOT_PARAMS"; then
    echo "Failed to eval boot params."
    return 1
  fi

  # Print 'skyconf' logs.
  if [[ -n "$LOGFILE" ]] ; then
    echo "-----BEGIN SKYCONF LOGS-----"
    $(command -v cat) - < "$LOGFILE" | while IFS= read -r line; do
      echo "$line"
    done
    echo "-----END SKYCONF LOGS-----"
  else
    echo "Cannot access 'skyconf' logs."
  fi
}
setup_skywire || exit 1

# 'setup_network' sets up networking for Skybian.
# It uses the IP (local IP address) and GW (Gateway IP address) of the boot
# params. If these are not defined, defaults will be kept.

# Disable dhcpcd in order to set the wifi correctly otherwise an error will be received when trying to start the wifi
sudo systemctl stop dhcpcd
sudo systemctl disable dhcpcd

setup_network()
{
  echo "Setting up network $NET_NAME..."

  if [[ -n "$IP" ]]; then
    echo "Setting manual IP to $IP for $NET_NAME."
    sudo nmcli con mod "$NET_NAME" ipv4.addresses "$IP/24" ipv4.method "manual"
  fi

  if [[ -n "$GW" ]]; then
    echo "Setting manual Gateway IP to $GW for $NET_NAME."
    sudo nmcli con mod "$NET_NAME" ipv4.gateway "$GW"
  fi

  sudo nmcli con mod "$NET_NAME" ipv4.dns "1.0.0.1, 1.1.1.1"
  sudo sleep 3
  sudo nmcli con up "$NET_NAME"
}

setup_wifi()
{
  echo "Setting up wifi connection $WIFI_NAME..."
  sudo nmcli c add type wifi con-name "$WIFI_NAME" ifname wlan0 ssid $WFN
  if [[ -n "$WFP" ]]; then
    sudo nmcli c modify "$WIFI_NAME" wifi-sec.key-mgmt wpa-psk wifi-sec.psk $WFP
  fi

  if [[ -n "$IP" && -n "$GW" ]]; then
    echo "Setting manual IP to $IP for $WIFI_NAME."
    sudo nmcli con mod "$WIFI_NAME" ipv4.addresses "$IP/24" ipv4.method "manual"
  fi

  if [[ -n "$GW" ]]; then
    echo "Setting manual Gateway IP to $GW for $WIFI_NAME."
    sudo nmcli con mod "$WIFI_NAME" ipv4.gateway "$GW"
  fi
  sudo nmcli con mod "$WIFI_NAME" ipv4.dns "1.0.0.1, 1.1.1.1"
  sudo nmcli con down "$WIFI_NAME"
  sudo sleep 3
  sudo nmcli con up "$WIFI_NAME"
  sudo sleep 10
}

# assume wifi should be configured instead of ethernet when wifi name env var is set
if [[ -n "$WFN" ]]; then
  setup_wifi || exit 1
else
  setup_network || exit 1
fi

for file in /etc/ssh/ssh_host* ; do
  echo "[skybian-firstrun] Checking $file:"
  cat "$file"
done

echo "Enabling 'skywire-visor.service'."
sudo systemctl enable skywire-visor.service
sleep 2
sudo systemctl start skywire-visor.service

install_ntp()
{
    # (courtesy of https://github.com/some4/skywire-install-bash/blob/master/install.sh)
    # Stop timesyncd:
    sudo systemctl stop systemd-timesyncd.service

    # Backup (but don't overwrite an existing) config. If not, sed will keep
    #   appending file:
    sudo cp -n /etc/systemd/timesyncd.conf /etc/systemd/timesyncd.orig
    # Use fresh copy in case installer used on existing system:
    sudo cp /etc/systemd/timesyncd.orig /etc/systemd/timesyncd.conf

    # When system is set to sync with RTC the time can't be updated and NTP
    #   is crippled. Switch off that setting with:
    sudo timedatectl set-local-rtc 0
    sudo timedatectl set-ntp on
    sudo apt update && sudo apt install -y ntp

    sudo systemctl disable systemd-timesyncd.service

    info "Restarting NTP..."
    sudo systemctl restart ntp.service
    # Set hardware clock to UTC (which doesn't have daylight savings):
    sudo hwclock -w
}
install_ntp || logger "Failed to setup ntp service"

# Set time and date using google
sudo date -s "$(curl -s --head http://google.com | grep ^Date: | sed 's/Date: //g')"

sudo systemctl disable skybian-firstrun.service
exit 0
