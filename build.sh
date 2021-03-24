#!/usr/bin/env bash

# This is the main script to build the Skybian OS for Skycoin Official and Raspberry Pi miners.
#
# Author: evanlinjin@github.com, @evanlinjin in Telegram
# Modified by: asxtree@github.com, @asxtree in Telegram
# Skycoin / Rudi team
#

# load env variables.
# shellcheck source=./build.conf
source "$(pwd)/build.conf"

## Variables.

# Needed tools to run this script, space separated
# On arch/manjaro, the qemu-aarch64-static dependency is satisfied by installing the 'qemu-arm-static' AUR package.
NEEDED_TOOLS="rsync wget 7z cut awk sha256sum gzip tar e2fsck losetup resize2fs truncate sfdisk qemu-aarch64-static qemu-arm-static go"

# Image related variables.
OS_IMG_XZ=""
OS_IMG=""
OS_VERSION=""
OS_KERNEL_VERSION=""

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
    # Output directory.
    ## For Orange Pi Prime the output directory will be output-prime
    if [ ${BOARD} == PRIME ] ; then
	    PARTS_DIR=${ROOT}/output-prime/parts
      IMAGE_DIR=${ROOT}/output-prime/image
      FS_MNT_POINT=${ROOT}/output-prime/mnt
      FINAL_IMG_DIR=${ROOT}/output-prime/final
    ## For Orange Pi 3 the output directory will be output-opi3
    elif [ ${BOARD} == OPI3 ] ; then
      PARTS_DIR=${ROOT}/output-opi3/parts
      IMAGE_DIR=${ROOT}/output-opi3/image
      FS_MNT_POINT=${ROOT}/output-opi3/mnt
      FINAL_IMG_DIR=${ROOT}/output-opi3/final
    ## For Raspberry Pi the output directory will be output-rpi
    elif [ ${BOARD} == RPI ] ; then
      PARTS_DIR=${ROOT}/output-rpi/parts
      IMAGE_DIR=${ROOT}/output-rpi/image
      FS_MNT_POINT=${ROOT}/output-rpi/mnt
      FINAL_IMG_DIR=${ROOT}/output-rpi/final
    fi

    # Base image location: we will work with partitions.
    BASE_IMG=${IMAGE_DIR}/base_image

    # Download directories.
    PARTS_OS_DIR=${PARTS_DIR}/OS
    PARTS_SKYWIRE_DIR=${PARTS_DIR}/skywire
    PARTS_TOOLS_DIR=${PARTS_DIR}/tools

    # output-x [main folder]
    #   /final [this will be the final images dir]
    #   /parts [all thing we download from the internet]
    #   /mnt [to mount resources, like img fs, etc]
    #   /image [all image processing goes here]

    info "Creating output folder structure..."
    mkdir -p "$FINAL_IMG_DIR"
    mkdir -p "$FS_MNT_POINT"
    mkdir -p "$PARTS_DIR" "$PARTS_OS_DIR" "$PARTS_SKYWIRE_DIR" "$PARTS_TOOLS_DIR"
    mkdir -p "$IMAGE_DIR"

    info "Done!"
}

# Get tools to configure skyconf
get_tools()
{
  local _src="$ROOT/cmd/skyconf/skyconf.go"
  local _out="$PARTS_TOOLS_DIR/skyconf"

  info "Building skyconf..."
  info "_src=$_src"
  info "_out=$_out"

  if [ ${BOARD} == PRIME ] || [ ${BOARD} == OPI3 ] ; then
	  env GOOS=linux GOARCH=arm64 GOARM=7 go build -o "$_out" -v "$_src" || return 1
  elif [ ${BOARD} == RPI ] ; then
    env GOOS=linux GOARCH=arm GOARM=7 go build -o "$_out" -v "$_src" || return 1
  fi

  info "Done!"
}

# Get skywire
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

  info "Cleaning..."
  rm -rf "${PARTS_SKYWIRE_DIR}/bin/README.md" "${PARTS_SKYWIRE_DIR}/bin/CHANGELOG.md"  || return 1

  info "Done!"
}

