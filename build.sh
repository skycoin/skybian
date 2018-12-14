#!/bin/bash

# This is the main script to build the Skybian OS for Skycoin miners.
#
# Author: stdevPavelmc@github.com, @co7wt in telegram
# Skycoin / Simelo teams
#

# loading env variables, ROOT is the base path on top all is made
ROOT=`pwd`
. ${ROOT}/environment.txt

##############################################################################
# This bash file is structured as functions with specific tasks, to see the
# tasks flow and comments go to bottom of the file and look for the 'main'
# function to see how they integrate to do the  whole job.
##############################################################################


# function to log messages as info
function info() {
    printf '\033[0;32m[ Info ]\033[0m %s\n' "${1}"
}


# function to log messages as notices
function notice() {
    printf '\033[0;34m[ Notice ]\033[0m %s\n' "${1}"
}


# function to log messages as warnings
function warn() {
    printf '\033[0;33m[ Warning ]\033[0m %s\n' "${1}"
}


# function to log messages as info
function error() {
    printf '\033[0;31m[ Error ]\033[0m %s\n' "${1}"
}


# Test the needed tools to build the script, iterate over the needed tools
# and warn if one is missing, exit 1 is generated
function tool_test() {
    # info
    info "Testing the workspace for needed tools"
    for t in ${NEEDED_TOOLS} ; do 
        local BIN=`which ${t}`
        if [ -z "${BIN}" ] ; then
            # not found
            error "Need tool '${t}' and it's not found on the system."
            error "Please install it and run the build script again."
            exit 1
        fi
    done

    # info
    info "All tools are installed, going forward."
}


