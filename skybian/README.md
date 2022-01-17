Builds requires archlinux host.

### Skybian image:

install dependencies from AUR:
```
yay -S gnome-disk-utility qemu-arm-static aria2 file-roller pacman-contrib
```

Note: be sure to install qemu-arm-static-bin if you don't have qemu-arm-static installed already

Build and create an archive:
```
 makepkg --skippgpcheck -p skybian.IMGBUILD
```

Note: the archive type that is created is specified in /etc/makepkg.conf

Build only:
```
 makepkg --noarchive --skippgpcheck -p skybian.IMGBUILD
```

The image, when created, can be found in the pkg dir

Update checksums on changes to source files:

```
updpkgsums skybian.IMGBUILD
```

### Skybian package:

install dependencies from AUR:
```
yay -S dpkg
```

Build:
```
makepkg
```

Update checksums on changes to source files:
```
updpkgsums
```


### Skybian Autoconfiguration Explained

The image achieves autoconfiguration by checking for any machine on the network at the .2 ip address of the current subnet.

If nothing is on that ip address, a static IP is set to that address (via systemd-networkd), a hypervisor configuration is created (skywire-autoconfig), and skywire.service is started via systemd

If a machine is on that ip address, the rpc server of the visor running at the .2 ip address of the current subnet is queried for its public key

The public key is then used to create a visor config with that public key as the remote hypervisor (skywire-autoconfig-remote).

### Using the Skybian image

* [Download the image](https://deb.skywire.skycoin.com/img/) and extract it from the archive
    - [Windows zst extraction utility](https://peazip.github.io/peazip-64bit.html)
    - [MacOS zst extraction utility](https://peazip.github.io/peazip-macos.html)
    - [linux:](https://man.archlinux.org/man/tar.1) `tar -xf /path/to/archive.tar.zst`

* Use balena etcher, or the dd / dcfldd command on linux, to write the image to a microSD card
    - [downlad balena etcher](https://www.balena.io/etcher/)
    - [dd command](https://wiki.archlinux.org/title/Dd)

* Power off every board in the skyminer with the individual switches

* Insert the card into the board which you designate as hypervisor, and power on that board. The board will reboot once during this process.

* Wait until the hypervisor interface appears at the ip address of the skyminer, port :8000.

* repeat step 2 with the next microSD card, insert it in the next pi, and power on the board

* wait until the visor appears in the hypervisor user interface. The board will reboot once during this process

* Repeat steps 6 and 7 for every node in the skyminer

If you prefer instead to use a different computer as the hypervisor of your cluster, the easiest way is to connect that machine to the skyminer router and assign it the .2 ip address. Make sure your hypervisor is running and the RPC server is enabled in your configuration file (delete localhost but leave the port :3435)

### Troubleshooting the image and skywire installation

If for some reason the hypervisor is not accessible or the visor never shows up in the hypervisor, first try rebooting that board

If the visor or hypervisor still does not show up online, ssh to the board or access it via keyboard and HDMI monitor

run `skywire-autoconfig` to fix almost any issue with configuration and yield a running instance of skywire

If skywire-autoconfig does not work, you may need to uninstall and reinstall skywire

```
apt remove skywire-bin
apt update
apt install skywire-bin
```

To explicitly configure a visor to the hypervisor running at the .2 ip address on the network (the rpc server of the hypervisor must accept queries from the LAN)

```
skywire-autoconfig-remote
```

To set a remote htpervisor via public key, supply the public key as an argument to skywire-autoconfig

```
skywire-autoconfig <pk>
```

To restore keys from a previous installation:

* place the configuration file at `/etc/skywire-config.json`
* `rm /opt/skywire/skywire.json`
* `skywire-autoconfig`

any remote hypervisor(s) set in the config file will not be retained.

### APT repository

Skywire is now available as a package from the repository at [https://deb.skywire.skycoin.com](https://deb.skywire.skycoin.com)

This package repository will work with any .deb based arm / arm64 / amd64 system.

To install skywire from this repository
(run all commands as root or use sudo)

Add the repository to your apt sources
```
add-apt-repository 'deb https://deb.skywire.skycoin.com sid main'
```

 or manually edit `/etc/apt/sources.list`:
```
nano /etc/apt/sources.list
```

Add the following:
```
deb http://deb.skywire.skycoin.com sid main
#deb-src https://deb.skywire.skycoin.com sid main
```

Add the repository signing key:
as root:
```
curl -L https://deb.skywire.skycoin.com/KEY.asc | apt-key add -
```
with sudo this would be:
```
curl -L https://deb.skywire.skycoin.com/KEY.asc | sudo apt-key add -
```

If you have difficulty with configuring this repository, you may attempt [manually downloading](https://deb.skywire.skycoin.com/archive) and installing the package with `dpkg -i`

Resync the package database:
```
apt update
```
Install skywire:
```
apt install skywire-bin
```

Skywire will be started automatically after installation. Access the hypervisor to be sure it's working.

### Additional notes

**the skybian package**, when updated, will enable the skymanager systemd service and the skywire-autoconfig service and disable the skywire service.
This will result in erroneous behavior of the skyminer, so this package is not included in the APT repo, but instead kept in the archive at
[https://deb.skywire.skycoin.com/archive](https://deb.skywire.skycoin.com/archive)


Images for testing can be found at [https://deb.skywire.skycoin.com/img/](https://deb.skywire.skycoin.com/img)


### Script and systemd service reference

#### Skybian
* skymanager.sh (formerly skybian-firstrun)
    - produces static IP configuration (hypervisor)
    - sets hostname (hypervisor)
    - enables either skywire-autoconfig or skywire-autoconfig-remote
    - disables skymanager.service
    - reboots the board
* skymanager.service
    - runs on skybian's first boot; wants network-online.target
* skybian-chrootconfig.sh (expected to run in chroot)
    - called by postinst of the skybian.deb package
    - disables and enables required systemd services
    - removes any autogenerated skywire config
* skybian-patch-config.sh
    - changes the skywire config for the hypervisor to serve rpc on lan
    - restarts skywire and disables skywire-patch-config.service
* skybian-patch-config.service
    - runs on first boot if hypervisor is configured
* skybian-reset.sh
    - resets skybian except for the static ip configuration (script for testing)


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
