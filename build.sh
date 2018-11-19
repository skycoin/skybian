#!/bin/bash

# This is the main script to build the Skybian OS for Skycoin miners.
#
# Author: stdevPavelmc@github.com, @co7wt in telegram
#

# loading env variables, ROOT is the base path on top all is made
ROOT=`pwd`
. ${ROOT}/environment.txt

# Test the needed tools to build the script, iterate over the needed tools
# and warn if one is missing, exit 1 is generated
function tool_test() {
    for t in ${NEEDED_TOOLS} ; do 
        local BIN=$(which ${t})
        if [ -z "${BIN}" ] ; then
            # not found
            echo "Error: need tool '${t}' and it's not found on the system."
            echo "Please install it and run the build script again."
            exit 1
        fi
    done
}


# Build the output/work folder structure, this is excluded from the git 
# tracking on purpose: this will generate GB of data on each push  
function create_folders() {
    # output [main folder]
    #   /final [this will be the final images dir]
    #   /downloaded [all thing we doenload from the internet]
    #   /mnt [to mount resources, like img fs, etc]
    #   /timage [all image processing goes here]
    #   /tmp [tmp dir to copy, move, etc]

    # fun is here
    cd ${ROOT}

    # create them
    mkdir -p ${ROOT}/output
    mkdir -p ${FINAL_IMG_DIR}
    mkdir -p ${FS_MNT_POINT}
    mkdir -p ${DOWNLOADS_DIR} ${DOWNLOADS_DIR}/armbian ${DOWNLOADS_DIR}/go
    mkdir -p ${TIMAGE_DIR}
    mkdir -p ${TMP_DIR}
}


# Extract armbian
function check_armbian_img_already_down() {
    # change to dest dir
    cd ${DOWNLOADS_DIR}/armbian

    # clean extracted files
    rm *img* *txt *sha &> /dev/null

    # test if we have a file in there
    local ARMBIAN_IMG_7z=`ls | grep 7z | grep Armbian | grep Orangepiprime | sort -hr | head -n1`
    if [ -z "${ARMBIAN_IMG_7z}" ] ; then
        # no image in there, must download
        echo "false"
    else
        # sure we have the image in there; but, we must reuse it?
        if [ "${SILENT_REUSE_DOWNLOADS}" == "no" ] ; then
            # we can not reuse it, must download, so erase it
            rm -f "${ARMBIAN_IMG_7z}" &> /dev/null
            echo "false"
        else
            # reuse it, return the filename
            echo "${ARMBIAN_IMG_7z}"
        fi
    fi
}


# Check armbian integrity
function check_armbian_integrity() {
    # change to dest dir
    cd ${DOWNLOADS_DIR}/armbian

    # test for downloaded file
    if [ ! -f ${ARMBIAN_IMG_7z} ] ; then
        # no file, exit
        exit 1
    fi

    # TODO trap this
    # extract armbian
    echo "Info: Extracting downloaded file..."
    `which 7z` e -bb0 -bd ${ARMBIAN_IMG_7z} > /dev/null

    # check for correct extraction
    if [ $? -ne 0 ] ; then
        echo "Error: Downloaded file is corrupt, re-run the script to get it right."
        rm ${ARMBIAN_IMG_7z} &> /dev/null
        exit 1
    fi

    # TODO trap this
    # check integrity
    echo "Info: Testing image integrity..."
    `which sha256sum` -c --status sha256sum.sha

    # check for correct extraction
    if [ $? -ne 0 ] ; then
        echo "Error: Integrity of the file is compromised, re-run the script to get it right."
        rm *img* *txt *sha *7z &> /dev/null
        exit 1
    fi
} 


# Get the latest ARMBIAN image for Orange Pi Prime 
function get_armbian() {
    # change to dest dir
    cd ${DOWNLOADS_DIR}/armbian

    # user info
    echo "Info: Getting Armbian image"

    # check if we have the the image already and 
    # actions to reuse/erase it
    local DOWNLOADED=`check_armbian_img_already_down`

    # download it if needed
    if [ "$DOWNLOADED" == "false" ] ; then
        # yes get it down
        wget -cq ${ARMIAN_OPPRIME_DOWNLOAD_URL}

        # check for correct download
        if [ $? -ne 0 ] ; then
            echo "Error: Can't get the file, re-run the script to get it right."
            rm "*7z *html" &> /dev/null
            exit 1
        fi
    else
        # user feedback
        ARMBIAN_IMG_7z=${DOWNLOADED}
        echo "Info: reusing file:"
        echo "      ${ARMBIAN_IMG_7z}"
    fi
    
    # get version & kernel version info
    ARMBIAN_VERSION=`echo ${ARMBIAN_IMG_7z} | awk -F '_' '{ print $2 }'`
    ARMBIAN_KERNEL_VERSION=`echo ${ARMBIAN_IMG_7z} | awk -F '_' '{ print $7 }' | rev | cut -d '.' -f2- | rev`
    
    # info to the user
    echo "Info: Got Armbian version: ${ARMBIAN_VERSION}"
    echo "Info: Armbian kernel version: ${ARMBIAN_KERNEL_VERSION}"

    # extract and check it's integrity
    check_armbian_integrity

    # get Armbian image name
    local NAME=`echo ${ARMBIAN_IMG_7z} | rev | cut -d '.' -f 2- | rev`
    ARMBIAN_IMG="${NAME}.img" 
}


