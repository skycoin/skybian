pkgname=skybian
_pkgname=skybian
pkgdesc="Skybian autoconfig: skymanager for skyminer first-boot - debian package"
# Tracks skywire-bin pkgver so they ship together. skybian.deb itself contains
# only the skymanager autoconfig script + service; apt-repo configuration
# and the install-skywire service live in the skyrepo deb (apt-repo/PKGBUILD).
# srvpk and skylog were retired in 1.3.59 — pubkey discovery now uses the
# hypervisor's unauthenticated /api/pk endpoint on port 8000.
pkgver='1.3.59'
_pkgver=${pkgver}
pkgrel=1
_pkgrel=${pkgrel}
arch=( 'any' )
# Only the architectures we actually image: arm64 (OPi Prime/3, RPi4) and
# armhf (RPi3). amd64/armel variants used to ship only apt-repo bits — those
# now live in skyrepo, so we no longer build those variants here.
_pkgarches=('arm64' 'armhf')
_pkgpath="github.com/skycoin/${_pkgname}"
url="https://${_pkgpath}"
makedepends=('dpkg')
depends=()
# skyrepo: apt config, signing key, install-skywire.service, skywire-chrootconfig.
# skywire-bin: the actual skywire binary + systemd unit our autoconfig drives.
_debdeps="skyrepo (>= 1.3.56-4), skywire-bin (>= 1.3.59)"
source=("skybian-static.tar.gz"
		"skybian-script.tar.gz")
sha256sums=('SKIP'
            'SKIP')

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
  _debpkgdir="${_pkgname}-${pkgver}-${_pkgrel}-${_pkgarch}"
  _pkgdir="${pkgdir}/${_debpkgdir}"
  #########################################################################
  _msg2 "Creating dirs"
  mkdir -p ${_pkgdir}/usr/bin/
  mkdir -p ${_pkgdir}/etc/update-motd.d/
  mkdir -p ${_pkgdir}/etc/default/
  mkdir -p ${_pkgdir}/etc/systemd/system/

  _msg2 "Installing motd"
  install -Dm644 ${srcdir}/static/armbian-motd ${_pkgdir}/etc/default/armbian-motd
  install -Dm755 ${srcdir}/static/10-skybian-header ${_pkgdir}/etc/update-motd.d/10-skybian-header

  _msg2 "Installing autoconfig scripts"
  install -Dm755 ${srcdir}/script/skymanager.sh ${_pkgdir}/usr/bin/skymanager
  install -Dm755 ${srcdir}/script/skybian-reset.sh ${_pkgdir}/usr/bin/skybian-reset

  _msg2 "Installing autoconfig systemd service"
  install -Dm644 ${srcdir}/script/skymanager.service ${_pkgdir}/etc/systemd/system/skymanager.service

  _msg2 "Installing skybian-chrootconfig (env setup; called by postinst)"
  install -Dm755 ${srcdir}/script/skybian-chrootconfig.sh ${_pkgdir}/usr/bin/skybian-chrootconfig

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
