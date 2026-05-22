#skybian-conf.sh
pkgname=skybian-${_board}${ENABLEAUTOPEER}
pkgdesc="Skybian ${_board} image build"
_img="Armbian_22.08.2_${_imgname}_bullseye_current_5.15.69.img"
_imgxz="${_img}.xz"
_imgsha="Bullseye_current.sha"
_imgshalink="https://redirect.armbian.com/${_board}/${_imgsha}"
_xzlink="https://www.armbian.com/dl/${_board}/archive/${_imgxz}"
#pkgver & pkgrel match the version & release of the skywire .deb in the apt repo
pkgver='1.2.1'
pkgrel=1
arch=('any')
_imgarch="arm64"
_hostarch="$(dpkg --print-architecture)"
_torrent="${_xzlink}.torrent"
_imgfinal="${pkgname}-${pkgver}.img"
_root_partition=/dev/loop0p1
_defaultuser=root
_skywiredeb="skywire-bin-${pkgver}-${pkgrel}-${_imgarch}.deb"
_skybiandeb="skybian-${_imgarch}.deb"
url="http://github.com/skycoin/skybian"
makedepends=('arch-install-scripts' 'aria2' 'dpkg' 'dtrx' 'gnome-disk-utility' 'qemu-user-static' 'qemu-user-static-binfmt')
_aptrepo="https://github.com/skycoin/apt-repo/releases/download"
source=("${_torrent}"
"${_torrent}.md5"
"${_imgshalink}"
"${_aptrepo}/archive/${_skywiredeb}"
"${_aptrepo}/current/${_skybiandeb}"
"skybian-conf.sh"
)
#"https://fl.us.mirror.archlinuxarm.org/aarch64/extra/gnu-netcat-0.7.1-8-aarch64.pkg.tar.xz"
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
#standard extraction utilities don't recognizes the armbian archive for some reason.
[[ ! -f ../${_img} ]] &&  _msg2 "extracting with dtrx" && dtrx ../${_imgxz} && mv ${_img} ../${_img}
_msg2 "checking image archive integrity"
_sum=$(sha256sum ../${_imgxz})
_msg2 "image sha256sum: ${_sum%%' '*}"
_check=$(cat ${_imgsha})
_msg2 "${_imgsha}: ${_check%%' '*}"
[[ "${_check%%' '*}" != "${_sum%%' '*}" ]] &&  _error "image integrity verification failed" && rm ${_imgsha} && exit 1
[[ "${_check%%' '*}" == "${_sum%%' '*}" ]] &&  _msg2 "image checksums verified" && rm ${_imgsha}
_msg2 "copying image.." #so we don't have to extract it every time
cp -b ../${_img} ${_imgfinal}
_msg2 "adding extra space" #may or may not be necessary
truncate -s +512M ${_imgfinal}
echo ", +" | sfdisk -N1 ${_imgfinal}
_msg2 "creating mount dir"
sudo umount -l ${srcdir}/mnt && _msg2 "unmounted lingering mounted dir" || true
rm -rf ${srcdir}/mnt
sudo losetup -d /dev/loop0 && _msg2 "detatched loop device after previous unclean exit" || true
mkdir -p ${srcdir}/mnt
_msg2 "mounting image to loop device.."
sudo gnome-disk-image-mounter -w ${_imgfinal}
_msg2 "mounting ${_root_partition} to mount point"
sudo mount ${_root_partition} ${srcdir}/mnt
_msg2 "copying packages into image"
sudo install -Dm644 ${srcdir}/${_skywiredeb} ${srcdir}/mnt/root/${_skywiredeb}
sudo install -Dm644 ${srcdir}/${_skybiandeb} ${srcdir}/mnt/root/${_skybiandeb}
#_msg2 "installing newer version of netcat binary to the image"
#sudo install -Dm755 ${srcdir}/usr/bin/netcat ${srcdir}/mnt/usr/bin/
#sudo install -Dm755 ${srcdir}/usr/bin/nc ${srcdir}/mnt/usr/bin/
_msg2 "copying qemu-aarch64-static command to chroot bin"
sudo cp "$(command -v qemu-aarch64-static)" "${srcdir}/mnt/usr/bin/"
################## chroot modifications for apt repo & package #################
#sudo is used for all commands to give correct environmental vars in chroot
_msg2 "disabling user creation on first login"
sudo rm -f  ${srcdir}/mnt/root/.not_logged_in_yet
##set password for _defaultuser
_msg2 "CHROOT: setting password skybian for ${_defaultuser}"
echo ${_defaultuser}:skybian | sudo arch-chroot ${srcdir}/mnt sudo chpasswd
sleep 1
_msg2 "CHROOT: installing skywire with dpkg"
sudo arch-chroot ${srcdir}/mnt sudo NOAUTOCONFIG=true dpkg -i /root/${_skywiredeb}
sudo rm ${srcdir}/mnt/root/${_skywiredeb}
_msg2 "CHROOT: installing packages in chroot with dpkg"
if [[ ${ENABLEAUTOPEER} == "-autopeer" ]] ; then
sudo arch-chroot ${srcdir}/mnt sudo  INSTALLFIRSTBOOT=1 CHROOTCONFIG=true dpkg -i /root/${_skybiandeb}
else
sudo arch-chroot ${srcdir}/mnt sudo  INSTALLFIRSTBOOT=1 dpkg -i /root/${_skybiandeb}
fi
sudo rm ${srcdir}/mnt/root/${_skybiandeb}
## included from chroot-commands.sh
_msg2 "CHROOT: Setting the chroot clock to now to avoid bugs with the date..."
sudo arch-chroot ${srcdir}/mnt sudo /sbin/fake-hwclock save force
_msg2 "CHROOT: Generating locale en_US.UTF-8..."
sudo arch-chroot ${srcdir}/mnt sudo locale-gen en_US.UTF-8
#fix console / tty
_msg2 "CHROOT: setting TERM=linux in /root/.bashrc"
echo 'TERM=linux' | sudo arch-chroot ${srcdir}/mnt tee -a /root/.bashrc
#set SKYBIAN=true
_msg2 "CHROOT: exporting SKYBIAN=true in /root/.bashrc"
echo 'export SKYBIAN=true' | sudo arch-chroot ${srcdir}/mnt tee -a /root/.bashrc
if [[ ${ENABLEAUTOPEER} == "-autopeer" ]] ; then
_msg2 "CHROOT: exporting AUTOPEER=1 in /root/.bashrc"
echo 'export AUTOPEER=1' | sudo arch-chroot ${srcdir}/mnt tee -a /root/.bashrc
fi
_msg2 "CHROOT: configuring unattended-upgrades"
echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | sudo arch-chroot ${srcdir}/mnt sudo debconf-set-selections
sudo arch-chroot ${srcdir}/mnt sudo dpkg-reconfigure -f noninteractive unattended-upgrades
######################## end chroot modifications ##############################
[[ -d ${srcdir}/mnt/lost+found ]] && sudo rm -rf ${srcdir}/mnt/lost+found
_msg2 "Unmounting image"
sudo umount ${srcdir}/mnt
_msg2 "detatching /dev/loop0"
sudo losetup -d /dev/loop0
mv ${_imgfinal} ../${_imgfinal}
cd ..
echo "created image(s):"
ls $_imgfinal
}

package() {
#let makepkg compress the archive as it does automatically for any package
#afterwards remove the metadata from the archive and change the extension
#avoid the compression step with makepkg --noarchive
#package only, assuming ${_imgfinal} exists with makepkg -R
install -Dm644 ${srcdir}/../${_imgfinal} ${pkgdir}/
cd ${pkgdir}
_msg2 "Creating image checksum"
sha256sum ${_imgfinal} > ${_imgfinal}.sha
cat ${_imgfinal}.sha
}

_msg2() {
(( QUIET )) && return
local mesg=$1; shift
printf "${BLUE}  ->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@"
}

_error() {
local mesg=$1; shift
printf "${RED}==> $(gettext "ERROR:")${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}
