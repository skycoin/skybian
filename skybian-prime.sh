#!/usr/bin/bash
#build until the server quits segfaulting on compression
#don't forget to update checksums first
updpkgsums skybian.prime.IMGBUILD
sudo umount -l src/mnt
sudo losetup -d /dev/loop0
if [[ $1 == "1" ]]; then
	#build once and dont compress the archive ; for testing
NOZIP="1" makepkg  --noarchive -fp skybian.prime.IMGBUILD
else
makepkg -fp skybian.prime.IMGBUILD || makepkg --skippgpcheck -fRp skybian.prime.IMGBUILD || makepkg --skippgpcheck -fRp skybian.prime.IMGBUILD || makepkg --skippgpcheck -fRp skybian.prime.IMGBUILD || makepkg --skippgpcheck -fRp skybian.prime.IMGBUILD || makepkg --skippgpcheck -fRp skybian.prime.IMGBUILD
fi