get_skywire_rpi()
{
  local _DST=${PARTS_SKYWIRE_DIR}/skywire.tar.gz # Download destination file name.

  if [ ! -f "${_DST}" ] ; then
      notice "Downloading package from ${SKYWIRE_DOWNLOAD_URL_RPI} to ${_DST}..."
      wget -c "${SKYWIRE_DOWNLOAD_URL_RPI}" -O "${_DST}" || return 1
  else
      info "Reusing package in ${_DST}"
  fi

  info "Extracting package..."
  mkdir "${PARTS_SKYWIRE_DIR}/bin"
  tar xvzf "${_DST}" -C "${PARTS_SKYWIRE_DIR}/bin" || return 1

  info "Cleaning..."
  rm -rf "${PARTS_SKYWIRE_DIR}/bin/README.md" "${PARTS_SKYWIRE_DIR}/bin/CHANGELOG.md"  || return 1

  info "Done!"
}

# Download function for OS image of each board type
download_os()
{
  if [ ${BOARD} == PRIME ] ; then
	  info "Downloading image from ${ARMBIAN_DOWNLOAD_URL}..."
    wget -c "${ARMBIAN_DOWNLOAD_URL}" ||
      (error "Image download failed." && return 1)

    info "Downloading checksum from ${ARMBIAN_DOWNLOAD_URL}.sha..."
    wget -c "${ARMBIAN_DOWNLOAD_URL}.sha" ||
      (error "Checksum download failed." && return 1)
  elif [ ${BOARD} == OPI3 ] ; then
	  info "Downloading image from ${ARMBIAN_DOWNLOAD_URL_OPI3}..."
    wget -c "${ARMBIAN_DOWNLOAD_URL_OPI3}" ||
      (error "Image download failed." && return 1)

    info "Downloading checksum from ${ARMBIAN_DOWNLOAD_URL_OPI3}.sha..."
    wget -c "${ARMBIAN_DOWNLOAD_URL_OPI3}.sha" ||
      (error "Checksum download failed." && return 1)
  elif [ ${BOARD} == RPI ] ; then
    info "Downloading image from ${RASPBIAN_DOWNLOAD_URL} to ${_DST} ..."
    wget -c "${RASPBIAN_DOWNLOAD_URL}" ||
      (error "Download failed." && return 1)

    info "Downloading checksum from ${RASPBIAN_DOWNLOAD_URL}.sha..."
    wget -c "${RASPBIAN_DOWNLOAD_URL}.sha256" ||
      (error "Checksum download failed." && return 1)
  fi
}

# Get the latest ARMBIAN image for Orange Pi Prime
get_armbian()
{

  # change to dest dir
  cd "${PARTS_OS_DIR}" ||
    (error "Failed to cd." && return 1)

  local OS_IMG_XZ="$(ls Armbian*img.xz || true)"

  # user info
  info "Getting Armbian image, clearing dest dir first."

  # test if we have a file in there
  if [ -r "${OS_IMG_XZ}" ] ; then

      # todo: doesn't seem to work, always downloads the image
      # todo: download checksum separately, and use it to validate local copy

      # use already downloaded image file
      notice "Reusing already downloaded file"
  else
      # no image in there, must download
      info "No cached image, downloading.."

      # download it
      download_os

      local OS_IMG_XZ="$(ls Armbian*img.xz || true)"
  fi

  # extract and check it's integrity
  info "Armbian file to process is '${OS_IMG_XZ}'."

  # check integrity
  info "Testing image integrity..."
  if ! $(command -v sha256sum) -c --status -- *.sha ; then
      error "Integrity of the image is compromised, re-run the script to get it right."
      rm -- armbian *txt *sha *xz &> /dev/null || true
      exit 1
  fi

  # check if extracted image is in there to save time
  if [ -n "$(ls Armbian*.img || true)" ] ; then
      # image already extracted nothing to do
      notice "Armbian image already extracted"
  else
      # extract armbian
      info "Extracting image..."
      if ! 7z e "${OS_IMG_XZ}" ; then
          error "Extracting failed, file is corrupt? Re-run the script to get it right."
          rm "${OS_IMG_XZ}" &> /dev/null || true
          exit 1
      fi
  fi

  # get image filename
  OS_IMG=$(ls Armbian*.img || true)

  # imge integrity
  info "Image integrity assured via sha256sum."
  notice "Final image file is ${OS_IMG}"

  # get version & kernel version info
  OS_VERSION=$(echo "${OS_IMG}" | awk -F '_' '{ print $2 }')
  OS_KERNEL_VERSION=$(echo "${OS_IMG}" | awk -F '_' '{ print $6 }' | rev | cut -d '.' -f2- | rev)

  # info to the user
  notice "Armbian version: ${OS_VERSION}"
  notice "Armbian kernel version: ${OS_KERNEL_VERSION}"
}

