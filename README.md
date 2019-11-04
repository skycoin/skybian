# What is Skybian?

[![Build Status](https://travis-ci.com/SkycoinProject/skybian.svg?branch=master)](https://travis-ci.com/SkycoinProject/skybian)

Skybian is an [Armbian-based](https://www.armbian.com/) Operating System that contains the Skycoin's Skywire testnet software and it's dependencies.

Currently, only the [Orange Pi Prime](http://www.orangepi.org/OrangePiPrime/) is supported, this are the [Single Board Computers](https://en.wikipedia.org/wiki/Single-board_computer) (SBC) you found on the Skycoin Skyminers.

## Why Debian, Armbian?

[Debian](https://www.debian.org) is a stable and widely supported Linux OS. Unfortunately, there is no straightforward way to install it on a Single Board Computer.

Armbian simplifies the process by providing System Images that contain the components required to run Debian on ARM and ARM64 architectures.

## Building over Armbian Binary Images vs Starting from Scratch

Working over existing images has a few advantages:

* Simplified development: we avoid duplicating the work required to create/maintain filesystems, kernels, boot scripts and other standard system components. This allows us to concentrate on customizing SBC Images tailored for our target hardware.
* Armbian supports a variety of SBC's.  Thanks to the work done by the Armbian team; porting the Skywire Software in the future for other Armbian-powered SBC's will be relatively easy.
* Working over a system image is easier and GNU/Linux tools are familiar.

## We follow a few simple guidelines to archive our goal:

* Build atop of the latest non-GUI version of Armbian.
* Prepare image; install the required software and dependencies.
* Build from one base root filesystem for both Manager and Minion nodes.
* Scripts & tests must be fully automatic; integrate with other tools to ease the dev cycle (travis 'et al')
* All non-workspace related files, binaries (beside final images) are excluded in the repository (or it will grow 'ad infinitum' with useless data)
* Client's will use Skybian releases as a base-image and may tune it to their particular environment with the [Skyflash](https://github.com/SkycoinProject/skyflash) tool

## Development process

If you plan to build the image yourself or to contribute with the project and test it, then you must take a peek on [this document](Building_Skybian.md) that describe the whole build process and some software dependencies you need to solve in order to successfully run the `build.sh` script.

The dev process happens in a linux PC, Ubuntu 18.04 LTS is the system of choice, but any debian like version with the dependencies must work.

This repository has two main branches:

* `master` this is the latest stable and production safe branch, release files are the code & the result of run the master branch.
* `develop` this is the latest code with new features and solution to known issues, and new features. It must not be used for production.

### Releases

You need a own repository to work before making the final pull request, for that you need a github account with travis integration and permission to push & deploy to the SkycoinProject/skybian repository.

To do a release you must follow these steps:

0. Fork the develop branch in the official SkycoinProject/skybian repository, then create locally a fork named release-vX.Y.Z, see the [CHANGELOG](CHANGELOG.md) file to see what's the next version number.
0. Check if there are commits on the master/fix/security branches at SkycoinProject/skybian repository that must be applied to release-vX.Y.Z, apply them and fix any merge issues.
0. Check any pending issues in order to close them if possible on this release.
0. Update the new version number in the `build.conf` file.
0. Update the `CHANGELOG.md` file with any needed info and move the `Unreleased` part to the new release version.
0. Review & update the `README.md` file for any needed updates or changes that need attention in the front page.
0. Wait for travis to validate all the changes.
0. On success, merge the release-vX.Y.Z branch into your local master branch, wait for travis validation and deploy.
0. Check that a draft release is published on your repository with the Skybian-vX.Y.Z.tar.xz file on it.
0. Download the Skybian-vX.Y.Z.tar.xz file from Github draft and test manually that Skyflash can work with it and generate the images for the default values.
0. If problems are found with skyflash raise issues where needed (skyflash/skybian) and fix them before continue with the next step.
0. Test the generated images in real hardware (a manager and two nodes at least) to detect any issues.
0. Fix any issues if found.
0. After all problems are solved and work as expected, tag it as `vX.Y.Z` & raise a PR against master branch in SkycoinProject/skybian, solve any issues and merge it.
0. Wait for travis completion and check the Skybian-vX.Y.Z.tar.xz file is published on the Github repository under releases.
0. Edit & comment the release with the changes in CHANGELOG.md that match this release, change status from Draft to Official release.
0. Update the version.txt file with the link to Skybian-vX.Y.Z.tar.xz in the matching case (testnet/mainner) and commit it directly to master, after finish discard the draft release in the releases page.
0. Merge master into develop.
0. Check if there is needed to raise issues & PR on the following repositories:

    * [Skyflash](https://github.com/SkycoinProject/skyflash): to update it's README.md and code for the final Skybian release URL.
    * [Skycoin](https://github.com/SkycoinProject/skycoin): mentions in it's README.md and elsewhere if applicable
    * [Skywire](https://github.com/SkycoinProject/skywire): to note the new release and the use of skybian/skyflash