# Build the output/work folder structure, this is excluded from the git 
# tracking on purpose: this will generate GB of data on each push  
function create_folders() {
    # output [main folder]
    #   /final [this will be the final images dir]
    #   /downloads [all thing we download from the internet]
    #   /mnt [to mount resources, like img fs, etc]
    #   /timage [all image processing goes here]

    # fun is here
    cd ${ROOT}

    # info
    info "Creating output folder structure"

    # create them
    mkdir -p ${ROOT}/output
    mkdir -p ${FINAL_IMG_DIR}
    mkdir -p ${FS_MNT_POINT}
    mkdir -p ${DOWNLOADS_DIR} ${DOWNLOADS_DIR}/armbian ${DOWNLOADS_DIR}/go
    mkdir -p ${TIMAGE_DIR}

    # erase final images if there
    warn "Cleaning final images directory"
    rm -f ${FINAL_IMG_DIR}/* &> /dev/null
}


# download armbian
function download_armbian() {
    # change to dest dir
    cd ${DOWNLOADS_DIR}/armbian

    # info
    info "Downloading armbian from:"
    info "${ARMBIAN_OPPRIME_DOWNLOAD_URL}"

    # get it
    wget -c ${ARMBIAN_OPPRIME_DOWNLOAD_URL} -O 'armbian.7z'

    # check for correct download
    if [ $? -ne 0 ] ; then
        error "Can't get the armbian image file, aborting... connection issue?."
        rm "*7z *html *txt" &> /dev/null
        exit 1
    fi
}


# Get the latest ARMBIAN image for Orange Pi Prime
function get_armbian() {
    # change to dest dir
    cd ${DOWNLOADS_DIR}/armbian

    # user info
    info "Getting Armbian image, clearing dest dir first."

    # test if we have a file in there
    ARMBIAN_IMG_7z=`ls | grep 'armbian.7z'`
    if [ -z "${ARMBIAN_IMG_7z}" ] ; then
        # no image in there, must download
        info "No cached image, downloading.."

        # download it
        download_armbian
    else
        # we have the image in there; but, we must reuse it?
        if [ "${SILENT_REUSE_DOWNLOADS}" == "no" ] ; then
            # we can not reuse it, must download, so erase it
            warn "Old copy detected but you stated not to reuse it"
            rm -f "armbian.7z" &> /dev/null
            
            # get it
            info "Downloading..."
            download_armbian
        else
            # use already downloaded image fi;e
            notice "Reusing already downloaded file"
        fi
    fi

    # if you get to this point then reset to the actual filename
    ARMBIAN_IMG_7z="armbian.7z"
    
    # extract and check it's integrity
    info "Armbian file to process is:"
    info "'${ARMBIAN_IMG_7z}'"

    # check if extracted image is in there to save time
    local LIMAGE=`ls | grep Orangepiprime | grep Armbian | grep -E ".*\.img$"`
    if [ ! -z "$LIMAGE" ] ; then
        # image already extracted nothing to do
        notice "Armbian image already extracted"
    else
        # extract armbian
        info "Extracting image"
        7z e "${ARMBIAN_IMG_7z}"

        # check for correct extraction
        if [ $? -ne 0 ] ; then
            error "Extracting failed, file is corrupt? Re-run the script to get it right."
            rm "${ARMBIAN_IMG_7z}" &> /dev/null
            exit 1
        fi
    fi

    # check integrity
    info "Testing image integrity..."
    `which sha256sum` -c --status sha256sum.sha

    # check for correct extraction
    if [ $? -ne 0 ] ; then
        errorr "Integrity of the image is compromised, re-run the script to get it right."
        rm *img *txt *sha *7z &> /dev/null
        exit 1
    fi

    # get image filename
    ARMBIAN_IMG=`ls | grep -E '.*\.img$'`

    # imge integrity
    info "Image integrity assured via sha256sum."
    notice "Final image file is ${ARMBIAN_IMG}"

    # get version & kernel version info
    ARMBIAN_VERSION=`echo ${ARMBIAN_IMG} | awk -F '_' '{ print $2 }'`
    ARMBIAN_KERNEL_VERSION=`echo ${ARMBIAN_IMG} | awk -F '_' '{ print $7 }' | rev | cut -d '.' -f2- | rev`
    
    # info to the user
    notice "Armbian version: ${ARMBIAN_VERSION}"
    notice "Armbian kernel version: ${ARMBIAN_KERNEL_VERSION}"
}


# download go
function download_go() {
    # change destination directory
    cd ${DOWNLOADS_DIR}/go

    # download it
    info "Getting golang from the internet"
    wget -c "${GO_ARM64_URL}"

    # check for correct download
    if [ $? -ne 0 ] ; then
        error "Can't get the file, re-run the script to get it right."
        rm "*gz *html"  &> /dev/null
        exit 1
    fi

    # info
    info "Done, golang downloaded"
}


# get go for arm64, the version specified in the environment.txt file
function get_go() {
    # change destination directory
    cd ${DOWNLOADS_DIR}/go

    # user info
    info "Getting go version ${GO_VERSION}"

    # test if we have a file in there
    GO_FILE=`ls | grep '.tar.gz' | grep 'linux-arm64' | grep "${GO_VERSION}" | sort -hr | head -n1`
    if [ -z "${GO_FILE}" ] ; then
        # warn
        notice "There is no already downloaded file, downloading it"

        # download it
        download_go
    else
        # sure we have the image in there; but, we must reuse it?
        if [ "${SILENT_REUSE_DOWNLOADS}" == "no" ] ; then
            # we can not reuse it, must download, so erase it
            warn "Golang archive present but you opt for not to reuse it"
            rm -f "*gz *html" &> /dev/null

            # now we get it
            download_go
        else
            # reuse the already downloaded file
            notice "Using the already downloaded file"
        fi
    fi

    # get the filename
    GO_FILE=`ls | grep '.tar.gz' | grep 'linux-arm64' | grep "${GO_VERSION}" | sort -hr | head -n1`

    # testing go file integrity
    info "Test downloaded file for integrity"
    gzip -kqt ${GO_FILE}

    # check for correct extraction
    if [ $? -ne 0 ] ; then
        error "Downloaded file is corrupt, try again."
        rm "*.gz *html"  &> /dev/null
        exit 1
    fi

    # info
    info "Downloaded file is ok"
}


# find a free loop device to use
function find_free_loop() {
    # loop until we find a free loop device
    local OUT="used"
    local DEV=""
    while [ ! -z "${OUT}" ] ; do
        DEV=`awk -v min=20 -v max=99 'BEGIN{srand(); print int(min+rand()*(max-min+1))}'`
        OUT=`losetup | grep /dev/loop$DEV`
    done
    
    # output to other function
    echo "/dev/loop$DEV"
}


# Increase the image size
function increase_image_size() {
    # Armbian image is tight packed, and we need room for adding our
    # bins, apps & configs, so we will make it bigger

    # move to correct dir
    cd ${TIMAGE_DIR}

    # clean the folder
    rm -f "*img *bin" &> /dev/null

    # copy the image here
    info "Preparing the Armbian image."
    rm "${BASE_IMG}" &> /dev/null
    cp "${DOWNLOADS_DIR}/armbian/${ARMBIAN_IMG}" "${BASE_IMG}"
    
    # create the added space file
    info "Adding ${BASE_IMG_ADDED_SPACE}MB of extra space to the image."
    truncate -s +"${BASE_IMG_ADDED_SPACE}M" "${BASE_IMG}"

    # add free space to the part 1 (sfdisk way)
    echo ", +" | sfdisk -N1 "${BASE_IMG}"

    #  setup loop device
    setup_loop

    # resize to gain space
    info "Make rootfs bigger"
    sudo resize2fs "${IMG_LOOP}"

    # check fs
    rootfs_check
}


# build disk
function build_disk() {
    # move to correct dir
    cd ${TIMAGE_DIR}

    # final name
    local NAME="Skybian-${VERSION}"

    # info
    info "Building image for ${NAME}"

    # force a FS sync
    info "Forcing a fs rsync to umount the real fs"
    sudo sync

    # umount the base image
    info "Umount the fs"
    sudo umount "${FS_MNT_POINT}"

    # check integrity & fix minor errors
    rootfs_check

    # TODO [TEST]
    # shrink the partition to a minimum size
    # sudo resize2fs -M "${IMG_LOOP}"
    # 
    # shrink the partition

    # force a FS sync
    info "Forcing a fs rsync to umount the loop device"
    sudo sync

    # freeing the loop device
    info "Freeing the loop device"
    sudo losetup -d "${IMG_LOOP}"

    # copy the image to final dir.
    info "Copy the image to final dir"
    cp "${BASE_IMG}" "${FINAL_IMG_DIR}/${NAME}.img"

    # info
    info "Image for ${NAME} ready"
}


# mount the Armbian image to start manipulations
function img_mount() {
    # move to the right dir
    cd ${TIMAGE_DIR}

    # mount it
    info "Mounting root fs to work with"
    sudo mount -t auto "${IMG_LOOP}" "${FS_MNT_POINT}" -o loop,rw

    # user info
    info "RootFS is ready to work with in ${FS_MNT_POINT}"
}


# install go inside the mnt mount point
function install_go() {
    # move to right dir
    cd ${FS_MNT_POINT}

    # create go dir
    info "Creating the paths for Go"
    sudo mkdir -p ${FS_MNT_POINT}${GOROOT}
    sudo mkdir -p ${FS_MNT_POINT}${GOPATH} "${FS_MNT_POINT}${GOPATH}/src" "${FS_MNT_POINT}${GOPATH}/pkg" "${FS_MNT_POINT}${GOPATH}/bin"

    # extract golang
    info "Installing ${GO_FILE} inside the image"
    cd ${FS_MNT_POINT}${GOROOT}/../
    sudo tar -xzf ${DOWNLOADS_DIR}/go/${GO_FILE}

    # setting the GO env vars, just copy it to /etc/profiles.d/
    info "Setting up go inside the image"
    sudo cp ${ROOT}/static/golang-env-settings.sh "${FS_MNT_POINT}/etc/profile.d/"
    sudo chmod 0644 "${FS_MNT_POINT}/etc/profile.d/golang-env-settings.sh"
}


# get and install skywire inside the FS
function get_n_install_skywire() {
    # get it on downloads, and if all is good then move it to final dest inside the image
    info "Getting last version of Skywire to install inside the chroot"

    # get it from github / local is you are the dev
    local LH=`hostname`
    # TODO remove references to dev things from final code.
    if [ "$LH" == "${DEV_PC}" ] ; then
        #  creating the dest folder
        notice "DEV trick: Creating destination directory"
        mkdir -p "${DOWNLOADS_DIR}/skywire"

        # dev env no need to do the github job, get it locally
        notice "DEV trick: Sync of the local skywire copy"
        rsync -a "${DEV_LOCAL_SKYWIRE}/" "${DOWNLOADS_DIR}/skywire"
    else
        # else where, download from github
        cd "${DOWNLOADS_DIR}/"

        # get it from github
        info "Cloning Skywire from the internet to the downloads dir"
        sudo git clone ${SKYWIRE_GIT_URL}

        # check for correct git clone command
        if [ $? -ne 0 ] ; then
            error "Git clone failed, network problem?"
            exit 1
        fi
    fi

    # create folder inside the image
    info "Git clone succeed, moving it to root fs"
    sudo mkdir -p "${FS_MNT_POINT}${SKYCOIN_DIR}"

    # copy it to the final dest
    sudo rsync -a "${DOWNLOADS_DIR}/skywire" "${FS_MNT_POINT}${SKYCOIN_DIR}"
}


# enable chroot
function enable_chroot() {
    # copy the aarm64 static exec to be able to execute 
    # things on the internal chroot
    AARM64=`which qemu-aarch64-static`

    # log
    info "Setup of the chroot jail to be able to exec command inside the roofs." 

    # copy the static bin
    sudo cp ${AARM64} ${FS_MNT_POINT}/usr/bin/

    # some required mounts
    info "Mapping special mounts inside the chroot" 
    sudo mount -t sysfs none ${FS_MNT_POINT}/sys
    sudo mount -t proc none ${FS_MNT_POINT}/proc
    sudo mount --bind /dev ${FS_MNT_POINT}/dev
    sudo mount --bind /dev/pts ${FS_MNT_POINT}/dev/pts
}


# disable chroot
function disable_chroot() {
    # remove the aarm64 static exec... disabling chroot support
    AARM64="qemu-aarch64-static"

    # log
    info "Disable the chroot jail." 

    # remove the static bin
    sudo rm ${FS_MNT_POINT}/usr/bin/${AARM64}

    # umount temp mounts
    sudo umount ${FS_MNT_POINT}/sys
    sudo umount ${FS_MNT_POINT}/proc
    sudo umount ${FS_MNT_POINT}/dev/pts
    sudo umount ${FS_MNT_POINT}/dev
}


# work to be donde on chroot
function do_in_chroot() {
    # enter chroot and execute what is passed as argument
    # WARNING  this must be run after enable_chroot
    # and NEVER BEFORE it

    # exec the commands
	sudo chroot "${FS_MNT_POINT}" $@
}


# fix some defaults on armian to skywire defaults
function fix_armian_defaults() {
    # armbian has some tricks in there to ease the operation.
    # some of them are not needed on skywire, so we disable them

    # disable the forced root password change and user creation
    info "Disabling new user creation on Armbian"
    sudo cp -f ${ROOT}/static/armbian-check-first-login.sh \
        ${FS_MNT_POINT}/etc/profile.d/armbian-check-first-login.sh

    # change root password
    info "Setting default password"
    sudo cp ${ROOT}/static/chroot_passwd.sh ${FS_MNT_POINT}/tmp
    sudo chmod +x ${FS_MNT_POINT}/tmp/chroot_passwd.sh
    do_in_chroot /tmp/chroot_passwd.sh
    sudo rm ${FS_MNT_POINT}/tmp/chroot_passwd.sh

    # execute some extra commands inside the chroot
    info "Executing extra configs."
    sudo cp ${ROOT}/static/chroot_extra_commands.sh ${FS_MNT_POINT}/tmp
    sudo chmod +x ${FS_MNT_POINT}/tmp/chroot_extra_commands.sh
    do_in_chroot /tmp/chroot_extra_commands.sh
    sudo rm ${FS_MNT_POINT}/tmp/chroot_extra_commands.sh

    # header update: present it as skybian.
    info "Headers update, now it presents itself as Skybian"
    sudo cp ${ROOT}/static/10-skybian-header ${FS_MNT_POINT}/etc/update-motd.d/
    sudo chmod +x ${FS_MNT_POINT}/etc/update-motd.d/10-skybian-header
    sudo cp -f ${ROOT}/static/armbian-motd ${FS_MNT_POINT}/etc/default

    # copy config files
    info "Copy and set of the default config files"
    sudo cp ${ROOT}/static/skybian.conf ${FS_MNT_POINT}/etc/
    sudo cp ${ROOT}/static/skybian-config ${FS_MNT_POINT}/usr/local/bin/
    sudo chmod +x ${FS_MNT_POINT}/usr/local/bin/skybian-config
    sudo cp ${ROOT}/static/skybian-config.service ${FS_MNT_POINT}/etc/systemd/system/
    do_in_chroot systemctl enable skybian-config.service
}


# setup the rootfs to a loop device 
function setup_loop() {
    # find a free loopdevice and set it on the environment
    IMG_LOOP=`find_free_loop`

    # user info
    info "Using ${IMG_LOOP} to mount the root fs."

    # map p1 to a loop device to ease operation
    local OFFSET=`echo $((${ARMBIAN_IMG_OFFSET} * 512))`
    sudo losetup -o "${OFFSET}" "${IMG_LOOP}" "${BASE_IMG}"
}


# root fs check
function rootfs_check() {
    # info
    info "Starting a FS check"
    sudo e2fsck -fpD "${IMG_LOOP}"
}


# systemd unit settings
function set_systemd_unit() {
    # only one parameter: unit file type (manager | node)
    # it will use the "${SKYMINER_MANAGER}" env var

    # info
    info "Setting Systemd unit service"

    # local var
    local UNITSDIR=${FS_MNT_POINT}${SKYWIRE_DIR}/static/script/upgrade/data

    # silently remove all units
    sudo rm ${FS_MNT_POINT}/etc/systemd/system/skywire*.service &>/dev/null

    # copy only the respective unit
    sudo cp "${UNITSDIR}/skywire-${1}.service" ${FS_MNT_POINT}/etc/systemd/system/

    # activate it
    info "Activating Systemd unit services."
    do_in_chroot systemctl enable skywire-${1}.service
}


# calculate md5, sha1 and compress
function calc_sums_compress() {
    # change to final dest
    cd ${FINAL_IMG_DIR}

    # vars
    local LIST=`ls *.img | xargs`

    # info
    info "Calculating the md5sum for the image, this may take a while"

    # cycle for each one
    for img in ${LIST} ; do
        # MD5
        info "MD5 Sum for image: $img"
        md5sum -b ${img} > ${img}.md5

        # sha1
        info "SHA1 Sum for image: $img"
        md5sum -b ${img} > ${img}.sha1

        # compress
        info "Compress it..."
        local name=`echo ${img} | awk -F '_' '{ print $2 }' | awk -F '.' '{ print $1 }'`
        tar -cvf ${name}.tar ${img}*
        xz -vzT0 ${name}.tar

        # remove files
        warn "Removing old files"
        rm ${img} ${img}.md5 ${img}.sha1
    done
}


# main exec block
function main () {
    # test for needed tools
    tool_test

    # create output folder and it's structure
    create_folders

    # download resources
    get_armbian
    get_go

    # increase image size
    increase_image_size

    # Mount the Armbian image
    img_mount

    # install golang
    install_go

    # get skywire and move it inside the FS root
    get_n_install_skywire

    # setup chroot
    enable_chroot

    # fixed for armbian defaults
    fix_armian_defaults

    # setup the systemd unit to start the services
    set_systemd_unit "manager"

    # disable chroot
    disable_chroot

    # build manager image
    build_disk

    # all good signal
    info "Done"
}

# doit
main
