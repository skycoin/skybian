#!/bin/bash

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# function to log messages as info
function info() {
    printf '\033[0;32m[ Info ]\033[0m %s\n' "${1}"
}

# Chroot extra commands. This allow us to pass some extra commands
# inside the chroot, for example to install/remove additional pkgs
# or execute some bash commands


# change root password to the default of: skybian
info "Setting default root password to 'skybian'..."
printf "skybian\nskybian\n" | passwd root

# by default update the es_US locales
info "Re-generating the locales info for en_US.UTF-8..."
locale-gen en_US.UTF-8

# apt-get commands (install/remove/purge)
# modify and un-comment
info "Updating your system via APT"
export DEBIAN_FRONTEND=noninteractive
apt-get -y update

info "Installing ntp"
# (courtesy of https://github.com/some4/skywire-install-bash/blob/master/install.sh)
# Stop timesyncd:
systemctl stop systemd-timesyncd.service

info "Setting up ntp"
# Backup (but don't overwrite an existing) config. If not, sed will keep
#   appending file:
cp -n /etc/systemd/timesyncd.conf /etc/systemd/timesyncd.orig
# Use fresh copy in case installer used on existing system:
cp /etc/systemd/timesyncd.orig /etc/systemd/timesyncd.conf

# When system is set to sync with RTC the time can't be updated and NTP
#   is crippled. Switch off that setting with:
timedatectl set-local-rtc 0
timedatectl set-ntp on
apt install -y ntp

systemctl disable systemd-timesyncd.service

info "Restarting NTP..."
systemctl restart ntp.service

# keep this on the very end of this block
info "Cleaning the APT cache to make a smaller image"
apt-get clean

# forge a time on the system to avoid fs dates are in the future
info "Setting the chroot clock to now to avoid bugs with the date..."
/sbin/fake-hwclock save force

# Mkdir
mkdir -p /etc/skywire-hypervisor || 0
mkdir -p /var/skywire-hypervisor || 0

# Enable systemd units.
info "Enabling systemd units..."
systemctl enable skybian-firstrun.service || exit 1