# download go
function download_go() {
    # change destination directory
    cd ${DOWNLOADS_DIR}/go

    # download it
    wget -cq "${GO_ARM64_URL}"

    # TODO trap this
    # check for correct download
    if [ $? -ne 0 ] ; then
        echo "Error: Can't get the file, re-run the script to get it right."
        rm "*gz *html"  &> /dev/null
        exit 1
    fi
}


# get go for arm64, the version specified in the environment.txt file
function get_go() {
    # change destination directory
    cd ${DOWNLOADS_DIR}/go

    # user info
    echo "Info: Getting go version ${GO_VERSION}"

    # test if we have a file in there
    GO_FILE=`ls | grep '.tar.gz' | grep 'linux-arm64' | grep "${GO_VERSION}" | sort -hr | head -n1`
    if [ -z "${GO_FILE}" ] ; then
        # download it
        download_go
    else
        # sure we have the image in there; but, we must reuse it?
        if [ "${SILENT_REUSE_DOWNLOADS}" == "no" ] ; then
            # we can not reuse it, must download, so erase it
            rm -f "*gz *html" &> /dev/null

            # now we get it
            download_go
        fi
    fi

    # get the filename
    GO_FILE=`ls | grep '.tar.gz' | grep 'linux-arm64' | grep "${GO_VERSION}" | sort -hr | head -n1`

    # testing go file integrity
    `which gzip` -kqt ${GO_FILE}

    # TODO trap this
    # check for correct extraction
    if [ $? -ne 0 ] ; then
        echo "Error: Downloaded file is corrupt, try again."
        rm "*gz *html"  &> /dev/null
        exit 1
    fi
}


# Increase the image size
function increase_image_size() {
    # Armbian image is tight packed, and we need room for adding our
    # bins, apps & configs, so will make it bigger

    # move to correct dir
    cd ${TIMAGE_DIR}

    # clean the folder
    rm -f "*img *bin" &> /dev/null

    # splitting the image to work with it
    echo "Info: Preparing Armbin image, this may take a while..."
    dd if="${DOWNLOADS_DIR}/armbian/${ARMBIAN_IMG}" of="${BASE_IMG}.MBR" bs=512 count="${ARMBIAN_IMG_OFFSET}"
    dd if="${DOWNLOADS_DIR}/armbian/${ARMBIAN_IMG}" of="${BASE_IMG}.ROOTFS" bs=512 skip="${ARMBIAN_IMG_OFFSET}"

    # create the added space file
    echo "Info: Adding a extra space to the image."
    dd if=/dev/zero of=./added_space.bin bs=1024k count=${BASE_IMG_ADDED_SPACE}

    # acctually add space
    cat ./added_space.bin >> "${BASE_IMG}.ROOTFS"

    # resize to gain space
    resize2fs "${BASE_IMG}.ROOTFS"

    # erase extra blanck space
    rm ./added_space.bin &> /dev/null
}


# build disk
function build_disk() {
    # move to correct dir
    cd ${TIMAGE_DIR}

    # force a FS sync
    sudo sync

    # umount the base image
    sudo umount ${FS_MNT_POINT}

    # built the disk
    cat "${BASE_IMG}.MBR" > "${BASE_IMG}"
    cat "${BASE_IMG}.ROOTFS" >> "${BASE_IMG}"

    # # clean the workspace
    # rm "${BASE_IMG}.MBR" &> /dev/null
    # rm "${BASE_IMG}.ROOTFS" &> /dev/null
}


# mount the Armbian image to start manipulations
function img_mount() {
    # move to the right dir
    cd ${TIMAGE_DIR}

    # mount it
    # TODO catch sudo commands
    sudo mount -t auto "${BASE_IMG}.ROOTFS" "${FS_MNT_POINT}" -o loop,rw

    # user info
    echo "Info: RootFS is ready to work with in ${FS_MNT_POINT}"
}


# install go inside the mnt mount point
function install_go() {
    # move to right dir
    cd ${FS_MNT_POINT}

    # create go dir
    sudo mkdir -p ${FS_MNT_POINT}${GOROOT}

    # extract golang
    echo "Info: Installing ${GO_FILE} inside the image"
    sudo cp ${DOWNLOADS_DIR}/go/${GO_FILE} ${FS_MNT_POINT}${GOROOT}/../
    cd ${FS_MNT_POINT}${GOROOT}/../
    sudo tar -xzf ${GO_FILE}
    sudo rm ${GO_FILE}

    # setting the GO env vars, just copy it to /etc/profiles.d/
    sudo cp ${ROOT}/static/golang-env-settings.sh "${FS_MNT_POINT}/etc/profile.d/"
    sudo chmod 0644 "${FS_MNT_POINT}/etc/profile.d/golang-env-settings.sh"
}


# main exec block
function main () {
    # test for needed tools
    echo "Info: Testing for needed tools..."
    tool_test

    # create output folder and it's structure
    echo "Info: Creating output folder structure..."
    create_folders

    # download resources
    echo "Info: Downloading resources, this may take a while..."
    get_armbian
    get_go

    # increase image size
    increase_image_size

    # Mount the Armbian image
    img_mount

    # install go
    install_go

    # build test disk
    build_disk

    # all good signal
    echo "All good so far"
}

# doit
main
