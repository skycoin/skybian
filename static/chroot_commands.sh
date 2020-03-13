#!/bin/bash

HOME=/root
SKYWIRE_DIR=${HOME}/skywire
export HOME
export SKYWIRE_DIR
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
info "Updating apt..."
export DEBIAN_FRONTEND=noninteractive
apt-get -y update
#apt-get -y remove --purge [your_pkgs_here]
# keep this on the very end of this block
info "Cleaning apt cache..."
apt-get clean

info "Installing jq..."
dpkg -i /tmp/jq/*.deb

# forge a time on the system to avoid fs dates are in the future
info "Setting the chroot clock to now to avoid bugs with the date..."
/sbin/fake-hwclock save force

# Enable systemd units.
info "Enabling systemd units..."
systemctl enable skybian-conf.service || return 1
systemctl enable skywire-visor.service || return 1

# your custom commands here