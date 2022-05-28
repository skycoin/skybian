#!/usr/bin/bash
#build until the server quits segfaulting on compression
#don't forget to update checksums first
updpkgsums skyraspbian.rpi3.IMGBUILD
if mountpoint -q -- "src/mnt"; then
	sudo umount -l src/mnt
fi
[[ $(losetup | grep /dev/loop0) == *"/dev/loop0"* ]] && sudo losetup -d /dev/loop0
if [[ $1 == "1" ]]; then
	#build once and dont compress the archive ; for testing
NOZIP="1" makepkg  --noarchive -fp skyraspbian.rpi3.IMGBUILD
else
makepkg --skippgpcheck -fp skyraspbian.rpi3.IMGBUILD || makepkg --skippgpcheck -fRp skyraspbian.rpi3.IMGBUILD || makepkg --skippgpcheck -fRp skyraspbian.rpi3.IMGBUILD || makepkg --skippgpcheck -fRp skyraspbian.rpi3.IMGBUILD || makepkg --skippgpcheck -fRp skyraspbian.rpi3.IMGBUILD || makepkg --skippgpcheck -fRp skyraspbian.rpi3.IMGBUILD
