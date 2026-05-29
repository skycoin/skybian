#skybian-conf.sh
# Shared logic for skybian.${board}.IMGBUILD variants (orangepiprime, orangepi3).
# The per-board IMGBUILDs set _board / _imgname and source this file.
pkgname=skybian-${_board}${ENABLEAUTOPEER}
pkgdesc="Skybian ${_board} image build"

#pkgver/pkgrel track the skywire-bin release in the apt repo
pkgver='1.3.59'
pkgrel=1

#skyrepo version. 1.3.59-1 absorbed the old skybian.deb role — ships
#skymanager / skybian-reset / motd snippets / skyenv defaults in addition
#to the apt config + install-skywire service.
_skyrepover='1.3.59'
_skyreporel=2

arch=('any')
_imgarch="arm64"
_hostarch="$(dpkg --print-architecture)"

# Armbian images for these boards are now community/rolling builds. The exact
# image filename embeds a build identifier that changes frequently, so we
# resolve it at build time from the .sha file instead of hardcoding it.
# These .sha / .torrent URLs are the stable indirection.
_armbianbranch="Trixie_current_minimal"
_imgsha="${_armbianbranch}.sha"
_imgshalink="https://dl.armbian.com/${_board}/${_imgsha}"
_torrent="https://dl.armbian.com/${_board}/${_armbianbranch}.torrent"

#deb names use standard dpkg underscore convention
_skywiredeb="skywire-bin_${pkgver}-${pkgrel}_${_imgarch}.deb"
_skyrepodeb="skyrepo_${_skyrepover}-${_skyreporel}_all.deb"

#canonical apt repo over plain HTTP — every published deb is at /pool/main/s/<pkg>/
_aptrepo="http://deb.skywire.skycoin.com/pool/main/s"

url="http://github.com/skycoin/skybian"
makedepends=('arch-install-scripts' 'aria2' 'dpkg' 'dtrx' 'gnome-disk-utility' 'qemu-user-static' 'qemu-user-static-binfmt')
source=("${_torrent}"
"${_imgshalink}"
"${_aptrepo}/skywire-bin/${_skywiredeb}"
"${_aptrepo}/skyrepo/${_skyrepodeb}"
"skybian-conf.sh"
)
noextract=("${_skywiredeb}" "${_skyrepodeb}")

# Resolved at build() time by reading ${_imgsha}. Keep _img/_imgxz/_imgfinal
# accessors as functions so prepare() can use the torrent before we've parsed
# the sha (aria2 reads the filename out of the torrent).
_parse_img_from_sha() {
	# .sha format: "<sha256hex>  <filename>" (filename may contain underscores/dots).
	# The filename already includes the .xz extension.
	awk '{print $2}' "${srcdir}/${_imgsha}" | head -n1
}

prepare() {
cd "${srcdir}"
# .sha is small and gives us the upstream filename; fetch first to know what
# the torrent will deliver.
if [[ ! -f ${_imgsha} ]]; then
	_msg2 "Downloading image .sha (${_imgsha})"
	aria2c --console-log-level=warn -o "${_imgsha}" "${_imgshalink}"
fi
_imgxz="$(_parse_img_from_sha)"
_img="${_imgxz%.xz}"
[[ -z "${_img}" ]] && _error "could not parse image filename from ${_imgsha}" && exit 1
_msg2 "Upstream image: ${_imgxz}"

if [[ ! -f ${_imgxz} ]] && [[ ! -f ../${_imgxz} ]]; then
_msg2 "Downloading image via torrent"	#	very fast!
aria2c -V --seed-time=0 "${_torrent}"
mv "${_imgxz}" "../${_imgxz}"
else
_msg2 "found previously downloaded image"
if [[ ! -f ../${_imgxz} ]]; then
mv "${_imgxz}" "../${_imgxz}"
fi
fi
}

