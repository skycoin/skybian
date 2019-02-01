# Description of the Skybian build process

This is a detailed guide of the steps we follow to transform an Armbian image for the Orange Pi Prime SBC into a Skybian Image.

## Know your workspace

The magic is on the `build.sh` script, it's the one in charge of the orchestra, but there are also some template files and aux scripts in the `static` folder & env variables are stored on the `build.conf` file.

On the first run of the script, it will create a folder called `output` with the following folder structure inside:

* `downloads` _all things we need to download will be placed here, things like Armbian, Skywire & Go binaries_
* `timage` _Temporary images in the build process will be placed here_
* `mnt` _Mount of the image's partitions will be done here, the main purpose is to copy & execute scripts inside the image being built_
* `final` _Final image storage_

## Step 1: Check for the tools and get the data from the internet

The script will check for the existence in your system of all the needed tools, the tools are listed in the `build.conf` file in the `NEEDED_TOOLS` variable; if one of them is not installed the script will stop and complain, you can install them all in any debian like system with this command:

```sh
sudo apt update && sudo apt install -y p7zip-full qemu-user-static build-essential crossbuild-essential-arm64
```

Then it will create the output folder and it's internal structure if not in place already

The download part kicks in at this point, latest tested Armbian image for the Orange Pi Prime SBC will be downloaded & extracted, the Go dist file for the matching architecture will be downloaded. Both download links can be found on the `build,conf` file _(the link for Go is crafted from the go version number dynamically)_

**Tip:** As the download, extraction and checking of the needed tools takes bandwidth and most important: time; there is some tricks on the `build.sh` script to reuse the files that was previously downloaded, accelerating the testing and developing process.

## Step 2: Image preparation

The Armbian team ships a image that has only a small percent of free space and we need more than that to manipulate the image; so we test the filesystem inside it and append a chunk of free space to it _(see `BASE_IMG_ADDED_SPACE` var in the `build.conf` file)_ and grow the filesystem to fill the new added space, testing the filesystem at the end.

Now all is set to begin the transformation, let's mount the base image in the `output/mnt` folder for the next steps.

## Step 3: Installing Go

We create the needed folder structure inside the image in the right place & extract the already downloaded Go dist file inside it; then we copy the file `static/golang-env-settings.sh` to a special path where it get executed at boot time, with this trick we register the Go env PATH's across the whole system.

There is a catch with this: on that script we try to load the Go env vars from `/etc/default/skywire` if that file exist, if not then set them by hand with the install defaults. The `/etc/default/skywire` file is really a link to a file that is part of the Skywire software, and it's Skywire who has the duty of creating that link if not in place, checking that on every startup.

## Step 4: Installing Skywire

The script moves to the `downloads` folder inside the `output` one, and clones the latest stable code from the github repository of Skywire _(there are a trick here also in the script to save bandwidth & time in the dev process)_ if all gone well then it will copy that folder via rsync to the right path of the mounted image file system.

All is set for the next step.

## Step 5: Tweaking Armbian into Skybian

In this step we setup a arm64 chroot environment that will allow us to make this tasks:

* Disable the creation of a local user by default in the Armbian OS (a new crafted version of the file `/etc/profile.d/armbian-check-first-login.sh` is put in place)
* Change the default root password to the Skybian default (run the script `chroot_password.sh`)
* Update the system locales.
* Update the APT indices and run optional pkgs install, this is the place to add custom pkgs to install by default on the image (see file `static/chroot_extra_commands.sh`)
* Compile the Skywire source code to Go binaries inside the chroot, in the process we test the compiler is working for future updates (be aware that the cross compilation with qemu has a bug with threading, so we do the compile job with just one core thread)
* Save the clock time to now. The SBC has no RTC and relies on the ntp protocol at run time but it need a local reference on boot with a fake hwclock. If you don't update this, all new files will be 'in the future' for Armbian and will cause troubles
* Change the header in the motd to present it as Skybian. (see `static/10-skybian-header` file)
* Copy `skybian-config` and script (more on this in the next section)
* Erase the home folder for skywire, by this trick we get a new and unique ids for each instance on first boot.

### Skywire config on boot

Part of the magic of this new OS for the Skyminers is that we can configure a single image into a manager or a node or even into a manager and 200+ nodes, all that by downloading a single image file and a tool called Skyflash, the time of downloading 8 bulky image files to get a Skyminer running is over.

Part of the magic is done by the skybian-config service, it's in charge of the following tasks:

* Read a "free" chuck of the start of the disk that is not used by Armbian or Skybian.
* Extract a configuration file from that 256 bytes disk chunk (if it's there) and overwrite the skybian-config file after validation of the data.
* If the disk space to read has not a valid config, it just runs with the defaults on the passed skybian-config file
* In any case it will start a manager or a node with the data in the skybian-config file.

## Step 6: Setup the services

Still with the chroot active we install and configure the following services:

* Skywire-manager
* Skywire-node
* Skybian-service

## Step 7: Build the disk

In this step we disable the chroot as no more work is needed inside the file system, perform a file system check and un mount the file system and free the devices associated with that.

Then the script copies the image in develop to the `output/final` folder with the proper name and version from the environment file.

## Step 8: Digest fingerprints and compression

Now that we have a final image it's time to create a digest fingerprints for it in the two most popular hashing algorithms: MD5 and SHA1, that will allow to test the integrity of the image at your end.

Once the digest fingerprints are done, the images and the digest files are packed in a .tar.xz compressed file.

The .xz (aka lzma flavour) compression method was selected because it has the best compression rations for our data type.

## Testing

All the above mentioned steps are done in a travis-ci job and at the end if it succeed and are a release it gets deployed to the Github account for you to download.

## Changelog

There is a `CHANGELOG.md` file in the source tree that keep track of changes we made to the source, like bug fixes, new features, etc.