#!/usr/bin/bash
#don't forget to update checksums first
updpkgsums skyraspbian.rpi4.IMGBUILD
if [[ "$1" == "0" ]]; then
	exit 0
fi
sudo umount -l src/mnt
sudo losetup -d /dev/loop0
if [[ "$1" == "1" ]]; then
	#build once and dont compress the archive ; for testing
makepkg  --noarchive -fp skyraspbian.rpi4.IMGBUILD
else
	#attempt the compression until success
	PKGEXT='.pkg.tar.zst' makepkg -fp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skyraspbian.rpi4.IMGBUILD ||                             PKGEXT='.pkg.tar.zst' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skyraspbian.rpi4.IMGBUILD
	PKGEXT='.pkg.tar.xz' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skyraspbian.rpi4.IMGBUILD ||                                    PKGEXT='.pkg.tar.xz' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skyraspbian.rpi4.IMGBUILD
	PKGEXT='.pkg.tar.gz' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skyraspbian.rpi4.IMGBUILD ||                                    PKGEXT='.pkg.tar.gz' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skyraspbian.rpi4.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skyraspbian.rpi4.IMGBUILD

fi
