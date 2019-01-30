# OS images for Skyminer powered by Armbian

[![Build Status](https://travis-ci.org/simelo/skybian.svg?branch=develop)](https://travis-ci.org/simelo/skybian)

Workspace to generate the Skyminer OS images for Skycoin, based on [latest OS images](https://www.armbian.com/orange-pi-prime/) from [Armbian](https://www.armbian.com/), at this moment only for  [Orange Pi Prime](http://www.orangepi.org/OrangePiPrime/).

## Why

[Debian](https://www.debian.org) is the one of the most stable Linux OS out there, also it's free as in freedom and has a strong & healthy community support; but on the ARM64 & [SBC world](https://en.wikipedia.org/wiki/Single-board_computer) it's [Armbian](https://www.armbian.com/) who has the lead, of curse built over Debian ground.

Then why not to step up on the shoulders of this two to great projects to build our Skyminers OS images?

## Main guidelines

We follow a few simple guidelines to archive our goal:

* Build on top of the last non-GUI version of Armbian for our hardware, yes: on top of the image.
* Prepare that image and install software and dependencies to run the code.
* Build from one base root FS, all the images for manager and nodes.
* The scripts & tests must be fully automatic to integrate with other tools, to ease the dev cycle (travis 'et al')
* All non-workspace related files and binaries (beside final images) is not covered on the repository (or it will grow 'ad infinitum' with useless data)

You can take explained build process on [this article](Building_skybian.md).

## Where is the data

When you run the build.sh script it will create a ```output``` directory with all the relevant data on it, we fetch all needed tools from the internet; that's it.

## Armbian: Final image or Whole dev space.

At the early stages we get to that point also, but working over the images has a few advantages:

* Simplify the work: by working with the image we avoid to duplicate efforts in fs, kernel, boot tricks and other simpler stuff that Armbian's team do very well, this allow us to concentrate on a simpler task: customize a SBC image tailored for out target hardware.
* Armbian covers a lot of ground by supporting a big set of SBC out there, and we are focused on only one. If they do they job very well whey do we need to duplicate it?
* Working over a system image is easy (yes, a lot of people think the contrary) the GNU/Linux tools are out there and forensic people know them well.

## This is yet a Work In Progress (WIP)

Yes, this is just a work in progress, please contribute with test results, ideas, comments, etc.
