# Skybian Image

The Skybian image is a Debian-based ARM Operating System image with skywire pre-installed.

Currently, the following SBCs (Single Board Computer) are supported:

* Orange Pi Prime
* Orange Pi 3
* Raspberry Pi 32-bit and 64-bit

This repository has two types of builds:

The first is a [PKGBUILD](PKGBUILD) for the skybian.deb packaged modifications to the base image.

The second are [IMGBUILD](skybian.prime.IMGBUILD)s, which modify a base Armbian or Raspbian images by installing the skybian and skywire-bin packages, setting the password, etc.

Release images for can be found at [https://deb.skywire.skycoin.com/img/](https://deb.skywire.skycoin.com/img)

### Prerequisite

To build everything in this repo requires:

* archlinux host
* ~15gb of disk space

### Build Skybian image:

install dependencies from AUR:
```
yay -S 'arch-install-scripts' 'aria2' 'dpkg' 'dtrx' 'qemu-arm-static' 'zip'
```
Note: be sure to install the binary package `qemu-arm-static-bin` if you don't have `qemu-arm-static` installed already.

Build only without creating an archive:
```
makepkg --noarchive -p skybian.prime.IMGBUILD
```

Once the image is created, it can be compressed into the desired archive format:
```
PKGEXT='.img.tar.zst' makepkg -fRp skybian.prime.IMGBUILD
PKGEXT='.img.tar.xz' makepkg -fRp skybian.prime.IMGBUILD
PKGEXT='.img.tar.gz' makepkg -fRp skybian.prime.IMGBUILD
```

Update checksums on changes to source files:
```
updpkgsums skybian.prime.IMGBUILD
```

### Skybian .deb package:

The skybian amd64 package includes only the apt repo configuration and repository signing key.

The skybian armhf and arm64 packages additionally contain the modifications to the base image ; when installed in a chroot, the skybian package enables the automatic remote hypervisor configuration on the first boot of the skybian image to a hypervisor running on the xxx.xxx.xxx.2 ip address of the current subnet.

to build the skybian package, first install dpkg from the AUR:
```
yay -S dpkg
```

Build the skybian .deb package:
```
makepkg
```

On changes to source files in [script](script) or [static](static) dir ; re-create the source archive(s):
```
tar -czvf skybian-static.tar.gz static
tar -czvf skybian-script.tar.gz script
```

Update checksums of source archives in the [PKGBUILD](PKGBUILD):
```
updpkgsums
```

### Building Both

 An automated development workflow is made possible with the skybian-prime.sh and skybian.sh scripts, which build the image and package respectively. The version of the skybian and skywire packages *must match* the version referenced in the skybian.prime.IMGBUILD:
 ```
 ./skybian.sh
 SKYBIAN=skybian.prime.IMGBUILD ./image.sh
```

### Building Image Variants
orange pi prime
```
SKYBIAN=skybian.prime.IMGBUILD ./image.sh 1
./skybian-prime.sh 1
```
orange pi prime with autopeering
```
ENABLEAUTOPEER="-autopeer" SKYBIAN=skybian.prime.IMGBUILD ./image.sh 1
```

orange pi 3
```
SKYBIAN=skybian.opi3.IMGBUILD ./image.sh 1
 ```
raspberry pi 3
 ```
 SKYBIAN=skyraspbian.rpi3.IMGBUILD ./image.sh 1
 ```
raspberry pi 4
 ```
 SKYBIAN=skyraspbian.rpi4.IMGBUILD ./image.sh 1
 ```

### Skybian Auto-Peering Explained

The Skybian orange pi prime image, when booted, checks for any machine on the network at the xxx.xxx.xxx.2 ip address of the current subnet; i.e. 192.168.0.2 [skymanager.sh](/skymanager.sh).

#### _If nothing is on that ip address;_
* a static IP is set to that address via systemd-networkd in `/etc/systemd/network/10-eth.network`
* A hypervisor configuration is created by the skywire-autoconfig script.
* skywire.service is started
* srvpk.service is started ; which is an http endpoint runing on :7998 for querying the hypervisor's public key (`skywire-cli visor pk -w`)

#### _If a machine is on that ip address;_
* the skywire systemd service is started.
* the hypervisor running at the .2 ip address of the current subnet is queried for its public key
* the public key is not written to the config, but established at runtime
* upon loss of connection to the hypervisor, the srvpk endpoint is queried until a hypervisor responds with its public key or until the previous hypervisor connection is re-established

If no configuration file was generated, the process is attempted again on reboot.

### Using the Skybian image

Refer to the [Skybian User Guide](https://github.com/skycoin/skywire/wiki/Skybian-User-Guide) in the [skywire github wiki](https://github.com/skycoin/skywire/wiki).

### Troubleshooting

If for some reason the hypervisor is not accessible or the visor never shows up in the hypervisor, first try rebooting that board.

If the visor or hypervisor still does not show up online, ssh to the board or access it via keyboard and HDMI monitor.

For troubleshooting the skywire package, see [Skywire Package Installation](https://github.com/skycoin/skywire/wiki/Skywire-Package-Installation).

### APT repository

Skywire is now available as a package from the repository at [https://deb.skywire.skycoin.com](https://deb.skywire.skycoin.com).

This package repository will work with any .deb based arm / arm64 / amd64 system and is pre-configured in the provided Skybian and Skyraspbian images.

To configure this repository please refer to [Skywire Package Installation](https://github.com/skycoin/skywire/wiki/Skywire-Package-Installation).

### Additional notes

Images for testing can be found at [https://deb.skywire.dev/img/](https://deb.skywire.dev/img)

### Script and systemd service reference

#### Skybian
* [skymanager.sh](/script/skymanager.sh) (formerly skybian-firstrun)
    - produces static IP configuration (hypervisor)
    - sets hostname (hypervisor)
    - generates the appropriate config with skywire-autoconfig (local or remote hypervisor)
    - disables skymanager.service
* [skymanager.service](/script/skymanager.service)
    - runs on skybian first boot; wants network-online.target and the wait-online.services
* [srvpk.service](/util/srvpk.service)
    - wants skywire.service
	- runs `skywire-cli hv srvpk`
* [skybian-chrootconfig.sh](/script/skybian-chrootconfig.sh) (expected to run in chroot)
    - called by [postinst.sh](/script/postinst.sh) of the skybian.deb package upon installation
    - disables and enables required systemd services
    - removes any autogenerated skywire config
	- produces the drop-in configuration for skywire systemd service to enable autopeering
* /etc/systemd/system/skywire.service.conf.d/skywire.conf
	- `Environment=AUTOPEER=1`
* [skybian-reset.sh](/script/skybian-reset.sh)
    - resets skybian; except for the static ip configuration and hostname


#### Skywire
* skywire-autoconfig.sh
    - produces or updates a skywire configuration
    - determines the correct systemd service to enable and start by the presence of the config file
    - takes public key as argument to create a remote hypervisor configuration
* skywire.service
    - `skywire -p`

### ArchlinuxARM image

An archlinuxARM IMGBUILD for raspberry pis has been provided for advanced users. This image contains the unmodified archlinuxARM root filesystem. It is left to the user to install skywire or skywire-bin from the [AUR](aur.archlinux.org) after they have completed initial system configuration. It is recommended to use `yay` to install skywire-bin from the AUR. The same scripts are included with the AUR package of skywire as the debian package, and the installation paths are identical.
