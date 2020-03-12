#!/bin/bash

# This is the main script to build the Skybian OS for Skycoin miners.
#
# Author: stdevPavelmc@github.com, @pavelmc in telegram
# Skycoin / Simelo team
#

# Fail on any error
#set -eo pipefail

# loading env variables, ROOT is the base path on top all is made
ROOT=$(pwd)
. "${ROOT}/build.conf"

##############################################################################
# This bash file is structured as functions with specific tasks, to see the
# tasks flow and comments go to bottom of the file and look for the 'main'
# function to see how they integrate to do the  whole job.
##############################################################################

# Capturing arguments to show help
if [ "$1" == "-h" ] || [ "$1" == "--help" ] ; then
    # show help
    cat << EOF

$0, Skybian build script.

This script builds the Skybian base OS to be used on the Skycoin
official Skyminers, there is just a few parameters:

-h / --help     Show this help
-p              Pack the image and checksums in a form ready to
                deploy into a release. WARNING for this to work
                you need to run the script with no parameters
                first

No parameters means image creation without checksum and packing

To know more about the script work, please refers to the file
called Building_Skybian.md on this folder.

Latest code can be found on https://github.com/SkycoinProject/skybian

EOF

    # exit
    exit 0
fi


# function to log messages as info
function info() {
    printf '\033[0;32m[ INFO ]\033[0m %s\n' "${FUNCNAME[1]}: ${1}"
}


# function to log messages as notices
function notice() {
    printf '\033[0;34m[ NOTI ]\033[0m %s\n' "${FUNCNAME[1]}: ${1}"
}


# function to log messages as warnings
function warn() {
    printf '\033[0;33m[ WARN ]\033[0m %s\n' "${FUNCNAME[1]}: ${1}"
}


# function to log messages as info
function error() {
    printf '\033[0;31m[ ERRO ]\033[0m %s\n' "${FUNCNAME[1]}: ${1}"
}


# Test the needed tools to build the script, iterate over the needed tools
# and warn if one is missing, exit 1 is generated
function tool_test() {
    # info
    info "Testing the workspace for needed tools"
    for t in ${NEEDED_TOOLS} ; do
        if [ -z "$(command -v "${t}")" ] ; then
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
    cd "${ROOT}" || (error "Failed to cd." && return 1)

    info "Creating output folder structure..."

    # sub-dir envs
    DOWNLOADS_ARMBIAN_DIR=${DOWNLOADS_DIR}/armbian
    DOWNLOADS_SKYWIRE_DIR=${DOWNLOADS_DIR}/skywire
    DOWNLOADS_JQ_DIR=${DOWNLOADS_DIR}/jq

    # create them
    mkdir -p "${FINAL_IMG_DIR}"
    mkdir -p "${FS_MNT_POINT}"
    mkdir -p "${DOWNLOADS_DIR}" "${DOWNLOADS_ARMBIAN_DIR}" "${DOWNLOADS_SKYWIRE_DIR}" "${DOWNLOADS_JQ_DIR}"
    mkdir -p "${TIMAGE_DIR}"

    info "Done!"
}


# Downloads jq .pkg packages.
function get_jq() {
  info "Downloading .deb packages for jq..."
  wget "${JQ_DOWNLOAD_URLS[@]}" -P "${DOWNLOADS_JQ_DIR}" || return 1
  info "Done!"
}


# Downloads and extracts skywire.
function get_skywire() {
  local _DST=${DOWNLOADS_SKYWIRE_DIR}/skywire.tar.gz # Download destination file name.

  # Erase previous versions (if any).
  rm -rdf "${DOWNLOADS_SKYWIRE_DIR:?}/*" || true

  if [ ! -f "${_DST}" ] ; then
      notice "Downloading package from ${SKYWIRE_DOWNLOAD_URL} to ${_DST}..."
      wget -c "${SKYWIRE_DOWNLOAD_URL}" -O "${_DST}" || return 1
  else
      info "Reusing package in ${_DST}"
  fi

  info "Extracting package..."
  tar xvzf "${_DST}" -C "${DOWNLOADS_SKYWIRE_DIR}" || return 1

  info "Moving binaries to structured folders..."
  mkdir -p "${DOWNLOADS_SKYWIRE_DIR}/bin/apps" || return 1

  cd "${DOWNLOADS_SKYWIRE_DIR}" || return 1

  mv -t "${DOWNLOADS_SKYWIRE_DIR}/bin/" skywire-visor skywire-cli || return 1

  mv -t "${DOWNLOADS_SKYWIRE_DIR}/bin/apps/" skychat skysocks skysocks-client || return 1

  cd "${ROOT}" || return 1

  info "Cleaning..."
  rm "${_DST}" "*.md" || return 1

  info "Done!"
}


