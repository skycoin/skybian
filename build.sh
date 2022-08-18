#!/usr/bin/bash
# $1 == "0"		only update checksums -> freshly download packages from apt repo
# $1 == "1"		only build the image ; without compressing
# $1 == ""		build the images and compress the image archives .xz and .zst
# $1 == "zip"		build the images and compress the image archives .xz and .zst
[[ $1 == "0" ]] && rm *.deb
SKYBIAN=skybian.prime.IMGBUILD ./image.sh $1
SKYBIAN=skybian.opi3.IMGBUILD ./image.sh $1
SKYBIAN=skyraspbian.rpi3.IMGBUILD ./image.sh $1
SKYBIAN=skyraspbian.rpi4.IMGBUILD ./image.sh $1
