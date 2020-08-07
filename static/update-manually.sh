#!/usr/bin/env bash

if [ "$#" -ne 1 ]; then
    printf "Usage:\n\t%s version\n" "$0"
    exit 1
fi

OS="linux"
ARCH="arm"
VERSION=$1
BASE_NAME="skywire-${VERSION}-${OS}-${ARCH}"
FOLDER_NAME="${BASE_NAME}"
ARCHIVE_NAME="${BASE_NAME}.tar.gz"
SKYWIRE_URL="https://github.com/skycoin/skywire/releases/download/${VERSION}/${ARCHIVE_NAME}"
BINARY_NAMES="skywire-visor hypervisor"

rm -f "./${ARCHIVE_NAME}"
wget -O "$ARCHIVE_NAME" "$SKYWIRE_URL"
rm -rf "./${FOLDER_NAME}"

mkdir "./${FOLDER_NAME}"
tar -xf "./${ARCHIVE_NAME}" -C "./${FOLDER_NAME}"

for BINARY_NAME in $BINARY_NAMES
do
  if [ "$BINARY_NAME" == "hypervisor" ]; then
    rm -f "/usr/bin/skywire-hypervisor"
    cp "./${FOLDER_NAME}/${BINARY_NAME}" "/usr/bin/skywire-hypervisor"
  else
    rm -f "/usr/bin/${BINARY_NAME}"
    cp "./${FOLDER_NAME}/${BINARY_NAME}" "/usr/bin/${BINARY_NAME}"
  fi
done

rm -rf "./${FOLDER_NAME}"
rm -f "./${ARCHIVE_NAME}"

reboot