# download armbian
function download_armbian() {
  local _DST=${DOWNLOADS_ARMBIAN_DIR}/armbian.7z # Download destination file name.

  info "Downloading image from ${ARMBIAN_DOWNLOAD_URL} to ${_DST} ..."
  wget -c "${ARMBIAN_DOWNLOAD_URL}" -O "${_DST}" ||
    (error "Download failed." && return 1)
}


# Get the latest ARMBIAN image for Orange Pi Prime
function get_armbian() {
    # change to dest dir
    cd "${DOWNLOADS_DIR}/armbian" ||
      (error "Failed to cd." && return 1)

    # user info
    info "Getting Armbian image, clearing dest dir first."

    # test if we have a file in there
    if [ -r armbian.7z ] ; then
        ARMBIAN_IMG_7z="armbian.7z"
        # we have the image in there; but, we must reuse it?
        if [ "${SILENT_REUSE_DOWNLOADS}" == "no" ] ; then
            # we can not reuse it, must download, so erase it
            warn "Old copy detected but you stated not to reuse it"
            rm -f "armbian.7z" &> /dev/null || true

            # get it
            info "Downloading..."
            download_armbian
        else
            # use already downloaded image file
            notice "Reusing already downloaded file"
        fi
    else
        # no image in there, must download
        info "No cached image, downloading.."

        # download it
        download_armbian
    fi

    # if you get to this point then reset to the actual filename
    ARMBIAN_IMG_7z="armbian.7z"

    # extract and check it's integrity
    info "Armbian file to process is '${ARMBIAN_IMG_7z}'."

    # check if extracted image is in there to save time
    if [ -n "$(ls Armbian*.img || true)" ] ; then
        # image already extracted nothing to do
        notice "Armbian image already extracted"
    else
        # extract armbian
        info "Extracting image..."
        if ! 7z e "${ARMBIAN_IMG_7z}" ; then
            error "Extracting failed, file is corrupt? Re-run the script to get it right."
            rm "${ARMBIAN_IMG_7z}" &> /dev/null || true
            exit 1
        fi
    fi

    # check integrity
    info "Testing image integrity..."
    if ! $(command -v sha256sum) -c --status -- *.sha ; then
        error "Integrity of the image is compromised, re-run the script to get it right."
        rm -- *img *txt *sha *7z &> /dev/null || true
        exit 1
    fi

    # get image filename
    ARMBIAN_IMG=$(ls Armbian*.img || true)

    # imge integrity
    info "Image integrity assured via sha256sum."
    notice "Final image file is ${ARMBIAN_IMG}"

    # get version & kernel version info
    ARMBIAN_VERSION=$(echo "${ARMBIAN_IMG}" | awk -F '_' '{ print $2 }')
    ARMBIAN_KERNEL_VERSION=$(echo "${ARMBIAN_IMG}" | awk -F '_' '{ print $6 }' | rev | cut -d '.' -f2- | rev)

    # info to the user
    notice "Armbian version: ${ARMBIAN_VERSION}"
    notice "Armbian kernel version: ${ARMBIAN_KERNEL_VERSION}"
}


function get_all() {
  get_armbian || return 1
  get_jq || return 1
  get_skywire || return 1
}


# setup the rootfs to a loop device
function setup_loop() {

  # find free loop device
  IMG_LOOP=$(losetup -f)

  # find image sector size (if not user-defined)
  [[ -z $IMG_SECTOR ]] &&
    IMG_SECTOR=$(fdisk -l "${BASE_IMG}" | grep "Sector size" | grep -o '[0-9]*' | head -1)

  # find image offset (if not user-defined)
  [[ -z "${IMG_OFFSET}" ]] &&
    IMG_OFFSET=$(fdisk -l "${BASE_IMG}" | tail -1 | awk '{print $2}')

  # setup loop device for root fs
  info "Map root fs to loop device '${IMG_LOOP}': sector size '${IMG_SECTOR}', image offset '${IMG_OFFSET}' ..."
  sudo losetup -o "$((IMG_OFFSET * IMG_SECTOR))" "${IMG_LOOP}" "${BASE_IMG}"
}


