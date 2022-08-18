#!/usr/bin/bash
#don't forget to update checksums first
if [[ ${SKYBIAN} != "sky"*".IMGBUILD" ]] ; then
	echo "error no build specified"
	echo "Valid options include:"
	echo "SKYBIAN=skybian.prime.IMGBUILD"
	echo "SKYBIAN=skybian.opi3.IMGBUILD"
	echo "SKYBIAN=skyraspbian.rpi3.IMGBUILD"
	echo "SKYBIAN=skyraspbian.rpi4.IMGBUILD"
	exit 0
fi
unset PKGEXT
updpkgsums ${SKYBIAN}
if [[ "$1" == "0" ]]; then
	exit 0
fi
sudo umount -l src/mnt
sudo losetup -d /dev/loop0
if [[ "$1" == "1" ]]; then
	#build once and dont compress the archive ; for testing the image
makepkg  --noarchive -fp ${SKYBIAN}
else
	#attempt the compression until success ; for building o the server
	#PKGEXT must be a valid format that makepkg can produce
	export PKGEXT='.pkg.tar.zst'
	makepkg -fp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN}
	export PKGEXT='.pkg.tar.xz'
	makepkg -fp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN}
	unset PKGEXT
fi
if [[ "$1" == "zip" ]]; then
	cd pkg
	_msg2 "Creating .zip archive"
	source ${SKYBIAN}
	export _zip=${pkgname}-${pkgver}-${pkgrel}-${_imgarch}.img.zip
	zip -r ${_zip} ${pkgname} || zip -r ${_zip} ${pkgname} || zip -r ${_zip} ${pkgname} || zip -r ${_zip} ${pkgname} || zip -r ${_zip} ${pkgname} || zip -r ${_zip} ${pkgname} || zip -r ${_zip} ${pkgname} || zip -r ${_zip} ${pkgname} || zip -r ${_zip} ${pkgname} || zip -r ${_zip} ${pkgname} || zip -r ${_zip} ${pkgname}
	mv *.zip ../
	unset _zip
	cd ..
fi
