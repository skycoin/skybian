pkgname=skyraspbian-${_imgarch}
pkgdesc="Skyraspbian ${_imgarch} image build"
pkgver='1.2.1'
pkgrel=1
arch=('any')
_hostarch=$(dpkg --print-architecture)
_img="2022-04-04-raspios-bullseye-${_imgarch}-lite.img"
_imgxz="${_img}.xz"
_xzlink="https://downloads.raspberrypi.org/raspios_lite_${_imgarch}/images/raspios_lite_${_imgarch}-2022-04-07/${_imgxz}"
_torrent="${_xzlink}.torrent"
_imgfinal="${pkgname}-${pkgver}.img"
_root_partition=/dev/loop0p2
_boot_partition=/dev/loop0p1
_defaultuser=pi
_skywiredeb="skywire-bin-${pkgver}-${pkgrel}-${_imgarch}.deb"
_skybiandeb="skybian-${_imgarch}.deb"
url="http://github.com/skycoin/skybian"
makedepends=('arch-install-scripts' 'aria2' 'dpkg' 'dtrx' 'gnome-disk-utility' 'qemu-user-static')
depends=()
_aptrepo="https://github.com/skycoin/apt-repo/releases/download"
source=("${_torrent}"
"${_aptrepo}/archive/${_skywiredeb}"
"${_aptrepo}/current/${_skybiandeb}"
"skyraspbian-conf.sh"
)
noextract=("${_skywiredeb}" "${_skybiandeb}")

prepare() {
cd "${srcdir}"
if [[ ! -f ${_imgxz} ]] && [[ ! -f ../${_imgxz} ]]; then
_msg2 "Downloading sources via torrent"	#	very fast!
aria2c -V --seed-time=0 ${_torrent}
mv ${_imgxz} ../${_imgxz}
else
_msg2 "found downloaded sources"
if [[ ! -f ../${_imgxz} ]]; then
mv ${_imgxz} ../${_imgxz}
fi
fi
}

build() {
#standard extraction utilities don't recognizes this archive for some reason.
[[ ! -f ../${_img} ]] &&  _msg2 "extracting with dtrx" &&  dtrx -no ../${_imgxz} && mv ${_img} ../${_img}
_msg2 "copying image.." #so we don't have to extract it every time
cp -b ../${_img} ${_imgfinal}
_msg2 "mounting image to loop device.."
sudo gnome-disk-image-mounter -w ${_imgfinal}
_msg2 "creating mount dir"
_mntdir="${srcdir}/mnt"
mkdir -p ${_mntdir}
_msg2 "mounting ${_root_partition} to mount point"
sudo mount ${_root_partition} ${_mntdir}
_msg2 "copy packages into apt cache"
sudo install -Dm644 ${srcdir}/${_skywiredeb} ${srcdir}/mnt/root/${_skywiredeb}
sudo install -Dm644 ${srcdir}/${_skybiandeb} ${srcdir}/mnt/root/${_skybiandeb}
_msg2 "copy qemu-aarch64-static command to chroot bin"
sudo cp "$(command -v qemu-aarch64-static)" "${srcdir}/mnt/usr/bin/"
################# chroot modifications for apt repo & package #################
#sudo is used for all commands to give correct environmental vars in chroot
_msg2 "CHROOT: installing skywire with dpkg"
sudo arch-chroot ${srcdir}/mnt sudo NOAUTOCONFIG=true dpkg -i /root/${_skywiredeb}
sudo rm ${srcdir}/mnt/root/${_skywiredeb}
_msg2 "CHROOT: installing packages in chroot with dpkg"
sudo arch-chroot ${srcdir}/mnt sudo INSTALLFIRSTBOOT=1 dpkg -i /root/${_skybiandeb}
sudo rm ${srcdir}/mnt/root/${_skybiandeb}
sudo arch-chroot ${_mntdir} sudo systemctl enable skywire-autoconfig
##set password for _defaultuser
_msg2 "CHROOT: setting password skybian for ${_defaultuser}"
echo ${_defaultuser}:skybian | sudo arch-chroot ${srcdir}/mnt sudo chpasswd
sleep 1
## included from chroot-commands.sh
_msg2 "CHROOT: Setting the chroot clock to now to avoid bugs with the date..."
sudo arch-chroot ${_mntdir} sudo /sbin/fake-hwclock save force
_msg2 "CHROOT: Generating locale en_US.UTF-8..."
sudo arch-chroot ${_mntdir} sudo locale-gen en_US.UTF-8
#set SKYBIAN=true
_msg2 "CHROOT: exporting SKYBIAN=true in /root/.bashrc"
echo 'export SKYBIAN=true' | sudo arch-chroot ${srcdir}/mnt tee -a /root/.bashrc
_msg2 "Unmounting image root partition"
sudo umount ${_mntdir}
######################## end chroot modifications ##############################
################# SKYRASPBIAN SPECIFIC BOOT CONFIG PARAMS ######################
_msg2 "creating mount dir for boot partition"
_mntdir="${srcdir}/boot"
mkdir -p ${_mntdir}
_msg2 "mounting ${_boot_partition} to mount point"
sudo mount ${_boot_partition} ${_mntdir}
_msg2 "Enabling UART"
sudo sed -i '/^#dtparam=spi=on.*/a enable_uart=1' "${_mntdir}/config.txt"
_msg2 "Enabling HDMI"
sudo sed -i 's/#hdmi_force_hotplug=1/hdmi_force_hotplug=1/' "${_mntdir}/config.txt"
_msg2 "Enabling SSH"
sudo touch "${_mntdir}/SSH.txt"
_msg2 "Unounting image boot partition"
sudo umount ${_mntdir}
########################## end boot param modifications  #######################
_msg2 "detatching /dev/loop0"
sudo losetup -d /dev/loop0
mv ${_imgfinal} ../${_imgfinal}
}

package() {
#Just let makepkg compress the archive as it does automatically for a package
#and then remove the metadata from the archive and change the extension
#avoid the compression step with makepkg --noarchive
#package only, assuming ${_imgfinal} exists with makepkg -R
install -Dm644 ${srcdir}/../${_imgfinal} ${pkgdir}/
cd ${pkgdir}
_msg2 "Creating image checksums"
sha256sum ${_imgfinal} > ${_imgfinal}.sha
cat ${_imgfinal}.sha
}

_msg2() {
(( QUIET )) && return
local mesg=$1; shift
printf "${BLUE}  ->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@"
}
