#!/bin/bash

# ROOT should be the base directory of this repository.
ROOT=$(pwd)

export CHROOT_DIR=$ROOT/integration/mnt

setup_chroot()
{
  teardown_chroot || return 1

  # Create chroot directory.
  rm -rf "$CHROOT_DIR" || return 1
  mkdir -p "$CHROOT_DIR"/{bin,usr/bin,etc,dev,tmp} || return 1

  # Copy libraries.
  # TODO(evanlinjin): Figure out a way to copy required binaries.
  cp -r /{lib,lib64} "$CHROOT_DIR" &> /dev/null
  cp -r /usr/{lib,lib64} "$CHROOT_DIR"/usr &> /dev/null

  # Copy binaries.
  cp -rv /bin/{bash,ls,mkdir,cat} "$CHROOT_DIR/bin" || return 1
  cp -rv /usr/bin/{bash,ls,mkdir,cat} "$CHROOT_DIR/usr/bin" &> /dev/null
}

teardown_chroot()
{
  sudo rm -rf "$CHROOT_DIR" || return 1
}

test_skyconf()
{
  setup_chroot || return 1

  cp -v "$ROOT/bin/skyconf" "$CHROOT_DIR/usr/bin" || return 1

  # Create mock device with MBR.
  mbr_dev="$CHROOT_DIR/dev/mmcblk0"
  touch "$mbr_dev" || return 1

  ## Test visor setup.
  echo "Testing visor config generation..."
  go run "$ROOT/integration/cmd/mock_mbr.go" -m=1 -of="$mbr_dev" || return 1
  sudo chroot "$CHROOT_DIR" /usr/bin/skyconf || return 1

  ## Test hypervisor setup.
  echo "Testing hypervisor config generation..."
  go run "$ROOT/integration/cmd/mock_mbr.go" -m=0 -of="$mbr_dev" || return 1
  sudo chroot "$CHROOT_DIR" /usr/bin/skyconf || return 1
}

# Magic starts here.

if ! test_skyconf; then
  teardown_chroot
  exit 1
fi

teardown_chroot
exit 0
