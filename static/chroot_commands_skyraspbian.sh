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
info "Setting default pi password to 'skybian'..."
printf "skybian\nskybian\n" | passwd pi

# by default update the es_US locales
info "Re-generating the locales info for en_US.UTF-8..."
sudo locale-gen en_US.UTF-8

# apt-get commands (install/remove/purge)
# modify and un-comment
info "Updating your system via APT"
export DEBIAN_FRONTEND=noninteractive
sudo apt -y update
sudo apt -y install network-manager toilet figlet
#apt-get -y remove --purge [your_pkgs_here]
# keep this on the very end of this block
info "Cleaning the APT cache to make a smaller image"
sudo apt clean

# forge a time on the system to avoid fs dates are in the future
#info "Setting the chroot clock to now to avoid bugs with the date..."
#/sbin/fake-hwclock save force

# Mkdir
sudo mkdir -p /etc/skywire-hypervisor || 0
sudo mkdir -p /var/skywire-hypervisor || 0

# Enable systemd units.
info "Enabling systemd units..."
sudo systemctl enable skybian-firstrun.service || exit 1