# root fs check
function rootfs_check() {
    # info
    info "Checking root fs"
    # local var to trap exit status
    out=0
    sudo e2fsck -fpD "${IMG_LOOP}" || out=$? && true
    # testing exit status
    if [ $out -gt 2 ] ; then
        error "Uncorrected errors while checking the fs, build stopped"
        return 1
    fi
}


# Prepares base image.
# - Copy armbian img to base img loc
# - Increase base image size & prepare loop device
# - Mount loop device
function prepare_base_image() {
    # Armbian image is tight packed, and we need room for adding our
    # bins, apps & configs, so we will make it bigger

    # clean
    info "Cleaning..."
    rm -rf "${TIMAGE_DIR:?}/*" &> /dev/null || true

    # copy armbian image to base image location
    info "Copying base image..."
    cp "${DOWNLOADS_DIR}/armbian/${ARMBIAN_IMG}" "${BASE_IMG}" || return 1

    # Add space to base image
    info "Adding ${BASE_IMG_ADDED_SPACE}MB of extra space to the image..."
    truncate -s +"${BASE_IMG_ADDED_SPACE}M" "${BASE_IMG}"
    echo ", +" | sfdisk -N1 "${BASE_IMG}" # add free space to the part 1 (sfdisk way)

    info "Setting up loop device..."
    setup_loop || return 1
    rootfs_check || return 1

    info "Resizing root fs..."
    sudo resize2fs "${IMG_LOOP}" || return 1
    rootfs_check || return 1

    info "Mounting root fs to ${FS_MNT_POINT}..."
    sudo mount -t auto "${IMG_LOOP}" "${FS_MNT_POINT}" -o loop,rw

    info "Done!"
}


function clean_image() {
    disable_chroot

    sudo sync
    sudo umount "${FS_MNT_POINT}"

    rootfs_check

    sudo sync
    sudo losetup -d "${IMG_LOOP}"
}


