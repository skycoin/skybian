#!/usr/bin/bash
#don't forget to update checksums first with $1 = "0"
if [[ ${SKYBIAN} != "sky"*".IMGBUILD" ]] ; then
	echo 'error no build specified'
	echo 'Valid options include:'
	echo 'SKYBIAN=skybian.prime.IMGBUILD'
	echo 'ENABLEAUTOPEER="-autopeer" SKYBIAN=skybian.prime.IMGBUILD'
	echo 'SKYBIAN=skybian.opi3.IMGBUILD'
	echo 'SKYBIAN=skyraspbian.rpi3.IMGBUILD'
	echo 'SKYBIAN=skyraspbian.rpi4.IMGBUILD'
	exit 0
fi
unset PKGEXT
updpkgsums ${SKYBIAN}
if [[ "$1" == "0" ]]; then
	exit 0
fi
source ${SKYBIAN}
if mount | awk '{if ($3 == "src/mnt") { exit 0}} ENDFILE{exit -1}'; then
	_msg2 "unmounting lingering mounted dir"
	sudo umount -l src/mnt
    fi
losetup /dev/loop0 && 	_msg2 "detatching loop device after previous unclean exit" && sudo losetup -d /dev/loop0
if [[ "$1" == "1" ]]; then
	#build once and dont compress the archive ; for testing the image
makepkg  --noarchive -fp ${SKYBIAN}
else
if [[ "$1" != "1" ]]; then
	#attempt the compression until success ; for building on the server
	#PKGEXT must be a valid format that makepkg can produce
	export PKGEXT='.pkg.tar.zst'
	makepkg -fp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN}
	mv ${pkgname}-${pkgver}-${pkgrel}-any.${PKGEXT/./} ${pkgname}-${pkgver}-${pkgrel}-${_imgarch}.img.${PKGEXT/.pkg./}
	export PKGEXT='.pkg.tar.xz'
	makepkg -fp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN} || makepkg -fRp  ${SKYBIAN}
	mv ${pkgname}-${pkgver}-${pkgrel}-any.${PKGEXT/./} ${pkgname}-${pkgver}-${pkgrel}-${_imgarch}.img.${PKGEXT/.pkg./}
	unset PKGEXT
fi
if [[ "$1" == "zip" ]]; then
	cd pkg
	_msg2 "Creating .zip archive"
	export _zip=${pkgname}-${pkgver}-${pkgrel}-${_imgarch}.img.zip
	echo $_zip
	echo "zip -r ${_zip} ${pkgname}"
	zip -r ${_zip} ${pkgname} || zip -r ${_zip} ${pkgname} || zip -r ${_zip} ${pkgname} || zip -r ${_zip} ${pkgname} || zip -r ${_zip} ${pkgname} || zip -r ${_zip} ${pkgname} || zip -r ${_zip} ${pkgname} || zip -r ${_zip} ${pkgname} || zip -r ${_zip} ${pkgname} || zip -r ${_zip} ${pkgname} || zip -r ${_zip} ${pkgname}
	mv *.zip ../
	unset _zip
	cd ..
fi
fi
