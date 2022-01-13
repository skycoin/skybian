Builds requires archlinux host.

### Skybian image:

install dependencies from AUR:
```
yay -S gnome-disk-utility qemu-arm-static aria2 file-roller
```

Note: be sure to install qemu-arm-static-bin if you don't have qemu-arm-static installed already

Build:
```
 makepkg --skippgpcheck -p IMGBUILD
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

### Autoconfiguration Explained

The image achieves autoconfiguration by checking for any machine on the network at the .2 ip address.

If nothing is on that ip address, a static IP is set to that address, a hypervisor configuration is created, and skywire is started

If a machine is on that ip address, the rpc server of the visor running on that ip address is queried for its public key

The public key is then used to create a visor config with that public key as the remote hypervisor.

### Using the image

1) Download the image and extract it from the archive

2) Use balena etcher, or the dd command on linux, to write the image to a microSD card

3) Power off every board in the skyminer with the individual switches

4) Insert the card into the board which is designated hypervisor and power on that board. The board will reboot once during this process

5) Wait until the hypervisor interface appears

6) repeat step 2 with the next microSD card

7) wait until the visor appears in the hypervisor user interface. The bboard will reboot once during this process

8) Repeat steps 6 and 7 for every node in the skyminer


### Troubleshooting

If for some reason the hypervisor is not accessible or the visor never shows up in the hypervisor, first try rebooting that board

If the visor or hypervisor still does not show up online, ssh to the board.

run `skywire-autoconfig` to fix almost any issue with configuration and yield a running instance of skywire

If skywire-autoconfig does not work, you may need to uninstall and reinstall skywire

```
apt remove skywire-bin
apt update
apt install skywire-bin
```

To explicitly configure a visor to the hypervisor running at the .2 ip address on the network (assuming the rpc server of that visor accepts queries from the LAN)

```
skywire-autoconfig-remote
```


### Additional notes

the skybian package, when updated, will enable the skymanager systemd service and the skywire-autoconfig service and disable the skywire service. Keep this in mind when updating the package, until this is changed in the future (or don't include skybian.deb in the apt repo)

The apt repo needs to have a domain / subdomain set, and the repository configuration needs to change

An image for testing can be found at https://deb.magnetosphere.net/skybian-0.5.0.img
