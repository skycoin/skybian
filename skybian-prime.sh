#!/usr/bin/bash
#don't forget to update checksums first
updpkgsums skybian.prime.IMGBUILD
sudo umount -l src/mnt
sudo losetup -d /dev/loop0
if [[ $1 == "1" ]]; then
	#build once and dont compress the archive ; for testing
makepkg  --noarchive -fp skybian.prime.IMGBUILD
else
	#attempt the compression until success
	PKGEXT='.pkg.tar.zst' makepkg -fp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.prime.IMGBUILD
	PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.prime.IMGBUILD
	PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.prime.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.prime.IMGBUILD
fi
mmv '*.any.pkg.tar.zst' '#1.arm64.img.tar.zst'
mmv '*.any.pkg.tar.xz' '#1.arm64.img.tar.xz'
mmv '*.any.pkg.tar.gz' '#1.arm64.img.tar.gz'