build() {
_imgxz="$(_parse_img_from_sha)"
_img="${_imgxz%.xz}"
_imgfinal="${pkgname}-${pkgver}.img"
_root_partition=/dev/loop0p1

#standard extraction utilities don't recognize the armbian archive for some reason.
[[ ! -f ../${_img} ]] &&  _msg2 "extracting with dtrx" && dtrx ../${_imgxz} && mv ${_img} ../${_img}
_msg2 "checking image archive integrity"
_sum=$(sha256sum ../${_imgxz})
_msg2 "image sha256sum: ${_sum%%' '*}"
_check=$(cat ${_imgsha})
_msg2 "${_imgsha}: ${_check%%' '*}"
[[ "${_check%%' '*}" != "${_sum%%' '*}" ]] &&  _error "image integrity verification failed" && rm ${_imgsha} && exit 1
[[ "${_check%%' '*}" == "${_sum%%' '*}" ]] &&  _msg2 "image checksums verified"
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
sudo install -Dm644 ${srcdir}/${_skyrepodeb} ${srcdir}/mnt/root/${_skyrepodeb}
_msg2 "copying qemu-aarch64-static command to chroot bin"
sudo cp "$(command -v qemu-aarch64-static)" "${srcdir}/mnt/usr/bin/"
################## chroot modifications #################
#sudo is used for all commands to give correct environmental vars in chroot
_msg2 "disabling user creation on first login"
sudo rm -f  ${srcdir}/mnt/root/.not_logged_in_yet
_msg2 "CHROOT: setting password skybian for root"
echo root:skybian | sudo arch-chroot ${srcdir}/mnt sudo chpasswd
sleep 1
# Order: skyrepo first (apt config + install-skywire.service +
# skymanager + skybian-reset + motd snippets + skywire-chrootconfig
# which uses INSTALLFIRSTBOOT/CHROOTCONFIG to enable services), then
# skywire-bin (NOAUTOCONFIG=true so the postinst doesn't try to start
# the service from inside the qemu chroot).
if [[ ${ENABLEAUTOPEER} == "-autopeer" ]] ; then
	_msg2 "CHROOT: installing skyrepo (autopeer: enables skymanager)"
	sudo arch-chroot ${srcdir}/mnt sudo INSTALLFIRSTBOOT=1 CHROOTCONFIG=1 dpkg -i /root/${_skyrepodeb}
else
	_msg2 "CHROOT: installing skyrepo (no autopeer)"
	sudo arch-chroot ${srcdir}/mnt sudo INSTALLFIRSTBOOT=1 dpkg -i /root/${_skyrepodeb}
fi
sudo rm ${srcdir}/mnt/root/${_skyrepodeb}
_msg2 "CHROOT: installing skywire-bin"
sudo arch-chroot ${srcdir}/mnt sudo NOAUTOCONFIG=true dpkg -i /root/${_skywiredeb}
sudo rm ${srcdir}/mnt/root/${_skywiredeb}
_msg2 "CHROOT: Setting the chroot clock to now to avoid bugs with the date..."
sudo arch-chroot ${srcdir}/mnt sudo /sbin/fake-hwclock save force
_msg2 "CHROOT: Generating locale en_US.UTF-8..."
sudo arch-chroot ${srcdir}/mnt sudo locale-gen en_US.UTF-8
#fix console / tty
_msg2 "CHROOT: setting TERM=linux in /root/.bashrc"
echo 'TERM=linux' | sudo arch-chroot ${srcdir}/mnt tee -a /root/.bashrc
_msg2 "CHROOT: exporting SKYBIAN=true in /root/.bashrc"
echo 'export SKYBIAN=true' | sudo arch-chroot ${srcdir}/mnt tee -a /root/.bashrc
if [[ ${ENABLEAUTOPEER} == "-autopeer" ]] ; then
_msg2 "CHROOT: exporting AUTOPEER=1 in /root/.bashrc"
echo 'export AUTOPEER=1' | sudo arch-chroot ${srcdir}/mnt tee -a /root/.bashrc
fi
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
_imgfinal="${pkgname}-${pkgver}.img"
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
