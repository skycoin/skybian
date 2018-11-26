# OS images for Skyminer powered by Armbian

Workspace to generate the Skyminer OS images for Skycoin, based on [latest OS images](https://www.armbian.com/orange-pi-prime/) from [Armbian](https://www.armbian.com/), at this moment only for  [Orange Pi Prime](http://www.orangepi.org/OrangePiPrime/).

## Why

[Debian](https://www.debian.org) is the one of the most stable Linux OS out there, also it's free as in freedom and has a strong & healthy community support; but on the ARM64 & [SBC world](https://en.wikipedia.org/wiki/Single-board_computer) it's [Armbian](https://www.armbian.com/) who has the lead, of curse built over Debian ground.

Then why not to step up on the shoulders of this two to great projects to build our Skyminers OS images?

## Main guidelines

We follow a few simple guidelines to archive our goal:

* Build on top of the last non-GUI version of armbian for our hardware, yes: on top of the image.
* Prepare that image and install software and dependencies to run the code.
* Build from one base root FS, all the images for manager and nodes.
* The scripts & tests must be fully automatic to integrate with other tools, to ease the dev cycle (travis 'et al')
* All non-workspace related files and binaries (beside final images) is not covered on the repository (or it will grow 'ad infinitum' with useless data)

## Where is the data

When you run the build.sh script it will create a ```output``` directory with all the relevant data on it, we fetch all needed tools from the internet; that's it.

## Armbian: Final image or Whole dev space.

At the early stages we get to that point also, but working over the images has a few advantages:

* Simplify the work: by working with the image we avoid to duplicate efforts in fs, kernel, boot tricks and other simpler stuff that Armbian's team do very well, this allow us to concentrate on a simpler task: customize a SBC image tailored for out target hardware.
* Armbian covers a lot of ground by supporting a big set of SBC out there, and we are focused on only one. If they do they job very well whey do we need to duplicate it?
* Working over a system image is easy (yes, a lot of people think the contrary) the GNU/Linux tools are out there and forensic people know them well.

## This is yet a Work In Progress (WIP)

Yes, this is just a work in progress, please contribute with test results, ideas, comments, etc.

**From this point forward we are talking of features being worked out in the roadmap, beware of dragons!**

## I have cloned your repo and created my own image, what's next?

If all gone well you will have two .img file on the folder output/final, one will have the word "manager" and the other will have "node" on them.

`Tip: To form a Skyminer you need a **Manager** and a few **Nodes**, see the [Skywire](https://github.com/skycoin/skywire) project page for more details.`

So you have the basic setup of 8 'Orange Pi Prime' SBC and same count of good quality uSD cards of 8Gb or more, you need to start with the manager

Flash your Manager img on a uSD card, [Etcher](https://etcher.io) is a good place to start, it works on Windows/Linux/Mac so it works on your favorite OS.

If you are in linux 'dd' can help you if you like the CLI (and if you like the CLi you already knows how to use 'dd')

And also the rest of the uSD cards with the Node image, yes, flash the rest of the uSD with the same node.img file, will work on them later.

Insert the Master uSD card on you Orange Pi Prime and boot it up, connect a ethernet cable an set you Pc/Laptop IP to 192.168.0.254, then open a ssh connection to 192.168.0.2 (If you use windows you will need to use Putty) once you are prompted use the user 'root' and password 'skywire' 

Once you are in you will find a screen like this:

[img]

If you point your browser to the Manager web GUI at http://192.168.0.2:8000/ you will find Skywire in there:

[img]

Now you need to proceed with the node.

**TODO**