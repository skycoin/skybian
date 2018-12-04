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

# Chroot extra commands. This allow us to pass some extra commands
# inside the chroot, for example to install/remove additional pkgs
# or execute some bash commands

# by default update the es_US locales
locale-gen en_US.UTF-8

# apt-get commands (install/remove/purge)
# modify and un-comment
export DEBIAN_FRONTEND=noninteractive
apt-get -y update
#apt-get -y install [your_pkgs_here]
#apt-get -y remove --purge [your_pkgs_here]
# keep this ot the very end of this block
apt-get clean

# compile skywire (folder is already created by install skywire)
cd ${SKYWIRE_DIR}/cmd
${GOROOT}/bin/go install -v ./...

# forge a time on the system to avoid fs dates are in the future
/sbin/fake-hwclock save force

# your custom commands here