# Get the latest RASPBIAN image for Orange Pi Prime
get_raspbian()
{
  # change to dest dir
  cd "${PARTS_OS_DIR}" ||
    (error "Failed to cd." && return 1)

    local OS_IMG_XZ=$(ls *raspios*.zip || true)

  # user info
  info "Getting Raspbian image, clearing dest dir first."

  # test if we have a file in there
  if [ -r "${OS_IMG_XZ}" ] ; then

    # use already downloaded image file
    notice "Reusing already downloaded file"
  else
    # no image in there, must download
    info "No cached image, downloading.."

    # download it
    download_os
  fi

  local OS_IMG_XZ=$(ls *raspios*.zip || true)

  # extract and check it's integrity
  info "Raspbian file to process is '${OS_IMG_XZ}'."

  # check integrity
  info "Testing image integrity..."
    if ! $(command -v sha256sum) -c --status -- *.sha256 ; then
        error "Integrity of the image is compromised, re-run the script to get it right."
        rm -- *img *txt *sha *7z &> /dev/null || true
        exit 1
    fi

    # check if extracted image is in there to save time
    if [ -n "$(ls *rasp*.img || true)" ] ; then
        # image already extracted nothing to do
        notice "Raspbian image already extracted"
    else
        # extract raspbian
        info "Extracting image..."
        if ! 7z e "${OS_IMG_XZ}" ; then
            error "Extracting failed, file is corrupt? Re-run the script to get it right."
            rm "${OS_IMG_XZ}" &> /dev/null || true
            exit 1
        fi
    fi

  # get image filename
  OS_IMG=$(ls *rasp*.img || true)

  # imge integrity
  info "Image integrity assured via sha256sum."
  notice "Final image file is ${OS_IMG}"
}

get_all_official()
{
  get_skywire || return 1
  get_armbian || return 1
  get_tools || return 1
}

get_all_rpi()
{
  get_skywire_rpi || return 1
  get_raspbian || return 1
  get_tools || return 1
}

# enable ssh, hdmi and UART on raspbian
enable_ssh()
{
	info "Mounting /boot"
	sudo mount -o loop,offset=4194304 "${PARTS_DIR}/OS/${OS_IMG}" "${FS_MNT_POINT}"
 
	info "Enabling UART"
	sudo sed -i '/^#dtoverlay=vc4-fkms-v3d.*/a enable_uart=1' "${FS_MNT_POINT}/config.txt"
 
	info "Enabling HDMI"
	sudo sed -i 's/#hdmi_force_hotplug=1/hdmi_force_hotplug=1/' "${FS_MNT_POINT}/config.txt"
 
	info "Enabling SSH"
	sudo touch "${FS_MNT_POINT}/SSH.txt"
 
	info "Unmounting /boot"
	sudo umount "${FS_MNT_POINT}"
}

