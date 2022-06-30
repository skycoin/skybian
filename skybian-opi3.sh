#!/usr/bin/bash
#don't forget to update checksums first
updpkgsums skybian.opi3.IMGBUILD
sudo umount -l src/mnt
sudo losetup -d /dev/loop0
if [[ $1 == "1" ]]; then
	#build once and dont compress the archive ; for testing
makepkg  --noarchive -fp skybian.opi3.IMGBUILD
else
	#attempt the compression until success
	PKGEXT='.pkg.tar.zst' makepkg -fp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.zst' makepkg -fRp skybian.opi3.IMGBUILD
	PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.opi3.IMGBUILD ||     PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.xz' makepkg -fRp skybian.opi3.IMGBUILD
	PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.opi3.IMGBUILD ||     PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.opi3.IMGBUILD || PKGEXT='.pkg.tar.gz' makepkg -fRp skybian.opi3.IMGBUILD
#	mmv '*.any.pkg.tar.zst' '#1.arm64.img.tar.zst'
#	mmv '*.any.pkg.tar.xz' '#1.arm64.img.tar.xz'
#	mmv '*.any.pkg.tar.gz' '#1.arm64.img.tar.gz'
fi
