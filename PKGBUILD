pkgname=skybian
_pkgname=skybian
pkgdesc="Packaged modifications to the skybian image, including scripts and utilities - debian package"
pkgver='1.0.0'
_pkgver=${pkgver}
pkgrel=4
_pkgrel=${pkgrel}
arch=( 'any' )
_pkgarches=('armhf' 'arm64' 'amd64')
_pkgpath="github.com/skycoin/${_pkgname}"
url="https://${_pkgpath}"
makedepends=('dpkg') # 'go' 'musl' 'kernel-headers-musl' 'aarch64-linux-musl' 'arm-linux-gnueabihf-musl')
depends=()
_debdeps=""
source=(
#original to skybian
"skybian-static.tar.gz"
#Below are scripts and utilities introduced by the maintainer
"skybian-script.tar.gz"
"skybian-util.tar.gz"
"skycoin.gpg"
)
#tar -czvf skybian-static.tar.gz static
#tar -czvf skybian-script.tar.gz script
#tar -czvf skybian-util.tar.gz util
sha256sums=('f372a652a01bf2dcbe7c7c8606cbeb9778441390698cc8c10d42262148c5fe4b'
            'e96120c8219eb12e77094702b9fa45dd8499309c9162cee03af074e2e5222186'
            '45828704c32db393d4d75f09c454c34ba1472893c31dd79c697bb25df2a2589d'
            'f2f964bb79541e51d5373204f4030dce6948d2d7862e345b55004b59b93d30e4')



build() {
  for i in ${_pkgarches[@]}; do
   msg2 "_pkgarch=$i"
   local _pkgarch=$i
   echo ${_pkgarch}

#   [[ $_pkgarch == "amd64" ]] && export GOARCH=amd64 && export CC=musl-gcc
#   [[ $_pkgarch == "arm64" ]] && export GOARCH=arm64 && export CC=aarch64-linux-musl-gcc
#   [[ $_pkgarch == "armhf" ]] && export GOARCH=arm && export GOARM=6 && export CC=arm-linux-gnueabihf-musl-gcc
#   #_ldflags=('-linkmode external -extldflags "-static" -buildid=')
#   #create the srvpk binaries
#   cd ${srcdir}/util
#   go build -trimpath --ldflags '-s -w -linkmode external -extldflags "-static" -buildid=' -o ${_pkgarch}.srvpk .


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
  mkdir -p ${_pkgdir}/etc/sources.list.d/
  mkdir -p ${_pkgdir}/etc/apt/trusted.gpg.d
  mkdir -p ${_pkgdir}/usr/bin/
  if [[ $_pkgarch != "amd64" ]]; then
	  _msg2 "Installing skybian modifications"
	  mkdir -p ${_pkgdir}/etc/update-motd.d/
	  mkdir -p ${_pkgdir}/etc/default/
	  mkdir -p ${_pkgdir}/etc/profile.d/
	  mkdir -p ${_pkgdir}/etc/systemd/system/
	  #install -Dm755 ${srcdir}/static/armbian-check-first-login.sh ${_pkgdir}/etc/profile.d/
	  install -Dm644 ${srcdir}/static/armbian-motd ${_pkgdir}/etc/default/
	  install -Dm755 ${srcdir}/static/10-skybian-header ${_pkgdir}/etc/update-motd.d/
	  _msg2 "Installing skybian scripts"
	  install -Dm755 ${srcdir}/script/skybian.sh ${_pkgdir}/etc/profile.d/skybian.sh
	  install -Dm755 ${srcdir}/script/skymanager.sh ${_pkgdir}/usr/bin/skymanager
	  install -Dm755 ${srcdir}/script/skybian-reset.sh ${_pkgdir}/usr/bin/skybian-reset
	  _msg2 "Installing utilities"
	  #install -Dm755 ${srcdir}/util/${_pkgarch}.srvpk ${_pkgdir}/usr/bin/srvpk
	  install -Dm755 ${srcdir}/util/bin/srvpk-${_pkgarch} ${_pkgdir}/usr/bin/srvpk
	  _msg2 "Installing systemd services"
	  install -Dm644 ${srcdir}/script/skymanager.service ${_pkgdir}/etc/systemd/system/skymanager.service
	  install -Dm644 ${srcdir}/util/srvpk.service ${_pkgdir}/etc/systemd/system/srvpk.service
  fi
  _msg2 "Installing skybian-chrootconfig"
  install -Dm755 ${srcdir}/script/skybian-chrootconfig.sh ${_pkgdir}/usr/bin/skybian-chrootconfig
  _msg2 "Installing apt repository configuration: /etc/apt/sources.list.d/skycoin.list"
  install -Dm644 ${srcdir}/script/skycoin.list ${_pkgdir}/etc/apt/sources.list.d/skycoin.list
  _msg2 "Installing apt repository configuration: /etc/apt/trusted.gpg.d/skycoin.gpg"
  install -Dm644 ${srcdir}/skycoin.gpg ${_pkgdir}/etc/apt/trusted.gpg.d/skycoin.gpg
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
