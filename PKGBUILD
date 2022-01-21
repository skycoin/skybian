pkgname=skybian
_pkgname=skybian
pkgdesc="Packaged modifications to the skybian image - debian package"
pkgver='0.5.0'
_pkgver=${pkgver}
pkgrel=1
_pkgrel=${pkgrel}
arch=( 'any' )
_pkgarches=('armhf' 'arm64')
_pkgpath="github.com/skycoin/${_pkgname}"
url="https://${_pkgpath}"
makedepends=('dpkg')
depends=()
_debdeps="skywire-bin"
source=(
#original to skybian
"skybian-static.tar.gz"
#Below are scripts introduced by the maintainer
"skybian-script.tar.gz"
)
#tar -czvf skybian-static.tar.gz static
#tar -czvf skybian-script.tar.gz script
sha256sums=('ce826193c89c5c5f7bd72673503913df650f8e95a64a0d79b5f9e903c85c9b6b'
            'fb62153b9f21fb6174b81174cbb32a2ffd6bdc754b1993c1a118c79593f6930b')



build() {
  for i in ${_pkgarches[@]}; do
   msg2 "_pkgarch=$i"
   local _pkgarch=$i
   echo ${_pkgarch}
  #create control file for the debian package
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
  msg2 "_pkgarch=${i}"
  local _pkgarch=${i}
   echo ${_pkgarch}
  _msg2 'creating dirs'
  #set up to create a .deb package
  _debpkgdir="${_pkgname}-${pkgver}-${_pkgrel}-${_pkgarch}"
  _pkgdir="${pkgdir}/${_debpkgdir}"
  #########################################################################
  #PACKAGE AS YOU NORMALLY WOULD HERE USING ${_pkgdir} instead of ${pkgdir}
  mkdir -p ${_pkgdir}/etc/update-motd.d/
  mkdir -p ${_pkgdir}/etc/default/
  mkdir -p ${_pkgdir}/etc/profile.d/
  mkdir -p ${_pkgdir}/etc/systemd/system/
  mkdir -p ${_pkgdir}/usr/bin/
  install -Dm755 ${srcdir}/static/10-skybian-header ${_pkgdir}/etc/update-motd.d/
  install -Dm755 ${srcdir}/static/armbian-check-first-login.sh ${_pkgdir}/etc/profile.d/
  install -Dm644 ${srcdir}/static/armbian-motd ${_pkgdir}/etc/default/
  install -Dm755 ${srcdir}/script/skymanager.sh ${_pkgdir}/usr/bin/skymanager
  install -Dm755 ${srcdir}/script/skybian-patch-config.sh ${_pkgdir}/usr/bin/skybian-patch-config
  install -Dm644 ${srcdir}/script/skybian-patch-config.service ${_pkgdir}/etc/systemd/system/skybian-patch-config.service
  install -Dm755 ${srcdir}/script/skybian-chrootconfig.sh ${_pkgdir}/usr/bin/skybian-chrootconfig
  install -Dm755 ${srcdir}/script/skybian-chrootconfig.sh ${_pkgdir}/usr/bin/skybian-chrootconfig
  install -Dm755 ${srcdir}/script/skybian-reset.sh ${_pkgdir}/usr/bin/skybian-reset
  install -Dm644 ${srcdir}/script/skymanager.service ${_pkgdir}/etc/systemd/system/skymanager.service
  #########################################################################
  _msg2 'installing control file and postinst script'
  install -Dm755 ${srcdir}/${_pkgarch}.control ${_pkgdir}/DEBIAN/control
  install -Dm755 ${srcdir}/script/postinst.sh ${_pkgdir}/DEBIAN/postinst
  _msg2 'creating the debian package'
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
