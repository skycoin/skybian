#!/usr/bin/bash
#build until the server quits segfaulting on compression
#don't forget to update checksums first
updpkgsums skybian.IMGBUILD
sudo umount -l src/mnt
sudo losetup -d /dev/loop0
if [[ $1 == "1" ]]; then
makepkg  --noarchive -fp skybian.IMGBUILD
else
makepkg -fp skybian.IMGBUILD || makepkg --skippgpcheck -fRp skybian.IMGBUILD || makepkg --skippgpcheck -fRp skybian.IMGBUILD || makepkg --skippgpcheck -fRp skybian.IMGBUILD || makepkg --skippgpcheck -fRp skybian.IMGBUILD || makepkg --skippgpcheck -fRp skybian.IMGBUILD
fi
