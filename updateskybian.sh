#!/usr/bin/bash
#update the image - only run on arm64 / aarch64 host
# depends gnome-disk-utility and arch-install-scripts
if [[ $EUID -ne 0 ]]; then
   echo -e "Root permissions required" 1>&2
   exit 100
fi
_msg2() {
(( QUIET )) && return
local mesg=$1; shift
printf "${BLUE}  ->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@"
}
_msg2 "mounting image to loop device.."
[[ -f /skybian.img ]] && gnome-disk-image-mounter -w /skybian.img || echo "error: resource not found" && exit 1
_msg2 "creating mount dir"
mkdir -p /mnt
_msg2 "mounting /dev/loop0p1 to mount point"
mount /dev/loop0p1 /mnt || echo "error: could not mount loop device"
_msg2 "updating image"
arch-chroot ${srcdir}/mnt sudo apt update
arch-chroot ${srcdir}/mnt sudo apt upgrade
arch-chroot ${srcdir}/mnt sudo skybian-reset
_msg2 "unmounting image"
umount /mnt
_msg2 "detatching /dev/loop0"
losetup -d /dev/loop0
