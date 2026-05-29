#!/usr/bin/bash
# $1 == "0"		only update checksums (no build)
# $1 == "1"		build the image without compression (fastest, for iterating)
# $1 == ""		build the image + .zst + .xz compressed archives
# $1 == "zip"		build + .zst + .xz + .zip archives (Windows imagers)
#
# build() failures are fatal ; the compression / zip steps retry up to
# 11 times to ride out the segfault we used to hit on the server, but
# never re-run build() blindly.
set -e

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

# Source the IMGBUILD so we can reference $pkgname, $pkgver, $_imgarch
# in the post-build mv steps.
source ${SKYBIAN}

# Cleanup any leftover mount / loop state from a prior unclean run.
# Use mountpoint -q so we don't false-positive on "src/mnt looks like a
# mount because awk parsed something weird."
if mountpoint -q src/mnt 2>/dev/null ; then
	_msg2 "unmounting lingering src/mnt"
	sudo umount -lR src/mnt
fi
if mountpoint -q src/boot 2>/dev/null ; then
	sudo umount -lR src/boot
fi
sudo losetup -d /dev/loop0 2>/dev/null && \
	echo "detached /dev/loop0 from a previous unclean exit" || true

# _retry_makepkg <max-attempts> <makepkg-args...>
# Used only for the -R (repackage-only) compression attempts where the
# retry actually makes sense.
_retry_makepkg() {
	local _max=$1 ; shift
	local _n=0
	until makepkg "$@" ${SKYBIAN} ; do
		_n=$((_n + 1))
		if (( _n >= _max )); then
			echo "ERROR: makepkg failed after $_n attempts with args: $*" >&2
			return 1
		fi
		echo "retrying makepkg (attempt $((_n+1))/${_max}) with args: $*"
	done
}

if [[ "$1" == "1" ]]; then
	# Build the image only ; skip compression. Fail-fast (set -e covers it).
	makepkg --noarchive -fp ${SKYBIAN}
	exit 0
fi

# Full build + compression path.
# Step 1: build the .img (no archive yet). Fail-fast.
makepkg --noarchive -fp ${SKYBIAN}

# Step 2: compress to .zst then .xz, retrying the package() step only.
# -R = repackage-only ; build() already ran above so this just re-walks
# package() with the new PKGEXT.
export PKGEXT='.pkg.tar.zst'
_retry_makepkg 11 -fRp
mv ${pkgname}-${pkgver}-${pkgrel}-any.${PKGEXT/./} ${pkgname}-${pkgver}-${pkgrel}-${_imgarch}.img.${PKGEXT/.pkg./}

export PKGEXT='.pkg.tar.xz'
_retry_makepkg 11 -fRp
mv ${pkgname}-${pkgver}-${pkgrel}-any.${PKGEXT/./} ${pkgname}-${pkgver}-${pkgrel}-${_imgarch}.img.${PKGEXT/.pkg./}
unset PKGEXT

# Step 3 (optional): zip on top.
if [[ "$1" == "zip" ]]; then
	cd pkg
	export _zip=${pkgname}-${pkgver}-${pkgrel}-${_imgarch}.img.zip
	_n=0
	until zip -r "${_zip}" "${pkgname}" ; do
		_n=$((_n + 1))
		if (( _n >= 11 )); then
			echo "ERROR: zip failed after $_n attempts" >&2
			exit 1
		fi
		echo "retrying zip (attempt $((_n+1))/11)"
	done
	mv *.zip ../
	unset _zip
	cd ..
fi
