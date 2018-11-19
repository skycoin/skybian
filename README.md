# OS images for Skyminer powered by ARMbian

Workspace to generate the Skyminer OS images for SkyCoin, based on [latest OS images](https://www.armbian.com/orange-pi-prime/) from [Armbian](https://www.armbian.com/), at this moment only for  [Orange Pi Prime](http://www.orangepi.org/OrangePiPrime/).

## Why?

[Debian](https://www.debian.org) is the one of the most stable Linux OS out there, also it's free as in freedom and has a strong & healthy community support; but on the ARM64 & [SBC world](https://en.wikipedia.org/wiki/Single-board_computer) its [Armbian](https://www.armbian.com/) who has the lead, of curse built on the shoulders of Debian.

Then why not to step up on the shoulders of this two to great projects to build our Skyminers OS images?

## Main guidelines

We follow a few simple guidelines to archive our goal:

* Build on top of the last non-GUI version of armbian for our hardware, yes: on top of the image.
* Prepare that image and install software and dependencies to run the code.
* Build from one base root FS all the images for manager and nodes.
* The scripts & tests must be fully automatic to integrate with other tools, to ease the dev cycle (travis et al)
* All non-workspace related files and binaries (beside final images) is not covered on the repository (or it will grow 'ad infinitum' with useless data)

## Where is the data?

When you run the build.sh script it will create a ```output``` directory with all the relevant data on it, we fetch all needed tools from the internet.

## This is yet a Work In Progress

Yes, this is just a work in progress, please contribute with test results, ideas, comments, etc.
