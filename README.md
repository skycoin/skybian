Builds require:
* archlinux host
* ~15gb of disk space

### Build Skybian image:

install dependencies from AUR:
```
yay -S 'arch-install-scripts' 'aria2' 'dpkg' 'dtrx' 'gnome-disk-utility' 'qemu-arm-static' 'zip'
```
Note: be sure to install the binary package qemu-arm-static-bin if you don't have qemu-arm-static installed already

Build the image and compress into archive:
```
 makepkg -p skybian.IMGBUILD
```
Build only without creating .zst archive (still creates .zip):
```
 makepkg --noarchive -p skybian.IMGBUILD
```

The image, when created, can be found in the pkg dir

The image archives will populate at the top level

Update checksums on changes to source files:

```
updpkgsums skybian.IMGBUILD
```

### Skybian package:

The skybian package contains the modifications to the base image

The skybian package, when installed in a chroot, enables the automatic remote hypervisor configuration on the first boot of the skybian image to a hypervisor running on the xxx.xxx.xxx.2 ip address of the current subnet.

to build the skybian package, first install dependencies from AUR:
```
yay -S dpkg
```

Build:
```
makepkg
```

On changes to source files in `script` or `static` dir; re-create the source archive(s):
```
tar -czvf skybian-static.tar.gz static
tar -czvf skybian-script.tar.gz script
```

Update checksums of source archives in the [PKGBUILD](PKGBUILD):
```
updpkgsums
```

### Building Both

 An automated development workflow is made possible with the skybian-img.sh and skybian.sh scripts, which build the image and package respectively. The version of the skybian package *must match* the version referenced in the skybian.IMGBUILD
 ```
./skybian.sh && ./skybian-img.sh 1
 ```

### Skybian Autoconfiguration Explained

The image achieves autoconfiguration by checking for any machine on the network at the .2 ip address of the current subnet (skymanager.sh).

If nothing is on that ip address, a static IP is set to that address (via systemd-networkd), a hypervisor configuration is created (skywire-autoconfig), and skywire.service is started via systemd

If a machine is on that ip address, the rpc server of the visor running at the .2 ip address of the current subnet is queried for its public key

The public key is then used to create a visor config with that public key as the remote hypervisor (skywire-autoconfig-remote) and the skywie-visor systemd service is started.

### Using the Skybian image

Refer to the [Skybian User Guide](https://github.com/skycoin/skywire/wiki/Skybian-User-Guide) in the [skywire github wiki](https://github.com/skycoin/skywire/wiki)

### Troubleshooting

If for some reason the hypervisor is not accessible or the visor never shows up in the hypervisor, first try rebooting that board

If the visor or hypervisor still does not show up online, ssh to the board or access it via keyboard and HDMI monitor

For troubleshooting the skywire package, see [Skywire Package Installation](https://github.com/skycoin/skywire/wiki/Skywire-Package-Installation)

### APT repository

Skywire is now available as a package from the repository at [https://deb.skywire.skycoin.com](https://deb.skywire.skycoin.com)

This package repository will work with any .deb based arm / arm64 / amd64 system and is pre-configured in the provided Skybian and Skyraspbian images.

To configure this repository please refer to [Skywire Package Installation](https://github.com/skycoin/skywire/wiki/Skywire-Package-Installation)

### Additional notes

Images for testing can be found at [https://deb.skywire.skycoin.com/img/](https://deb.skywire.skycoin.com/img)

### Script and systemd service reference

#### Skybian
* [skymanager.sh](/script/skymanager.sh) (formerly skybian-firstrun)
    - produces static IP configuration (hypervisor)
    - sets hostname (hypervisor)
    - enables either skywire-autoconfig or skywire-autoconfig-remote
    - disables skymanager.service
    - reboots the board
* [skymanager.service](/script/skymanager.service)
    - runs on skybian's first boot; wants network-online.target
* [skybian-chrootconfig.sh](/script/skybian-chrootconfig.sh) (expected to run in chroot)
    - called by [postinst.sh](/script/postinst.sh) of the skybian.deb package upon installation
    - disables and enables required systemd services
    - removes any autogenerated skywire config
* [skybian-reset.sh](/script/skybian-reset.sh)
    - resets skybian; except for the static ip configuration - for testing purposes only


#### Skywire
* skywire-autoconfig.sh
    - produces or updates a skywire configuration
    - determines the correct systemd service to enable and start by the presence of the config file
    - can take public key as argument to create a visor configuration using that public key as hypervisor
* skywire-autoconfig.service
    - enabled by skymanager.service
    - systemd service to produce skywire (hypervisor) config & start skywire on boot
* skywire-autoconfig-remote.sh
    - queries any node running at the .2 ip address of the current subnet for its public key
    - calls `skywire-autoconfig <pk>` to set the remote hypervisor to that public key
    - disables skywire-autoconfig-remote.service
* skywire-autoconfig-remote.service
    - enabled by skymanager.service
    - runs after the initial reboot to set up remote hypervisor
* skywire.service
    - `skywire -c /opt/sykywire/skywire.json`
* skywire-visor.service
    - `skywire -c /opt/skywire/skywire-visor.json`


### ArchlinuxARM image

An archlinuxARM image compatable with raspberry pis has been provided for advanced users. This image contains the unmodified archlinuxARM root filesystem. It is left to the user to install skywire or skywire-bin from the [AUR](aur.archlinux.org) after they have completed initial system configuration. It is recommended to use `yay` to install skywire-bin from the AUR. The same scripts are included with the AUR package of skywire as the debian package and the installation paths are identical.
