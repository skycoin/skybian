pkgname=skybian
_pkgname=skybian
pkgdesc="Packaged modifications to the skybian image, including repo configuration - debian package"
pkgver='1.1.0'
_pkgver=${pkgver}
pkgrel=1
_pkgrel=${pkgrel}
arch=( 'any' )
_pkgarches=('amd64' 'arm64' 'armhf' 'armel')
_pkgpath="github.com/skycoin/${_pkgname}"
url="https://${_pkgpath}"
makedepends=('dpkg')
depends=()
_debdeps=""
source=("skybian-static.tar.gz"
		"skybian-script.tar.gz")
sha256sums=('3111f03858e7aa857b938e6b7902fcf615bcb80e8167eeac0f58212fc9fa48c9'
            'c6e11e08d051a3ef5d754c9e340fc2dd6e028597efc32ca6fbfe5e70a796a56c')

build() {
  for i in ${_pkgarches[@]}; do
   _msg2 "_pkgarch=$i"
   local _pkgarch=$i
   _msg2 "Creating DEBIAN/control file for ${_pkgarch}"
  echo "Package: ${_pkgname}" > ${srcdir}/${_pkgarch}.control
  echo "Version: ${_pkgver}-${_pkgrel}" >> ${srcdir}/${_pkgarch}.control
  echo "Priority: optional" >> ${srcdir}/${_pkgarch}.control
  echo "Section: web" >> ${srcdir}/${_pkgarch}.control
  echo "Architecture: ${_pkgarch}" >> ${srcdir}/${_pkgarch}.control
  echo "Depends: ${_debdeps}" >> ${srcdir}/${_pkgarch}.control
  echo "Maintainer: Skycoin" >> ${srcdir}/${_pkgarch}.control
  echo "Description: ${pkgdesc}" >> ${srcdir}/${_pkgarch}.control
  cat ${srcdir}/${_pkgarch}.control
done
}

package() {
  for i in ${_pkgarches[@]}; do
  _msg2 "_pkgarch=${i}"
  local _pkgarch=${i}
   echo ${_pkgarch}
  #set up to create a .deb package with dpkg
  _debpkgdir="${_pkgname}-${pkgver}-${_pkgrel}-${_pkgarch}"
  _pkgdir="${pkgdir}/${_debpkgdir}"
  #########################################################################
  #package normally here using ${_pkgdir} instead of ${pkgdir}
  _msg2 "Creating dirs"
  mkdir -p ${_pkgdir}/etc/apt/sources.list.d/
  mkdir -p ${_pkgdir}/etc/apt/trusted.gpg.d
  mkdir -p ${_pkgdir}/usr/bin/
  if [[ $_pkgarch != "amd64" ]]; then
	  _msg2 "Installing skybian modifications"
	  mkdir -p ${_pkgdir}/etc/update-motd.d/
	  mkdir -p ${_pkgdir}/etc/default/
	  mkdir -p ${_pkgdir}/etc/profile.d/
	  mkdir -p ${_pkgdir}/etc/systemd/system/
	  install -Dm644 ${srcdir}/static/armbian-motd ${_pkgdir}/etc/default/
	  install -Dm755 ${srcdir}/static/10-skybian-header ${_pkgdir}/etc/update-motd.d/
	  _msg2 "Installing skybian scripts"
#	  install -Dm755 ${srcdir}/script/skyenv.sh ${_pkgdir}/etc/profile.d/skyenv.sh
	  install -Dm755 ${srcdir}/script/skymanager.sh ${_pkgdir}/usr/bin/skymanager
	  install -Dm755 ${srcdir}/script/skybian-reset.sh ${_pkgdir}/usr/bin/skybian-reset
	  install -Dm755 ${srcdir}/script/install-skywire.sh ${_pkgdir}/usr/bin/install-skywire
	  _msg2 "Installing systemd services"
	  install -Dm644 ${srcdir}/script/skymanager.service ${_pkgdir}/etc/systemd/system/skymanager.service
	  install -Dm644 ${srcdir}/script/srvpk.service ${_pkgdir}/etc/systemd/system/srvpk.service
	  install -Dm644 ${srcdir}/script/install-skywire.service ${_pkgdir}/etc/systemd/system/install-skywire.service
  fi
  _msg2 "Installing skybian-chrootconfig" #called by postinstall
  install -Dm755 ${srcdir}/script/skybian-chrootconfig.sh ${_pkgdir}/usr/bin/skybian-chrootconfig
  _msg2 "Installing apt repository configuration to:\n    /etc/apt/sources.list.d/skycoin.list"
  install -Dm644 ${srcdir}/script/skycoin.list ${_pkgdir}/etc/apt/sources.list.d/skycoin.list
  #export TESTDEPLOYMENT=1
  if [[ "${TESTDEPLOYMENT}" == "1" ]] ; then
	  _msg2 "substituiting test repository http://deb.skywire.dev" #called by postinstall
	  echo "deb http://deb.skywire.dev  sid main
# deb-src http://deb.skywire.dev sid main" | tee ${_pkgdir}/etc/apt/sources.list.d/skycoin.list
  fi
  _msg2 "Installing apt repository signing key to:\n    /etc/apt/trusted.gpg.d/skycoin.gpg"
  install -Dm644 ${srcdir}/script/skycoin.gpg ${_pkgdir}/etc/apt/trusted.gpg.d/skycoin.gpg
  #########################################################################
  _msg2 'Installing control file and postinst script'
  install -Dm755 ${srcdir}/${_pkgarch}.control ${_pkgdir}/DEBIAN/control
  install -Dm755 ${srcdir}/script/postinst.sh ${_pkgdir}/DEBIAN/postinst
  _msg2 'Creating the debian package'
  cd $pkgdir
  dpkg-deb --build -z9 ${_debpkgdir}
  mv *.deb ../../
  done
  #exit so the arch package doesn't get built
  exit
}

_msg2() {
	(( QUIET )) && return
	local mesg=$1; shift
	printf "${BLUE}  ->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@"
}
