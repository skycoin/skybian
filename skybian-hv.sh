#!/usr/bin/bash
#build until the server quits segfaulting on compression
#don't forget to update checksums first
updpkgsums skybianhv.IMGBUILD
sudo umount -l src/mnt
sudo losetup -d /dev/loop0
if [[ $1 == "1" ]]; then
makepkg --noarchive -fp skybianhv.IMGBUILD
else
makepkg -fp skybianhv.IMGBUILD || makepkg --skippgpcheck -fRp skybianhv.IMGBUILD || makepkg --skippgpcheck -fRp skybianhv.IMGBUILD || makepkg --skippgpcheck -fRp skybianhv.IMGBUILD || makepkg --skippgpcheck -fRp skybianhv.IMGBUILD || makepkg --skippgpcheck -fRp skybianhv.IMGBUILD
fi
