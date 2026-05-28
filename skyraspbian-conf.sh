#skyraspbian-conf.sh
# Shared logic for skyraspbian.rpi3.IMGBUILD (armhf) / rpi4.IMGBUILD (arm64).
# Per-arch IMGBUILDs set _imgarch and source this file.
pkgname=skyraspbian-${_imgarch}
pkgdesc="Skyraspbian ${_imgarch} image build"

#pkgver/pkgrel track the skywire-bin release in the apt repo
pkgver='1.3.59'
pkgrel=1

#skyrepo version (apt config + install-skywire service).
#1.3.56-4 is the first release with install-skywire.service Type=oneshot.
_skyrepover='1.3.56'
_skyreporel=4

arch=('any')
_hostarch=$(dpkg --print-architecture)

# Raspberry Pi OS Trixie (Debian 13). Pinned to a known good date for
# reproducibility; bump when refreshing the base image. The "lite" variant
# has no desktop. Note: trixie raspios no longer ships a default `pi` user;
# we create root credentials in the chroot for headless first boot.
_imgdate="2026-04-21"
_imgcodename="trixie"
_img="${_imgdate}-raspios-${_imgcodename}-${_imgarch}-lite.img"
_imgxz="${_img}.xz"
_xzlink="https://downloads.raspberrypi.org/raspios_lite_${_imgarch}/images/raspios_lite_${_imgarch}-${_imgdate}/${_imgxz}"
_torrent="${_xzlink}.torrent"
_imgfinal="${pkgname}-${pkgver}.img"
_root_partition=/dev/loop0p2
_boot_partition=/dev/loop0p1

_skywiredeb="skywire-bin_${pkgver}-${pkgrel}_${_imgarch}.deb"
_skyrepodeb="skyrepo_${_skyrepover}-${_skyreporel}_all.deb"
_skybiandeb="skybian-${_imgarch}.deb"
url="http://github.com/skycoin/skybian"
makedepends=('arch-install-scripts' 'aria2' 'dpkg' 'dtrx' 'gnome-disk-utility' 'qemu-user-static')
depends=()
_aptrepo="http://deb.skywire.skycoin.com/pool/main/s"
source=("${_torrent}"
"${_aptrepo}/skywire-bin/${_skywiredeb}"
"${_aptrepo}/skyrepo/${_skyrepodeb}"
"skyraspbian-conf.sh"
)
noextract=("${_skywiredeb}" "${_skyrepodeb}")

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
#standard extraction utilities don't recognize this archive for some reason.
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
sudo install -Dm644 ${srcdir}/${_skyrepodeb} ${srcdir}/mnt/root/${_skyrepodeb}
sudo install -Dm644 ${srcdir}/../${_skybiandeb} ${srcdir}/mnt/root/${_skybiandeb}
_msg2 "copy qemu static command to chroot bin"
if [[ ${_imgarch} == "armhf" ]] ; then
sudo cp "$(command -v qemu-arm-static)" "${srcdir}/mnt/usr/bin/"
else
sudo cp "$(command -v qemu-aarch64-static)" "${srcdir}/mnt/usr/bin/"
fi
################# chroot modifications for apt repo & package #################
_msg2 "CHROOT: installing skyrepo (apt config + install-skywire service)"
sudo arch-chroot ${_mntdir} sudo INSTALLFIRSTBOOT=1 dpkg -i /root/${_skyrepodeb}
sudo rm ${_mntdir}/root/${_skyrepodeb}
_msg2 "CHROOT: installing skywire-bin"
sudo arch-chroot ${_mntdir} sudo NOAUTOCONFIG=true dpkg -i /root/${_skywiredeb}
sudo rm ${_mntdir}/root/${_skywiredeb}
_msg2 "CHROOT: installing skybian (autoconfig: skymanager/srvpk/skylog)"
sudo arch-chroot ${_mntdir} sudo INSTALLFIRSTBOOT=1 dpkg -i /root/${_skybiandeb}
sudo rm ${_mntdir}/root/${_skybiandeb}
sudo arch-chroot ${_mntdir} sudo systemctl enable skywire-autoconfig 2>/dev/null || true
# Trixie raspios: no default `pi` user. Set root password for headless ssh.
# Operators can create user accounts after first login as needed.
_msg2 "CHROOT: setting root password to 'skybian'"
echo root:skybian | sudo arch-chroot ${_mntdir} sudo chpasswd
_msg2 "CHROOT: enabling root login over ssh"
sudo arch-chroot ${_mntdir} sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sleep 1
_msg2 "CHROOT: Setting the chroot clock to now to avoid bugs with the date..."
sudo arch-chroot ${_mntdir} sudo /sbin/fake-hwclock save force
_msg2 "CHROOT: Generating locale en_US.UTF-8..."
sudo arch-chroot ${_mntdir} sudo locale-gen en_US.UTF-8
_msg2 "CHROOT: exporting SKYBIAN=true in /root/.bashrc"
echo 'export SKYBIAN=true' | sudo arch-chroot ${_mntdir} tee -a /root/.bashrc
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
sudo touch "${_mntdir}/ssh"
_msg2 "Unmounting image boot partition"
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
