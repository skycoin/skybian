#!/usr/bin/env bash

# This is the main script to build the Skybian OS for Skycoin miners.
#
# Author: evanlinjin@github.com, @evanlinjin in telegram
# Skycoin / Rudi team
#

# load env variables.
# shellcheck source=./build.conf
source "$(pwd)/build.conf"

## Variables.

# Needed tools to run this script, space separated
# On arch/manjaro, the qemu-aarch64-static dependency is satisfied by installing the 'qemu-arm-static' AUR package.
NEEDED_TOOLS="rsync wget 7z cut awk sha256sum gzip tar e2fsck losetup resize2fs truncate sfdisk qemu-aarch64-static go"

# Output directory.
PARTS_DIR=${ROOT}/output/parts
IMAGE_DIR=${ROOT}/output/image
FS_MNT_POINT=${ROOT}/output/mnt
FINAL_IMG_DIR=${ROOT}/output/final

# Base image location: we will work with partitions.
BASE_IMG=${IMAGE_DIR}/base_image

# Download directories.
PARTS_ARMBIAN_DIR=${PARTS_DIR}/armbian
PARTS_SKYWIRE_DIR=${PARTS_DIR}/skywire
PARTS_TOOLS_DIR=${PARTS_DIR}/tools

# Image related variables.
ARMBIAN_IMG_7z=""
ARMBIAN_IMG=""
ARMBIAN_VERSION=""
ARMBIAN_KERNEL_VERSION=""

# Loop device.
IMG_LOOP="" # free loop device to be used.


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
-c              Clean everything (in case of failure)

No parameters means image creation without checksum and packing

To know more about the script work, please refers to the file
called Building_Skybian.md on this folder.

Latest code can be found on https://github.com/skycoin/skybian

EOF

    exit 0
fi

# for logging

info()
{
    printf '\033[0;32m[ INFO ]\033[0m %s\n' "${FUNCNAME[1]}: ${1}"
}

notice()
{
    printf '\033[0;34m[ NOTI ]\033[0m %s\n' "${FUNCNAME[1]}: ${1}"
}

warn()
{
    printf '\033[0;33m[ WARN ]\033[0m %s\n' "${FUNCNAME[1]}: ${1}"
}

error()
{
    printf '\033[0;31m[ ERRO ]\033[0m %s\n' "${FUNCNAME[1]}: ${1}"
}

# Test the needed tools to build the script, iterate over the needed tools
# and warn if one is missing, exit 1 is generated
tool_test()
{
    # info
    info "Testing the workspace for needed tools"
    for t in ${NEEDED_TOOLS} ; do
        if [ -z "$(command -v "${t}")" ] ; then
            # not found
            error "Need tool '${t}' and it's not found on the system."
            error "Please install it and run the build script again."
            return 1
        fi
    done

    # info
    info "All tools are installed, going forward."
}

# Build the output/work folder structure, this is excluded from the git
# tracking on purpose: this will generate GB of data on each push
create_folders()
{
    # output [main folder]
    #   /final [this will be the final images dir]
    #   /parts [all thing we download from the internet]
    #   /mnt [to mount resources, like img fs, etc]
    #   /image [all image processing goes here]

    info "Creating output folder structure..."
    mkdir -p "$FINAL_IMG_DIR"
    mkdir -p "$FS_MNT_POINT"
    mkdir -p "$PARTS_DIR" "$PARTS_ARMBIAN_DIR" "$PARTS_SKYWIRE_DIR" "$PARTS_TOOLS_DIR"
    mkdir -p "$IMAGE_DIR"

    info "Done!"
}

get_tools()
{
  local _src="$ROOT/cmd/skyconf/skyconf.go"
  local _out="$PARTS_TOOLS_DIR/skyconf"

  info "Building skyconf..."
  info "_src=$_src"
  info "_out=$_out"
  env GOOS=linux GOARCH=arm64 GOARM=7 go build -o "$_out" -v "$_src" || return 1

  info "Done!"
}

get_skywire()
{
  local _DST=${PARTS_SKYWIRE_DIR}/skywire.tar.gz # Download destination file name.

  if [ ! -f "${_DST}" ] ; then
      notice "Downloading package from ${SKYWIRE_DOWNLOAD_URL} to ${_DST}..."
      wget -c "${SKYWIRE_DOWNLOAD_URL}" -O "${_DST}" || return 1
  else
      info "Reusing package in ${_DST}"
  fi

  info "Extracting package..."
  mkdir "${PARTS_SKYWIRE_DIR}/bin"
  tar xvzf "${_DST}" -C "${PARTS_SKYWIRE_DIR}/bin" || return 1

  info "Renaming 'hypervisor' to 'skywire-hypervisor'..."
  mv "${PARTS_SKYWIRE_DIR}/bin/hypervisor" "${PARTS_SKYWIRE_DIR}/bin/skywire-hypervisor" || 0

  info "Cleaning..."
  rm -rf "${PARTS_SKYWIRE_DIR}/bin/README.md" "${PARTS_SKYWIRE_DIR}/bin/CHANGELOG.md"  || return 1

  info "Done!"
}

