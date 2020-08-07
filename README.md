# Skybian

[![Build Status](https://travis-ci.com/skycoin/skybian.svg?branch=master)](https://travis-ci.com/skycoin/skybian)

Skybian is an [Armbian-based](https://www.armbian.com/) Operating System that contains the Skycoin's Skywire software and it's dependencies.

Currently, only the [Orange Pi Prime](http://www.orangepi.org/OrangePiPrime/) [Single Board Computer](https://en.wikipedia.org/wiki/Single-board_computer) is supported.

This repository has two main components. The first is a script for building a base Skybian image. The second is a tool named `skyimager`, that downloads a base Skybian image, and generates a number of final Skybian images (based on the provided options by the user).

## Dependencies

At the time of writing, only building on Linux is supported.

Golang 1.13+ is requred.
- [Installation/Setup for Golang 1.14](https://github.com/skycoin/skycoin/blob/develop/INSTALLATION.md).

**Additional dependencies for building Skybian base image:**

```
rsync wget 7z cut awk sha256sum gzip tar e2fsck losetup resize2fs truncate sfdisk qemu-aarch64-static go
```

For Debian-based linux distributions, you can install these via:
```bash
$ sudo apt update && sudo apt install -y p7zip-full qemu-user-static build-essential crossbuild-essential-arm64
```

On Arch-based distributions, to satisfy the `qemu-aarch64-static` dependency, one can install the `qemu-arm-static` AUR package.

**Additional dependencies for building `skyimager-gui`:**

The GUI uses the [Fyne](https://github.com/fyne-io) library. The prerequisites for Fyne can be found here: https://fyne.io/develop/index

## Configure and build

Both the script to build the Skybian base image, as well as the script to build `skyimager-gui` are configured via [`build.conf`](./build.conf).

To build the Skybian base image, run:
```bash
$ make build-skybian-img
```

To build `skyimager-gui`, run:
```bash
$ make build-skyimager-gui
```

## Developer Information

### Skybian Image Build Process

The [`build.sh`](./build.sh) script orchestrates the Skybian image build process.

It's supplemented by files in the `static` folder where auxiliary scripts and systemd service files reside.

Running the script will create a folder named `output` containing:
* `parts` - Where downloaded or compiled components such as the Armbian, Skywire and `skyconf` are stored.
* `image` - Where the temporary image is stored during the build process.
* `mnt` - Used as a mount point for the image. Scripts will be copied and executed for the image being built.
* `final` - Where the final image is stored.

### Preparing a Release

1. Make sure your remote is set to a branch on origin.
2. Update [`CHANGELOG`](CHANGELOG.md) as required.
3. Change `VERSION` variable within [`build.conf`](build.conf).
4. Do `git add . && git commit -m "<your-commit-msg>"`.
5. Run `make tag`. Travis will prepare a release draft at https://github.com/skycoin/skybian/releases
6. Edit the draft and publish.

## FAQ

### What are Boot Parameters?

Final Skybian images have boot parameters written to the [Master Boot Record](https://en.wikipedia.org/wiki/Master_boot_record) section of the image. The encoded boot parameters have a maximum size of 216 bytes, and is located at offset `+0E0` (The bootstrap code area part 2).

Boot parameters determine what is, and what is not done when booting the OS.

Values of the boot parameters are separated by `0x1F` characters. The values are of the following order:
- `MD`: The operating mode of the node. Current valid values are: `0x00` (Hypervisor), `0x01` (Visor).
- `IP`: The local IP address. Only IPv4 compatible addresses are supported.
- `GW`: The gateway IP address. Only IPv4 compatible addresses are supported.
- `SS`: The passcode for the `skysocks` app (Only valid if `MD=0x01` - Visor).
- `HVS`: Delegated hypervisor public keys. (Only valid of `MD=0x01` - Visor).

These values can be written by the `skyimager-gui` (provided in this repo) with user-provided options.

