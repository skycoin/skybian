#!/bin/bash

# Go vars: WARNING! this must match the ones defined in skywire
# see http://github.com/skycoin/skywire
HOME=/root
GOROOT=/usr/local/go
GOPATH=/usr/local/skywire/go
SKYCOIN_DIR=${GOPATH}/src/github.com/skycoin
SKYWIRE_DIR=${SKYCOIN_DIR}/skywire
export HOME
export GOROOT
export GOPATH
export SKYCOIN_DIR 
export SKYWIRE_DIR

# function to log messages as info
function info() {
    printf '\033[0;32m[ Info ]\033[0m %s\n' "${1}"
}

# Chroot extra commands. This allow us to pass some extra commands
# inside the chroot, for example to install/remove additional pkgs
# or execute some bash commands

# by default update the es_US locales
info "Re-generating the locales info for en_US.UTF-8"
locale-gen en_US.UTF-8

# apt-get commands (install/remove/purge)
# modify and un-comment
info "Updating your system via APT"
export DEBIAN_FRONTEND=noninteractive
apt-get -y update
#apt-get -y install [your_pkgs_here]
#apt-get -y remove --purge [your_pkgs_here]
# keep this ot the very end of this block
info "Cleanign the APT cache to make a smaller image"
apt-get clean

# compile skywire (folder is already created by install skywire)
info "Compile Skywire inside the chroot"
cd ${SKYWIRE_DIR}/cmd
${GOROOT}/bin/go install -v ./...

# forge a time on the system to avoid fs dates are in the future
info "Setting the chroot clock to now to avoid bugs with the date"
/sbin/fake-hwclock save force

# your custom commands here