# build disk
function build_disk() {
    # move to correct dir
    cd "${TIMAGE_DIR}" || (error "Failed to cd." && return 1)

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


# enable chroot
function enable_chroot() {
  info "Seting up chroot jail for root FS..."

  info "Setting up qemu..."
  QEMU_BIN=$(command -v qemu-aarch64-static)

  sudo cp "${QEMU_BIN}" "${FS_MNT_POINT}/usr/bin/"

  # find a way to set:
  # PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin
  # update-command-not-found

  info "Setting up special mount points..."
  sudo mount -t sysfs none "${FS_MNT_POINT}/sys"
  sudo mount -t proc none "${FS_MNT_POINT}/proc"
  sudo mount --bind /dev "${FS_MNT_POINT}/dev"
  sudo mount --bind /dev/pts "${FS_MNT_POINT}/dev/pts"
}


# disable chroot
function disable_chroot() {
  info "Disabling the chroot jail..."

  info "Removing qemu..."
  sudo rm "${FS_MNT_POINT}/usr/bin/qemu-aarch64-static"

  info "Unmounting..."
  sudo umount "${FS_MNT_POINT}/sys"
  sudo umount "${FS_MNT_POINT}/proc"
  sudo umount "${FS_MNT_POINT}/dev/pts"
  sudo umount "${FS_MNT_POINT}/dev"
}


# work to be donde on chroot
function do_in_chroot() {
    # enter chroot and execute what is passed as argument
    # WARNING  this must be run after enable_chroot
    # and NEVER BEFORE it

    # exec the commands
	sudo chroot "${FS_MNT_POINT}" "$@"
}


function copy_to_img() {
    # Copy jq packages (they will we installed by ./static/chroot_extra_commands.sh)

    info "Copying jq packages..."
    sudo cp -r "${DOWNLOADS_JQ_DIR}" "${FS_MNT_POINT}/tmp" || return 1

    # Copy skywire bins

    info "Copying skywire bins..."
    sudo cp "${DOWNLOADS_SKYWIRE_DIR}/bin/skywire-visor" "${FS_MNT_POINT}/usr/local/bin/" || return 1
    sudo cp "${DOWNLOADS_SKYWIRE_DIR}/bin/skywire-cli" "${FS_MNT_POINT}/usr/local/bin/" || return 1

    info "Copying skywire apps..."
    sudo mkdir -p "${FS_MNT_POINT}/root/skywire" || return 1
    sudo cp -r "${DOWNLOADS_SKYWIRE_DIR}/bin/apps" "${FS_MNT_POINT}/root/skywire/" || return 1

    # Copy systemd units
    
    local _SYSTEMD_DIR=${FS_MNT_POINT}/etc/systemd/system

    info "Copying systemd units..."
    sudo cp -f "${ROOT}/static/skywire-visor.service" "${_SYSTEMD_DIR}/"

    # Copy permanent scripts

    info "Copying disable user creation script..."
    sudo cp -f "${ROOT}/static/armbian-check-first-login.sh" "${FS_MNT_POINT}/etc/profile.d/armbian-check-first-login.sh" || return 1
    sudo chmod +x "${FS_MNT_POINT}/etc/profile.d/armbian-check-first-login.sh" || return 1

    info "Copying headers (so OS presents itself as Skybian)..."
    sudo cp "${ROOT}/static/10-skybian-header" "${FS_MNT_POINT}/etc/update-motd.d/" || return 1
    sudo chmod +x "${FS_MNT_POINT}/etc/update-motd.d/10-skybian-header" || return 1
    sudo cp -f "${ROOT}/static/armbian-motd" "${FS_MNT_POINT}/etc/default" || return 1

    # Copy temporary scripts

    info "Copying chroot script..."
    sudo cp "${ROOT}/static/chroot_commands.sh" "${FS_MNT_POINT}/tmp"
    sudo chmod +x "${FS_MNT_POINT}/tmp/chroot_commands.sh"

    info "Done!"
}


# fix some defaults on armian to skywire defaults
function fix_armian_defaults() {
    # armbian has some tricks in there to ease the operation.
    # some of them are not needed on skywire, so we disable them

    # Executing chroot script...
    do_in_chroot /tmp/chroot_extra_commands.sh

    # copy config files
    info "Copy and set of the default config files"
    sudo cp "${ROOT}/static/skybian.conf" "${FS_MNT_POINT}/etc/"
    sudo cp "${ROOT}/static/skybian-config" "${FS_MNT_POINT}/usr/local/bin/"
    sudo chmod +x "${FS_MNT_POINT}/usr/local/bin/skybian-config"

    # clean /tmp in root fs
    sudo rm -rf "${FS_MNT_POINT}/tmp/*" > /dev/null || true

    # clean any old/temp skywire work dir
    sudo rm -rdf "${FS_MNT_POINT}/root/.skywire" > /dev/null || true
}


# systemd units settings
function set_systemd_units() {
    # info
    info "Setting Systemd unit services"

    # local var
    local UNITSDIR=${FS_MNT_POINT}${SKYWIRE_DIR}/static/script/upgrade/data
    local SYSTEMDDIR=${FS_MNT_POINT}/etc/systemd/system/

    # copy only the respective unit
    sudo cp -f "${UNITSDIR}/skywire-manager.service" ${SYSTEMDDIR}
    sudo cp -f "${UNITSDIR}/skywire-node.service" ${SYSTEMDDIR}
    sudo cp -f ${ROOT}/static/skybian-config.service ${SYSTEMDDIR}

    # activate it
    info "Activating Systemd unit services."
    do_in_chroot systemctl enable skybian-config.service
}


# calculate md5, sha1 and compress
function calc_sums_compress() {
    # change to final dest
    cd "${FINAL_IMG_DIR}" ||
      (error "Failed to cd." && return 1)

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
        sha1sum -b ${img} > ${img}.sha1

        # compress
        info "Compressing, this will take a while..."
        local name=`echo ${img} | rev | cut -d '.' -f 2- | rev`
        tar -cvf ${name}.tar ${img}*
        xz -vzT0 ${name}.tar
    done
}


 # main exec block
 function main () {
    # test for needed tools
    tool_test

    # create output folder and it's structure
    create_folders

    # erase final images if there
    warn "Cleaning final images directory"
    rm -f "${FINAL_IMG_DIR}/*" &> /dev/null || true

    # download resources
    get_all

    # prepares and mounts base image
    prepare_base_image

    # copy downloads/bins to root fs
    copy_to_img

    # setup chroot
    enable_chroot

    # fixed for armbian defaults
    fix_armian_defaults

    # setup the systemd unit to start the services
    set_systemd_units

    # disable chroot
    #disable_chroot

    # clean
    #clean_image

    # build manager image
    #build_disk

    # all good signal
    info "Done with the image creation"
 }

# # executions depends on the parameters passed
# if [ "$1" == "-p" ] ; then
#     # ok, packing the image if there
#
#     # test for needed tools
#     tool_test
#
#     # create output folder and it's structure
#     create_folders
#
#     # just pack an already created image
#     calc_sums_compress
# else
#     # build the image
#     main
# fi
