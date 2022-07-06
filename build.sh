#!/usr/bin/bash
# $1 == "0"		only update checksums -> freshly download packages from apt repo
# $1 == "1"		only build the image ; without compressing
# $1 == ""		build the images and compress the image archives .xz and .zst
[[ $1 == "0" ]] && rm *.deb
./skybian-prime.sh $1
./skybian-opi3.sh $1
./skyraspbian-rpi3.sh $1
./skyraspbian-rpi4.sh $1
