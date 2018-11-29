#!/bin/bash

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

# your custom commands here