# setup the rootfs to a loop device
setup_loop()
{
  if [ ${BOARD} == PRIME ] || [ ${BOARD} == OPI3 ] ; then
	    # find free loop device
      IMG_LOOP=$(sudo losetup -f)

      # find image sector size (if not user-defined)
      [[ -z $IMG_SECTOR ]] &&
        IMG_SECTOR=$(fdisk -l "${BASE_IMG}" | grep "Sector size" | grep -o '[0-9]*' | head -1)

      # find image offset (if not user-defined)
      [[ -z "${IMG_OFFSET}" ]] &&
        IMG_OFFSET=$(fdisk -l "${BASE_IMG}" | tail -1 | awk '{print $2}')

      # setup loop device for root fs
      info "Map root fs to loop device '${IMG_LOOP}': sector size '${IMG_SECTOR}', image offset '${IMG_OFFSET}' ..."
      sudo losetup -o "$((IMG_OFFSET * IMG_SECTOR))" "${IMG_LOOP}" "${BASE_IMG}"
  elif [ ${BOARD} == RPI ] ; then
      # find free loop device
      IMG_LOOP=$(sudo losetup -f)

      # find image sector size (if not user-defined)
      [[ -z $IMG_SECTOR ]] &&
        IMG_SECTOR=$(fdisk -l "${BASE_IMG}" | grep "Sector size" | grep -o '[0-9]*' | head -1)

      # find image offset (if not user-defined)
      [[ -z "${RPI_IMG_OFFSET}" ]] &&
        RPI_IMG_OFFSET=$(fdisk -l "${BASE_IMG}" | tail -1 | awk '{print $2}')

      # setup loop device for root fs
      info "Map root fs to loop device '${IMG_LOOP}': sector size '${IMG_SECTOR}', image offset '${RPI_IMG_OFFSET}' ..."
      sudo losetup -o "$((RPI_IMG_OFFSET * IMG_SECTOR))" "${IMG_LOOP}" "${BASE_IMG}"
  fi
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
prepare_base_image_official()
{
  # Armbian image is tight packed, and we need room for adding our
  # bins, apps & configs, so we will make it bigger

  # clean
  info "Cleaning..."
  rm -rf "${IMAGE_DIR:?}/*" &> /dev/null || true

  # copy armbian image to base image location
  info "Copying base image..."
  cp "${PARTS_DIR}/OS/${OS_IMG}" "${BASE_IMG}" || return 1

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

# Prepares base image.
# - Copy raspbian img to base img loc
# - Prepare loop device
# - Mount loop device
prepare_base_image_rpi()
{
  # Raspbian has enough room for adding our
  # bins, apps & configs, making it bigger may result in kernel panic

  # clean
  info "Cleaning..."
  rm -rf "${IMAGE_DIR:?}/*" &> /dev/null || true

  # copy raspbian image to base image location
  info "Copying base image..."
  cp "${PARTS_DIR}/OS/${OS_IMG}" "${BASE_IMG}" || return 1

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

  # Copy skywire tools
  info "Copying skywire tools..."
  sudo cp -rf "$PARTS_TOOLS_DIR"/* "$FS_MNT_POINT"/usr/bin/ || return 1

  # Copy skywire bins
	sudo cp "$ROOT"/static/skybian-firstrun "$FS_MNT_POINT"/usr/bin/ || return 1
  sudo chmod +x "$FS_MNT_POINT"/usr/bin/skybian-firstrun || return 1

  if [ ${BOARD} == PRIME ] || [ ${BOARD} == OPI3 ] ; then
    
    # Copy scripts
    info "Copying disable user creation script..."
    sudo cp -f "${ROOT}/static/armbian-check-first-login.sh" "${FS_MNT_POINT}/etc/profile.d/armbian-check-first-login.sh" || return 1
    sudo chmod +x "${FS_MNT_POINT}/etc/profile.d/armbian-check-first-login.sh" || return 1
    info "Copying headers (so OS presents itself as Skybian)..."
    sudo cp "${ROOT}/static/10-skybian-header" "${FS_MNT_POINT}/etc/update-motd.d/" || return 1
    sudo chmod +x "${FS_MNT_POINT}/etc/update-motd.d/10-skybian-header" || return 1
    sudo cp -f "${ROOT}/static/armbian-motd" "${FS_MNT_POINT}/etc/default" || return 1

    # Copy chroot scripts to root fs
    info "Copying chroot script..."
    sudo cp "${ROOT}/static/chroot_commands.sh" "${FS_MNT_POINT}/tmp" || return 1
    sudo chmod +x "${FS_MNT_POINT}/tmp/chroot_commands.sh" || return 1
  elif [ ${BOARD} == RPI ] ; then
    # Copy skywire bins
	  sudo cp "$ROOT"/static/skyraspbian-firstrun "$FS_MNT_POINT"/usr/bin/ || return 1
    sudo chmod +x "$FS_MNT_POINT"/usr/bin/skyraspbian-firstrun || return 1

    # Copy scripts
    info "Copying headers (so OS presents itself as Skybian)..."
    sudo cp "${ROOT}/static/10-skyraspbian-header" "${FS_MNT_POINT}/etc/update-motd.d/" || return 1
    sudo chmod +x "${FS_MNT_POINT}/etc/update-motd.d/10-skyraspbian-header" || return 1
    sudo rm -rf "${FS_MNT_POINT}/etc/10-uname" || return 1
    sudo rm -rf "${FS_MNT_POINT}/etc/motd" || return 1

    # Copy chroot scripts to root fs
    info "Copying chroot script..."
    sudo cp "${ROOT}/static/chroot_commands_skyraspbian.sh" "${FS_MNT_POINT}/tmp" || return 1
    sudo chmod +x "${FS_MNT_POINT}/tmp/chroot_commands_skyraspbian.sh" || return 1
  fi

  # Copy systemd units
  info "Copying systemd unit services..."
  local SYSTEMD_DIR=${FS_MNT_POINT}/etc/systemd/system/
  sudo cp -f "${ROOT}"/static/*.service "${SYSTEMD_DIR}" || return 1

  info "Done!"
}

# fix some defaults on armbian and raspbian to skywire defaults
chroot_actions()
{
  # enable chroot
  info "Seting up chroot jail..."

  if [ ${BOARD} == PRIME ] || [ ${BOARD} == OPI3 ] ; then
	  sudo cp "$(command -v qemu-aarch64-static)" "${FS_MNT_POINT}/usr/bin/"
  elif [ ${BOARD} == RPI ] ; then
    sudo cp "$(command -v qemu-arm-static)" "${FS_MNT_POINT}/usr/bin/"
  fi

  sudo mount -t sysfs none "${FS_MNT_POINT}/sys"
  sudo mount -t proc none "${FS_MNT_POINT}/proc"
  sudo mount --bind /dev "${FS_MNT_POINT}/dev"
  sudo mount --bind /dev/pts "${FS_MNT_POINT}/dev/pts"

  if [ ${BOARD} == PRIME ] || [ ${BOARD} == OPI3 ] ; then
	  # Executing chroot script
    info "Executing chroot script..."
    sudo chroot "${FS_MNT_POINT}" /tmp/chroot_commands.sh
  elif [ ${BOARD} == RPI ] ; then
    # ld.so.preload fix
    sed -i 's/^/#/g' "${FS_MNT_POINT}/etc/ld.so.preload"

    # Executing chroot script
    info "Executing chroot script..."
    sudo chroot "${FS_MNT_POINT}" /tmp/chroot_commands_skyraspbian.sh

    # revert ld.so.preload fix
    sed -i 's/^#//g' "${FS_MNT_POINT}/etc/ld.so.preload"
  fi

	# Disable chroot
  info "Disabling the chroot jail..."

  if [ ${BOARD} == PRIME ] || [ ${BOARD} == OPI3 ] ; then
    sudo rm "${FS_MNT_POINT}/usr/bin/qemu-aarch64-static"
  elif [ ${BOARD} == RPI ] ; then
    sudo rm "${FS_MNT_POINT}/usr/bin/qemu-arm-static"
  fi
    
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
  if [ ${BOARD} == PRIME ] ; then
  # output prime skybian image
	  FINAL_IMG_DIR="${ROOT}/output-prime/final"
  elif [ ${BOARD} == OPI3 ] ; then
  # output opi3 skybian image
	  FINAL_IMG_DIR="${ROOT}/output-opi3/final"
  elif [ ${BOARD} == RPI ] ; then
  # output skyraspbian image
    FINAL_IMG_DIR="${ROOT}/output-rpi/final"
  fi
  
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
      tar -cvzf "${name}.tar.gz" "${img}"*
    done

    cd "${ROOT}" || return 1
    info "Done!"
  done
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
    PARTS_OS_DIR="${ROOT}/output-prime/parts/OS ${ROOT}/output-opi3/parts/OS ${ROOT}/output-rpi/parts/OS"
    for i in ${PARTS_OS_DIR} ; do

      cd "${i}" && find . -type f ! -name '*.xz' -delete

    done

    PARTS_SKYWIRE_DIR="${ROOT}/output-prime/parts/skywire ${ROOT}/output-opi3/parts/skywire ${ROOT}/output-rpi/parts/skywire"
    for j in ${PARTS_SKYWIRE_DIR} ; do

      cd "${j}" && find . -type f ! -name '*.tar.gz' -delete && rm -rf bin
    
    done

    FINAL_IMG_DIR="${ROOT}/output-prime/final ${ROOT}/output-opi3/final ${ROOT}/output-rpi/final" 
    for k in ${FINAL_IMG_DIR} ; do

      cd "${k}" && find . -type f ! -name '*.tar.gz' -delete
    
    done

    BASE_IMG="${ROOT}/output-prime/image/base_image ${ROOT}/output-opi3/image/base_image ${ROOT}/output-rpi/image/base_image"
    for l in ${BASE_IMG} ; do

      rm -v "${l}"

    done

  # cd to root.
  cd "${ROOT}" || return 1
}

# build disk
build_disk()
{
  # move to correct dir
  cd "${IMAGE_DIR}" || return 1

  # determine final name
  if [ ${BOARD} == PRIME ] ; then
	  local NAME="Skybian-prime-${VERSION}"
  elif [ ${BOARD} == OPI3 ] ; then
    local NAME="Skybian-opi3-${VERSION}"
  elif [ ${BOARD} == RPI ] ; then
    local NAME="Skybian-rpi-${VERSION}"
  fi

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

build_prime()
{
    #BOARD=PRIME
    # test for needed tools
    tool_test || return 1

    # create output folder and it's structure
    create_folders || return 1

    # erase final images if there
    warn "Cleaning final images directory"
    rm -f "$FINAL_IMG_DIR"/* &> /dev/null || true

    # download resources
    get_all_official || return 1

    # prepares and mounts base image
    prepare_base_image_official || return 1

    # copy parts to root fs
    copy_to_img || return 1

    # setup chroot
    chroot_actions || return 1

    # build manager image
    build_disk || return 1

    # all good signal
    info "Success!"
}

build_opi3()
{
    #BOARD=OPI3
    # test for needed tools
    tool_test || return 1

    # create output folder and it's structure
    create_folders || return 1

    # erase final images if there
    warn "Cleaning final images directory"
    rm -f "$FINAL_IMG_DIR"/* &> /dev/null || true

    # download resources
    get_all_official || return 1

    # prepares and mounts base image
    prepare_base_image_official || return 1

    # copy parts to root fs
    copy_to_img || return 1

    # setup chroot
    chroot_actions || return 1

    # build manager image
    build_disk || return 1

    # all good signal
    info "Success!"
}

build_rpi()
{
    #BOARD=RPI
    # test for needed tools
    tool_test || return 1

    # create output folder and it's structure
    create_folders || return 1

    # erase final images if there
    warn "Cleaning final images directory"
    rm -f "$FINAL_IMG_DIR"/* &> /dev/null || true

    # download resources
    get_all_rpi || return 1

    # enable ssh, hdmi and uart
	  enable_ssh || return 1

    # prepares and mounts base image
    prepare_base_image_rpi || return 1

    # copy parts to root fs
    copy_to_img || return 1

    # setup chroot
    chroot_actions || return 1

    # build manager image
    build_disk || return 1

    # all good signal
    info "Success!"
}

# main build block
main_build()
{
    if [ ${BOARD} == PRIME ] ; then
    # build prime skybian image
	    build_prime || return 1
    elif [ ${BOARD} == OPI3 ] ; then
    # build opi3 skybian image
	    build_opi3 || return 1
    elif [ ${BOARD} == RPI ] ; then
    # build skyraspbian image
      build_rpi || return 1
    fi

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
