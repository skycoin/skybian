pkgname=skybian
_pkgname=skybian
pkgdesc="Packaged modifications to the skybian image - debian package"
pkgver='1.0.0'
_pkgver=${pkgver}
pkgrel=4
_pkgrel=${pkgrel}
arch=( 'any' )
_pkgarches=('armhf' 'arm64')
_pkgpath="github.com/skycoin/${_pkgname}"
url="https://${_pkgpath}"
makedepends=('dpkg')
depends=()
_debdeps=""
source=(
#original to skybian
"skybian-static.tar.gz"
#Below are scripts introduced by the maintainer
"skybian-script.tar.gz"
)
#tar -czvf skybian-static.tar.gz static
#tar -czvf skybian-script.tar.gz script
sha256sums=('f372a652a01bf2dcbe7c7c8606cbeb9778441390698cc8c10d42262148c5fe4b'
            '45935ff1f129f3452b875890781d3d0efe621ad0da09603b8778c9186a9cd862')



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
  _msg2 "_pkgarch=${i}"
  local _pkgarch=${i}
   echo ${_pkgarch}
  _msg2 'creating dirs'
  #set up to create a .deb package
  _debpkgdir="${_pkgname}-${pkgver}-${_pkgrel}-${_pkgarch}"
  _pkgdir="${pkgdir}/${_debpkgdir}"
  #########################################################################
  #PACKAGE AS YOU NORMALLY WOULD HERE USING ${_pkgdir} instead of ${pkgdir}
  _msg2 "Creating dirs"
  mkdir -p ${_pkgdir}/etc/update-motd.d/
  mkdir -p ${_pkgdir}/etc/default/
  mkdir -p ${_pkgdir}/etc/profile.d/
  mkdir -p ${_pkgdir}/etc/sources.list.d/
  mkdir -p ${_pkgdir}/etc/systemd/system/
  mkdir -p ${_pkgdir}/usr/bin/
  #install -Dm755 ${srcdir}/static/armbian-check-first-login.sh ${_pkgdir}/etc/profile.d/
  install -Dm644 ${srcdir}/static/armbian-motd ${_pkgdir}/etc/default/
  install -Dm755 ${srcdir}/static/10-skybian-header ${_pkgdir}/etc/update-motd.d/
  _msg2 "Installing apt repository configuration: /etc/apt/sources.list.d/skycoin.list"
  install -Dm644 ${srcdir}/script/skycoin.list ${_pkgdir}/etc/apt/sources.list.d/skycoin.list
  _msg2 "Installing scripts"
  install -Dm755 ${srcdir}/script/skymanager.sh ${_pkgdir}/usr/bin/skymanager
  install -Dm755 ${srcdir}/script/install-skywire.sh ${_pkgdir}/usr/bin/install-skywire
  install -Dm755 ${srcdir}/script/skybian.sh ${_pkgdir}/etc/profile.d/skybian.sh
  install -Dm755 ${srcdir}/script/skybian-chrootconfig.sh ${_pkgdir}/usr/bin/skybian-chrootconfig
  install -Dm755 ${srcdir}/script/skybian-reset.sh ${_pkgdir}/usr/bin/skybian-reset
  _msg2 "Installing systemd services"
  install -Dm644 ${srcdir}/script/skymanager.service ${_pkgdir}/etc/systemd/system/skymanager.service
  install -Dm644 ${srcdir}/script/install-skywire.service ${_pkgdir}/etc/systemd/system/install-skywire.service
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
