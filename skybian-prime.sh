#!/usr/bin/bash
#don't forget to update checksums first
[[ -f Bullseye_current.sha ]] && rm Bullseye_current.sha
updpkgsums skybian.prime.IMGBUILD
if [[ "$1" == "0" ]]; then
	exit 0
fi
sudo umount -l src/mnt
sudo losetup -d /dev/loop0
if [[ "$1" == "1" ]]; then
	#build once and dont compress the archive ; for testing
makepkg  --noarchive -fp skybian.prime.IMGBUILD
else
	#attempt the compression until success
	PKGEXT='.pkg.tar.zst' makepkg -fp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.prime.IMGBUILD
	PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.prime.IMGBUILD
#	PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.prime.IMGBUILD
fi
