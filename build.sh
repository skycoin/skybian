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

# Test the needed tools to build the script, iterate over the needed tools
# and warn if one is missing, exit 1 is generated
function tool_test() {
    for t in ${NEEDED_TOOLS} ; do 
        local BIN=`which ${t}`
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
    #   /downloaded [all thing we download from the internet]
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


# check if we have a working armbian copy on local folders
function check_armbian_img_already_down() {
    # this is done to minimize the bandwidth use and speed up the dev process

    # change to dest dir
    cd ${DOWNLOADS_DIR}/armbian

    # clean extracted files
    rm *img* *txt *sha &> /dev/null

    # test if we have a file in there
    ARMBIAN_IMG_7z=`ls | grep 'armbian.7z'`
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
        echo "There is no armbian image on the download folder:"
        local LS=`ls ${DOWNLOADS_DIR}/armbian`
        printf "%s" "${LS}"
        echo "Exit."
        exit 1
    fi

    # debug
    echo "Armbian file to process is: ${ARMBIAN_IMG_7z}"

    # TODO trap this
    # extract armbian
    echo "Info: Extracting downloaded file..."
    `which 7z` e -bb3 ${ARMBIAN_IMG_7z}

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

    # debug
    echo "Check for previous downloaded armbian file is: $DOWNLOADED"

    # download it if needed
    if [ "$DOWNLOADED" == "false" ] ; then
        # yes get it down
        echo "We need to download a new file."
        wget -c ${ARMBIAN_OPPRIME_DOWNLOAD_URL} -O 'armbian.7z'

        # check for correct download
        if [ $? -ne 0 ] ; then
            echo "Error: Can't get the armbian image file, re-run the script to get it right."
            rm "*7z *html *txt" &> /dev/null
            exit 1
        fi

        # if you get to this point then reset to the actual filename
        ARMBIAN_IMG_7z="armbian.7z"
    else
        # use already downloaded image fi;e
        ARMBIAN_IMG_7z=${DOWNLOADED}
        echo "Info: reusing file:"
        echo "      ${ARMBIAN_IMG_7z}"
    fi
    
    # extract and check it's integrity
    check_armbian_integrity

    # get version & kernel version info
    ARMBIAN_VERSION=`echo ${ARMBIAN_IMG_7z} | awk -F '_' '{ print $2 }'`
    ARMBIAN_KERNEL_VERSION=`echo ${ARMBIAN_IMG_7z} | awk -F '_' '{ print $7 }' | rev | cut -d '.' -f2- | rev`
    
    # info to the user
    echo "Info: Armbian version: ${ARMBIAN_VERSION}"
    echo "Info: Armbian kernel version: ${ARMBIAN_KERNEL_VERSION}"


    # get Armbian image name
    local NAME=`echo ${ARMBIAN_IMG_7z} | rev | cut -d '.' -f 2- | rev`
    ARMBIAN_IMG="${NAME}.img" 
}


# download go
function download_go() {
    # change destination directory
    cd ${DOWNLOADS_DIR}/go

    # download it
    echo "Info: Getting go from the internet"
    wget -c "${GO_ARM64_URL}"

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


# find a free loop device to use
function find_free_loop() {
    # loop until we find a free loop device
    local OUT="used"
    local DEV=""
    while [ ! -z "${OUT}" ] ; do
        DEV=`awk -v min=20 -v max=99 'BEGIN{srand(); print int(min+rand()*(max-min+1))}'`
        OUT=`losetup | grep /dev/loop$DEV`
    done
    
    # output
    echo "/dev/loop$DEV"
}


# Increase the image size
function increase_image_size() {
    # Armbian image is tight packed, and we need room for adding our
    # bins, apps & configs, so will make it bigger

    # move to correct dir
    cd ${TIMAGE_DIR}

    # clean the folder
    rm -f "*img *bin" &> /dev/null

    # copy the image here
    echo "Info: Preparing Armbian image, this may take a while..."
    rm "${BASE_IMG}" &> /dev/null
    cp "${DOWNLOADS_DIR}/armbian/${ARMBIAN_IMG}" "${BASE_IMG}"
    
    # create the added space file
    echo "Info: Adding ${BASE_IMG_ADDED_SPACE}MB of a extra space to the image."
    truncate -s +"${BASE_IMG_ADDED_SPACE}M" "${BASE_IMG}"

    # # add free space to the part 1 (parted way)
    # local NSIZE=`env LANG=C parted "${BASE_IMG}" print all | grep Disk | grep MB | awk '{print $3}'`
    # echo "p
    # resizepart
    # 1
    # ${NSIZE}
    # p
    # q" | env LANG=C parted "${BASE_IMG}"

    # add free space to the part 1 (sfdisk way)
    echo ", +" | sfdisk -N1 "${BASE_IMG}"

    # find a free loopdevice
    IMG_LOOP=`find_free_loop`

    # user info
    echo "Info: Using ${IMG_LOOP} to mount the root fs."

    # map p1 to a loop device to ease operation
    local OFFSET=`echo $((${ARMBIAN_IMG_OFFSET} * 512))`
    sudo losetup -o "${OFFSET}" "${IMG_LOOP}" "${BASE_IMG}"

    # resize to gain space
    echo "Info: Make rootfs bigger & check integrity..."
    sudo resize2fs "${IMG_LOOP}"
    sudo e2fsck -fv "${IMG_LOOP}"
}


# build disk
function build_disk() {
    # move to correct dir
    cd ${TIMAGE_DIR}

    # force a FS sync
    echo "Info: Forcing a fs rsync to umount the real fs"
    sudo sync

    # check integrity & fix minor errors
    echo "Info: Checking the fs prior to umount"
    sudo e2fsck -fDy "${IMG_LOOP}"

    # TODO: disk size trim
    
    # umount the base image
    echo "Info: Umount the fs"
    sudo umount "${FS_MNT_POINT}"

    # freeing the loop device
    echo "Info: Freeing the loop device"
    sudo losetup -d "${IMG_LOOP}"

    # TODO move the image to final dir.
}


# mount the Armbian image to start manipulations
function img_mount() {
    # move to the right dir
    cd ${TIMAGE_DIR}

    # mount it
    echo "Info: mounting root fs..."
    sudo mount -t auto "${IMG_LOOP}" "${FS_MNT_POINT}" -o loop,rw

    # user info
    echo "Info: RootFS is ready to work with in ${FS_MNT_POINT}"
}


# install go inside the mnt mount point
function install_go() {
    # move to right dir
    cd ${FS_MNT_POINT}

    # create go dir
    echo "Info: Creating the paths for Go"
    sudo mkdir -p ${FS_MNT_POINT}${GOROOT}
    sudo mkdir -p ${FS_MNT_POINT}${GOPATH} "${FS_MNT_POINT}${GOPATH}/src" "${FS_MNT_POINT}${GOPATH}/pkg" "${FS_MNT_POINT}${GOPATH}/bin"

    # extract golang
    echo "Info: Installing ${GO_FILE} inside the image"
    sudo cp ${DOWNLOADS_DIR}/go/${GO_FILE} ${FS_MNT_POINT}${GOROOT}/../
    cd ${FS_MNT_POINT}${GOROOT}/../
    sudo tar -xzf ${GO_FILE}
    sudo rm ${GO_FILE}

    # setting the GO env vars, just copy it to /etc/profiles.d/
    echo "Info: Setting up go inside the image"
    sudo cp ${ROOT}/static/golang-env-settings.sh "${FS_MNT_POINT}/etc/profile.d/"
    sudo chmod 0644 "${FS_MNT_POINT}/etc/profile.d/golang-env-settings.sh"
}


# get and install skywire inside the FS
get_n_install_skywire() {
    # get it on downloads, and if all is good then move it to final dest inside the image

    # get it from github / local is you are the dev
    local LH=`hostname`
    # TODO remove references to dev things from final code.
    if [ "$LH" == "agatha-lt" ] ; then
        #  creating the dest folder
        mkdir -p "${DOWNLOADS_DIR}/skywire"

        # dev env no need to do the github job, get it locally
        echo "Info: DEV trick: sync of the local skywire copy"
        `which rsync` -av "${DEV_LOCAL_SKYWIRE}/" "${DOWNLOADS_DIR}/skywire"
    else
        # else where, download from github
        cd "${DOWNLOADS_DIR}/"

        # get it from github
        echo "Info: Cloning skywire to this download dir"
        `which git` clone ${SKYWIRE_GIT_URL}

        # check for correct git clone command
        if [ $? -ne 0 ] ; then
            echo "Error: git clone failed."
            exit 1
        fi
    fi

    # create folder inside the image
    echo "Info: Git clone ok, moving it to root fs"
    sudo mkdir -p "${FS_MNT_POINT}${SKYCOIN_DIR}"

    # copy it to the final dest
    sudo `which rsync` -av "${DOWNLOADS_DIR}/skywire" "${FS_MNT_POINT}${SKYCOIN_DIR}"

    # note the existence of the folder
    echo "Listing of the final dir."
    ls -l "${FS_MNT_POINT}${SKYCOIN_DIR}"
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

    # get skywire and move it inside the FS root
    get_n_install_skywire

    # build test disk
    build_disk

    # all good signal
    echo "All good so far"
}

# doit
main