download_armbian()
{
  local _DST=${PARTS_ARMBIAN_DIR}/armbian.7z # Download destination file name.

  info "Downloading image from ${ARMBIAN_DOWNLOAD_URL} to ${_DST} ..."
  wget -c "${ARMBIAN_DOWNLOAD_URL}" -O "${_DST}" ||
    (error "Download failed." && return 1)
}

# Get the latest ARMBIAN image for Orange Pi Prime
get_armbian()
{
  local ARMBIAN_IMG_7z="armbian.7z"

    # change to dest dir
    cd "${PARTS_ARMBIAN_DIR}" ||
      (error "Failed to cd." && return 1)

    # user info
    info "Getting Armbian image, clearing dest dir first."

    # test if we have a file in there
    if [ -r armbian.7z ] ; then

        # use already downloaded image file
        notice "Reusing already downloaded file"
    else
        # no image in there, must download
        info "No cached image, downloading.."

        # download it
        download_armbian
    fi

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

get_all()
{
  get_armbian || return 1
  get_skywire || return 1
  get_tools || return 1
}


# setup the rootfs to a loop device
setup_loop()
{
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
rootfs_check()
{
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
prepare_base_image()
{
  # Armbian image is tight packed, and we need room for adding our
  # bins, apps & configs, so we will make it bigger

  # clean
  info "Cleaning..."
  rm -rf "${IMAGE_DIR:?}/*" &> /dev/null || true

  # copy armbian image to base image location
  info "Copying base image..."
  cp "${PARTS_DIR}/armbian/${ARMBIAN_IMG}" "${BASE_IMG}" || return 1

  # Add space to base image
  if [[ "$BASE_IMG_ADDED_SPACE" -ne "0" ]]; then
    info "Adding ${BASE_IMG_ADDED_SPACE}MB of extra space to the image..."
    truncate -s +"${BASE_IMG_ADDED_SPACE}M" "${BASE_IMG}"
    echo ", +" | sfdisk -N1 "${BASE_IMG}" # add free space to the part 1 (sfdisk way)
  fi

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

copy_to_img()
{
  # Copy skywire bins
  info "Copying skywire bins..."
  sudo cp -rf "$PARTS_SKYWIRE_DIR"/bin/* "$FS_MNT_POINT"/usr/bin/ || return 1
  sudo cp "$ROOT"/static/skybian-firstrun "$FS_MNT_POINT"/usr/bin/ || return 1
  sudo chmod +x "$FS_MNT_POINT"/usr/bin/skybian-firstrun || return 1

  # Copy skywire tools
  info "Copying skywire tools..."
  sudo cp -rf "$PARTS_TOOLS_DIR"/* "$FS_MNT_POINT"/usr/bin/ || return 1

  # Copy scripts
  info "Copying disable user creation script..."
  sudo cp -f "${ROOT}/static/armbian-check-first-login.sh" "${FS_MNT_POINT}/etc/profile.d/armbian-check-first-login.sh" || return 1
  sudo chmod +x "${FS_MNT_POINT}/etc/profile.d/armbian-check-first-login.sh" || return 1
  info "Copying headers (so OS presents itself as Skybian)..."
  sudo cp "${ROOT}/static/10-skybian-header" "${FS_MNT_POINT}/etc/update-motd.d/" || return 1
  sudo chmod +x "${FS_MNT_POINT}/etc/update-motd.d/10-skybian-header" || return 1
  sudo cp -f "${ROOT}/static/armbian-motd" "${FS_MNT_POINT}/etc/default" || return 1

  # Copy systemd units
  info "Copying systemd unit services..."
  local SYSTEMD_DIR=${FS_MNT_POINT}/etc/systemd/system/
  sudo cp -f "${ROOT}"/static/*.service "${SYSTEMD_DIR}" || return 1

  info "Done!"
}

# fix some defaults on armbian to skywire defaults
chroot_actions()
{
  # copy chroot scripts to root fs
  info "Copying chroot script..."
  sudo cp "${ROOT}/static/chroot_commands.sh" "${FS_MNT_POINT}/tmp" || return 1
  sudo chmod +x "${FS_MNT_POINT}/tmp/chroot_commands.sh" || return 1

  # enable chroot
  info "Seting up chroot jail..."
  sudo cp "$(command -v qemu-aarch64-static)" "${FS_MNT_POINT}/usr/bin/"
  sudo mount -t sysfs none "${FS_MNT_POINT}/sys"
  sudo mount -t proc none "${FS_MNT_POINT}/proc"
  sudo mount --bind /dev "${FS_MNT_POINT}/dev"
  sudo mount --bind /dev/pts "${FS_MNT_POINT}/dev/pts"

  # Executing chroot script
  info "Executing chroot script..."
  sudo chroot "${FS_MNT_POINT}" /tmp/chroot_commands.sh

  # disable chroot
  info "Disabling the chroot jail..."
  sudo rm "${FS_MNT_POINT}/usr/bin/qemu-aarch64-static"
  sudo umount "${FS_MNT_POINT}/sys"
  sudo umount "${FS_MNT_POINT}/proc"
  sudo umount "${FS_MNT_POINT}/dev/pts"
  sudo umount "${FS_MNT_POINT}/dev"

  # clean /tmp in root fs
  info "Cleaning..."
  sudo rm -rf "$FS_MNT_POINT"/tmp/* > /dev/null || true

  info "Done!"
}

# calculate md5, sha1 and compress
calc_sums_compress()
{
  # change to final dest
  cd "${FINAL_IMG_DIR}" ||
    (error "Failed to cd." && return 1)

  # info
  info "Calculating the md5sum for the image, this may take a while"

  # cycle for each one
  for img in $(find -- *.img -maxdepth 1 -print0 | xargs --null) ; do
    # MD5
    info "MD5 Sum for image: $img"
    md5sum -b "${img}" > "${img}.md5"

    # sha1
    info "SHA1 Sum for image: $img"
    sha1sum -b "${img}" > "${img}.sha1"

    # compress
    info "Compressing, this will take a while..."
    name=$(echo "${img}" | rev | cut -d '.' -f 2- | rev)
    tar -cvf "${name}.tar" "${img}"*
    xz -vzT0 "${name}.tar"
  done

  cd "${ROOT}" || return 1
  info "Done!"
}

clean_image()
{
  sudo umount "${FS_MNT_POINT}/sys"
  sudo umount "${FS_MNT_POINT}/proc"
  sudo umount "${FS_MNT_POINT}/dev/pts"
  sudo umount "${FS_MNT_POINT}/dev"

  sudo sync
  sudo umount "${FS_MNT_POINT}"

  sudo sync
  # only do so if IMG_LOOP is set
  [[ -n "${IMG_LOOP}" ]] && sudo losetup -d "${IMG_LOOP}"
}

clean_output_dir()
{
  # Clean parts.
  cd "${PARTS_ARMBIAN_DIR}" && find . -type f ! -name '*.7z' -delete
  cd "${PARTS_SKYWIRE_DIR}" && find . -type f ! -name '*.tar.gz' -delete && rm -rf bin
  cd "${FINAL_IMG_DIR}" && find . -type f ! -name '*.tar.xz' -delete

  # Rm base image.
  rm -v "${IMAGE_DIR}/base_image"

  # cd to root.
  cd "${ROOT}" || return 1
}

# build disk
build_disk()
{
  # move to correct dir
  cd "${IMAGE_DIR}" || return 1

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

# main build block
main_build()
{
    # test for needed tools
    tool_test || return 1

    # create output folder and it's structure
    create_folders || return 1

    # erase final images if there
    warn "Cleaning final images directory"
    rm -f "$FINAL_IMG_DIR"/* &> /dev/null || true

    # download resources
    get_all || return 1

    # prepares and mounts base image
    prepare_base_image || return 1

    # copy parts to root fs
    copy_to_img || return 1

    # setup chroot
    chroot_actions || return 1

    # build manager image
    build_disk || return 1

    # all good signal
    info "Success!"
}

main_clean()
{
  clean_output_dir
  clean_image || return 0
}

# clean exec block
main_package()
{
    tool_test || return 1
    #create_folders || return 1
    calc_sums_compress || return 1
    info "Success!"
}

case "$1" in
"-p")
    # Package image.
    main_package || (error "Failed." && exit 1)
    ;;
"-c")
    # Clean in case of failures.
    main_clean || (error "Failed." && exit 1)
    ;;
*)
    main_build || (error "Failed." && exit 1)
    ;;
 esac
