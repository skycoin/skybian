#!/usr/bin/bash
# $1 == "0"		only update checksums -> freshly download packages from apt repo
# $1 == "1"		only build the image ; without compressing
# $1 == ""		build the images and compress the image archives .xz and .zst
# $1 == "zip"		build the images and compress the image archives ; additionally preform .zip compression
#
# Aborts on the first failed build (set -e) ; cleanup() unwinds any
# leftover mount / loop state so the next attempt isn't blocked.
set -e

cleanup() {
	# Always succeed — we're in a trap and a failure here would mask the
	# original error code.
	set +e
	# Best-effort umount of any path we mount under src/mnt.
	if mountpoint -q ./src/mnt 2>/dev/null ; then
		sudo umount -lR ./src/mnt 2>/dev/null
	fi
	if mountpoint -q ./src/boot 2>/dev/null ; then
		sudo umount -lR ./src/boot 2>/dev/null
	fi
	# Detach any loop device still bound to a working image.
	for _img in *.img ; do
		[[ -e "$_img" ]] || continue
		while read -r _dev ; do
			[[ -n "$_dev" ]] && sudo losetup -d "$_dev" 2>/dev/null
		done < <(sudo losetup -j "$_img" 2>/dev/null | cut -d: -f1)
	done
	# /dev/loop0 is the conventional target used by image.sh ; nuke it
	# unconditionally so a partial run can't leave it claimed.
	sudo losetup -d /dev/loop0 2>/dev/null
}
trap cleanup EXIT

[[ $1 == "0" ]] && rm -f *.deb
SKYBIAN=skybian.prime.IMGBUILD ./image.sh $1
ENABLEAUTOPEER="-autopeer" SKYBIAN=skybian.prime.IMGBUILD ./image.sh $1
SKYBIAN=skybian.opi3.IMGBUILD ./image.sh $1
SKYBIAN=skyraspbian.rpi3.IMGBUILD ./image.sh $1
SKYBIAN=skyraspbian.rpi4.IMGBUILD ./image.sh $1
