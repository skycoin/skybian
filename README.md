# OS images for Skyminer powered by Armbian

[![Build Status](https://travis-ci.org/skycoin/skybian.svg?branch=master)](https://travis-ci.org/skycoin/skybian)

Workspace to generate the Skyminer OS images for Skycoin, based on [latest OS images](https://www.armbian.com/orange-pi-prime/) from [Armbian](https://www.armbian.com/), at this moment only for  [Orange Pi Prime](http://www.orangepi.org/OrangePiPrime/).

## Why

[Debian](https://www.debian.org) is the one of the most stable Linux OS out there, also it's free as in freedom and has a strong & healthy community support; but on the ARM64 & [SBC world](https://en.wikipedia.org/wiki/Single-board_computer) it's [Armbian](https://www.armbian.com/) who has the lead, of curse built over Debian ground.

Then why not to step up on the shoulders of this two to great projects to build our Skyminers OS images?

## Armbian: binary image vs. whole dev space

At the early stages we get to that point also, but working over the images has a few advantages:

* Simplify the work: by working with the image we avoid to duplicate efforts in fs, kernel, boot tricks and other simpler stuff that Armbian's team do very well, this allow us to concentrate on a simpler task: customize a SBC image tailored for our target hardware.
* Armbian covers a lot of ground by supporting a big set of SBC out there, but we are focused now in just one: the Orange Pi Prime; thanks to the work done by the Armbian team, port this software in the future to other Armbian powered SBC will be relatively easy.
* Working over a system image is easy (yes, a lot of people think the contrary!) the GNU/Linux tools to do the job are out there and forensic IT people know them well.

## Main guidelines

We follow a few simple guidelines to archive our goal:

* Build on top of the last non-GUI version of Armbian for our hardware, yes: on top of the binary image.
* Prepare that image and install software and dependencies to run the code.
* Build from one base root FS, all the images for manager and nodes.
* The scripts & tests must be fully automatic to integrate with other tools, to ease the dev cycle (travis 'et al')
* All non-workspace related files and binaries (beside final images) is not covered on the repository (or it will grow 'ad infinitum' with useless data)
* On the client's side, they will use the Skybian releases as a base image and will tune it to his particular environment with the [Skyflash](https://github.com/skycoin/skyflash) tool, follow the link to know more about this.

If you want to know more about the build process keep reading.

## Develop process

If you plan to build the image yourself or to contribute with the project and test it, then you must take a peek on [this document](Building_Skybian.md) that describe the whole build process and some software dependencies you need to solve in order to successfully run the `build.sh` script.

The dev process happens in a linux PC, Ubuntu 18.04 LTS is the system of choice, but any debian like version with the dependencies must work.

This repository has two main branches:

* `master` this is the latest stable and production safe branch, release files are the code & the result of run the master branch.
* `develop` this is the latest code with new features and solution to known issues, and new features. It must not be used for production.

## Releases

To do a release you must follow these steps:

0. Check if there are commits on the master branch that must be applied to develop (hot fixes or security ones), apply them and fix any merge issues.
0. On develop branch, check any pending issues in order to close them if possible on this release and close them is possible.
0. Merge the develop branch into the release one and fix any conflicts if any.
0. Update the new version number in the `build.conf` file.
0. Update the `CHANGELOG.md` file with any needed info and move the `Unreleased` part to the new release version.
0. Review & update the `README.md` file for any needed updates or changes that need attention in the front page.
0. Wait for travis to validate all the changes (can take more than 30 minutes)
0. On success, tag the code at this point with `release-X.Y.Z-rc`, then wait for travis completion and check the draft release is published on the repository with the Skybian-X.Y.Z-rc.tar.xz file.
0. Download the Skybian-X.Y.Z-rc.tar.xz file from Github and test manually that Skyflash can work with it and generate the images for the default values.
0. If problems are found with skyflash raise issues where needed (skyflash/skybian) and fix them before continue with the next step
0. Test the generated images in real hardware (a manager and two nodes at least) to detect any issues.
0. Fix any issues if found (work in the release branch)
0. After all problems are solved and work as expected, raise a PR against master branch and merge it, then tag it as `Skybian-X.Y.Z` that will trigger travis.
0. Wait for travis completion and check the Skybian-X.Y.Z.tar.xz file is published on the Github repository under releases.
0. Edit & comment the release with the changes in CHANGELOG.md that match this release.
0. Merge master into develop.
0. Check if there is needed to raise issues & PR on the following repositories:

    * [Skyflash](https://github.com/skycoin/skyflash): to update it's README.md and code for the final Skybian release URL.
    * [Skycoin](https://github.com/skycoin/skycoin): mentions in it's README.md and elsewhere if applicable
    * [Skywire](https://github.com/skycoin/skywire): to note the new release and the use of skybian/skyflash