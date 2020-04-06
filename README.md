# Skybian

[![Build Status](https://travis-ci.com/SkycoinProject/skybian.svg?branch=master)](https://travis-ci.com/SkycoinProject/skybian)

Skybian is an [Armbian-based](https://www.armbian.com/) Operating System that contains the Skycoin's Skywire software and it's dependencies.

Currently, only the [Orange Pi Prime](http://www.orangepi.org/OrangePiPrime/) [Single Board Computer](https://en.wikipedia.org/wiki/Single-board_computer) is supported.

This repository has two main components. The first is a script for building a base Skybian image. The second is a tool named `skyimager`, that downloads a base Skybian image, and generates a number of final Skybian images (based on the provided options by the user).

## Configure and build

Both the script to build a Skybian base image, as well as the script to build `skyimager-gui` are configured via [`build.conf`](./build.conf).

To build the Skybian base image, run:
```bash
$ make build-skybian-img
```

To build `skyimager-gui`, run:
```bash
$ make build-skyimager-gui
```

## Developers

Please check out the [doc](./doc) folder for resources that may help you out.

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

