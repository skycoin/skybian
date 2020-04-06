# The Skybian Build Process

This document outlines the steps involved in converting an Armbian Image into a Skybian Image.

## The created workspace and files involved

`build.sh` is a script that orchestrates the conversion.  It's supplemented by files in the `static` folder where templates, environment variables, auxilary scripts and systemd service files reside.

Running the script will create a folder named `output` containing:
* `downloads` _where downloaded components such as the Armbian, Skywire and Golang binaries are stored_
* `timage` _where temporary images in the build process are stored_
* `mnt` _which will be used as a mount point where scripts will be copied and executed for the image being built_
* `final` _where the final image is stored_

## Step 1: Check build environment and download components
The system which `build.sh` is executed on is checked for the required tools which are listed in the `build.conf` file under the `NEEDED_TOOLS` variable.  Missing components will stop execution.  Debian-based users may install missing files by entering the command:

```sh
sudo apt update && sudo apt install -y p7zip-full qemu-user-static build-essential crossbuild-essential-arm64
```

The `output` folder and it's internal structure is then created.

The latest stable Armbian Images and Golang distribution files (for the matching architecture) are then downloaded and extracted.  Both download links can be found in `build.conf` _(the link for Go is crafted from the go version number dynamically)_

**Tip:** Downloading, extraction, and checking for the needed tools takes bandwidth and most importantly: time.  `build.sh` contains functions that reuse previously downloaded files that accelerate testing and development.

## Step 2: Image preparation

Armbian ships with a small amount of free space which needs to be extended in order to manipulated.  The filesystem inside is tested; free space is appended, formatted _(see `BASE_IMG_ADDED_SPACE` in the `build.conf` file)_ and is again tested at the end.

Now that there's space to work with, the base image is mounted to `output/mnt`.

## Step 3: Installing Golang

Inside the image, the needed folder structure is created and the downloaded Golang distribution file is extracted.  `static/golang-env-settings.sh` is then copied to a special path where it's executed at boot time; using this method we register the Golang's environment PATH across the whole system.

`golang-env-settings.sh` tries to load environment variables from `/etc/default/skywire` (if it exists); if not, they're manually loaded.  `/etc/default/skywire` is a link to a file that is part of the Skywire software and it's Skywire's duty to create that link (if it's missing) and is checked-for every startup.

## Step 4: Installing Skywire

The `downloads` folder is then moved to `output` and clones the latest stable code from the Skwire Github repository _(doing this saves bandwidth and time in the dev process)_.  If all has gone well, that folder is copied via rsync to the appropriate path on the mounted image.

## Step 5: Tweaking Armbian into Skybian

An arm64 chroot environment is setup that will:

* Substitute the creation of a default user with the new version from file `/etc/profile.d/armbian-check-first-login.sh`
* Change the default root password to a Skybian default (see `chroot_password.sh`)
* Update system locales
* Update APT indices and run optional pkg installs (see `static/chroot_extra_commands.sh` to add custom pkgs, commands for installation on the product image)
* Compile Skywire source code to Golang binaries.  During this process the compiler is tested for use in future updates (cross compilation using qemu has a bug with threading, so compilation is done with one thread)
* Set a local time.  Single Board Computers's (SBC) have no RTC (realtime clock) and rely on the NTP (Network Time Protocol) at run time.  A local reference on boot using a fake hwclock is needed; if not, all new files will be 'in the future' and will create problems
* Change the MOTD (Message of the Day) to present as Skybian (see `static/10-skybian-header`)
* Copy `skybian-config` (more details in the next section)
* Erase the home folder for Skywire.  Doing this, new and unique ID's for each instance are generated on first boot

### Skywire config on boot

One advantage for using Skybian is that a single image may be used to create Master and Minion nodes (or one Master, 200+ Minion's) from a single image and a tool called Skyflash; no more downloading 8 bulky image files!

This is done by `skybian-config.service` which:

* Reads a "free" chunk at the start of the disk that is not used by Armbian or Skybian
* Extracts a configuration file from the 256 bytes disk chunk from above (if it's there), overwrites the `skybian-config` file after data validation
* If the disk space read does not have a valid config it runs using defaults from `skybian-config`
* In any case, will start a Master or Minion node with the data from `skybian-config`

## Step 6: Setup systemd services

Still in an arm64 chroot, the following services are installed and configured:

* Skywire-manager
* Skywire-node
* Skybian-service

## Step 7: Build the disk

Chroot is exited; the file system (and it's accompanying devices) are checked and unmounted.

The image is copied to folder `output/final` with a proper name and version from the environment file.

## Step 8: File integrity and compression

With the final image on-hand, it's time to create digest fingerprints: the two most popular hashing algorithms--MD5 and SHA1--will allow integrity tests of the image from your end.

Once the digest fingerprints are done, the image and digest files are packed in a .tar.xz compressed file.

The .xz (aka lzma flavour) compression method was selected because it has the best compression rations for our data type.

## Testing

All the above mentioned steps are done in a travis-ci job.  If the build succeeds and is released it gets deployed to the Github account for download.

## Changelog

There is a `CHANGELOG.md` file in the source tree that keeps track of changes made to the source (bug fixes, new features, etc).