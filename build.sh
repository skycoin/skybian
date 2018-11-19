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

    # fun is here
    cd ${ROOT}

    # create them
    mkdir -p output/final output/mnt output/timage
    mkdir -p output/downloads
    mkdir -p output/downloads/armbian
    mkdir -p output/downloads/go
}


# Extract armbian
function check_armbian_img_already_down() {
    # change to dest dir
    cd ${DOWNLOADS_DIR}/armbian

    # clean extracted files
    rm *img* *txt *sha &> /dev/null

    # test if we have a file in there
    local ARMBIAN_IMG=`ls | grep 7z | grep Armbian | grep Orangepiprime | sort -hr | head -n1`
    if [ -z "${ARMBIAN_IMG}" ] ; then
        # no image in there, must download
        echo "false"
    else
        # sure we have the image in there; but, we must reuse it?
        if [ "${SILENT_REUSE_DOWNLOADS}" == "no" ] ; then
            # we can not reuse it, must download, so erase it
            rm -f "${ARMBIAN_IMG}" &> /dev/null
            echo "false"
        else
            # reuse it, return the filename
            echo "${ARMBIAN_IMG}"
        fi
    fi
}


# Check armbian integrity
function check_armbian_integrity() {
    # change to dest dir
    cd ${DOWNLOADS_DIR}/armbian

    # test for downloaded file
    if [ ! -f ${ARMBIAN_IMG} ] ; then
        # no file, exit
        exit 1
    fi

    # TODO trap this
    # extract armbian
    echo "Info: Extracting downloaded file..."
    `which 7z` e -bb0 -bd ${ARMBIAN_IMG} > /dev/null

    # check for correct extraction
    if [ $? -ne 0 ] ; then
        echo "Error: Downloaded file is corrupt, re-run the script to get it right."
        rm ${ARMBIAN_IMG} &> /dev/null
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
        ARMBIAN_IMG=${DOWNLOADED}
        echo "Info: reusing file:"
        echo "      ${ARMBIAN_IMG}"
    fi
    
    # get version & kernel version info
    ARMBIAN_VERSION=`echo ${ARMBIAN_IMG} | awk -F '_' '{ print $2 }'`
    ARMBIAN_KERNEL_VERSION=`echo ${ARMBIAN_IMG} | awk -F '_' '{ print $7 }' | rev | cut -d '.' -f2- | rev`
    
    # info to the user
    echo "Info: Got armbian version '${ARMBIAN_VERSION}' with kernel version '${ARMBIAN_KERNEL_VERSION}'"

    # extract and check it's integrity
    check_armbian_integrity
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

    # all good signal
    echo "All good so far"
}

# doit
main
