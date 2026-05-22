#!/bin/bash
# Build a bootable Arch Linux ARM (aarch64) image for the Orange Pi Prime.
# Run as root from this directory:  sudo ./build-image.sh
#
# Inputs (must be in the same directory):
#   - u-boot-sunxi-with-spl.bin      (extracted from Armbian)
#   - ArchLinuxARM-aarch64-latest.tar.gz
# Output:
#   - ArchLinuxARM-OrangePiPrime.img (raw image; flash with `dd` to SD card)
#
# Boot flow: BROM -> SPL at sector 16 -> U-Boot proper -> /boot/extlinux/extlinux.conf
#            -> /boot/Image + sun50i-h5-orangepi-prime.dtb + initramfs-linux.img -> Linux
# On first boot a oneshot service expands the root partition + fs to fill the SD card.

set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

UBOOT_BLOB="u-boot-sunxi-with-spl.bin"
ROOTFS_TAR="ArchLinuxARM-aarch64-latest.tar.gz"
OUT_IMG="ArchLinuxARM-OrangePiPrime.img"
MOUNT_DIR="$HERE/.mnt"
LOGFILE="$HERE/build.log"

# Mirror everything to build.log so we can review after the fact even if the
# terminal scrollback is gone.
: > "$LOGFILE"
exec > >(tee -a "$LOGFILE") 2>&1

FAILED=0
on_err() {
    local exit_code=$?
    local line=$1
    local cmd=$2
    FAILED=1
    {
        echo
        echo "################################################################"
        echo "# BUILD FAILED"
        echo "#   line:    $line"
        echo "#   exit:    $exit_code"
        echo "#   command: $cmd"
        echo "#   log:     $LOGFILE"
        echo "################################################################"
    } >&2
}
# -E propagates the ERR trap into functions, subshells, and command substitutions.
trap 'on_err "$LINENO" "$BASH_COMMAND"' ERR

# Sized to hold the ALARM aarch64 rootfs (~2150 MiB extracted, most of which
# is /usr/lib/firmware for hardware we don't have) + ext4 overhead + headroom.
# First-boot service grows the partition + ext4 to fill the SD card.
IMG_SIZE_MB=2700
PART_START_SECTOR=8192       # 4 MiB. Matches Armbian; leaves room for SPL+U-Boot.

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: must run as root (needs losetup/mount/mkfs)." >&2
    exit 1
fi

for f in "$UBOOT_BLOB" "$ROOTFS_TAR"; do
    [[ -f "$f" ]] || { echo "ERROR: missing $f in $HERE" >&2; exit 1; }
done

for cmd in losetup mkfs.ext4 tar partprobe dd sfdisk blkid mountpoint truncate; do
    command -v "$cmd" >/dev/null || { echo "ERROR: $cmd not found" >&2; exit 1; }
done

# Pre-flight: refuse to run on top of leftover state from a prior crashed run.
if mountpoint -q "$MOUNT_DIR" 2>/dev/null; then
    echo "ERROR: $MOUNT_DIR is already mounted. Run: sudo umount -R '$MOUNT_DIR'" >&2
    exit 1
fi
# If a previous run left a loop device bound to our image, detach it first.
if existing="$(losetup -j "$HERE/$OUT_IMG" 2>/dev/null | cut -d: -f1)" && [[ -n "$existing" ]]; then
    echo "==> Detaching stale loop device(s) from prior run: $existing"
    for dev in $existing; do losetup -d "$dev"; done
fi

LOOP=""
cleanup() {
    # Cleanup must not mask the original failure or itself trigger the ERR trap.
    set +e
    trap - ERR
    if mountpoint -q "$MOUNT_DIR" 2>/dev/null; then
        umount -R "$MOUNT_DIR"
    fi
    if [[ -n "$LOOP" ]] && losetup "$LOOP" >/dev/null 2>&1; then
        losetup -d "$LOOP"
    fi
    rmdir "$MOUNT_DIR" 2>/dev/null
    if [[ "$FAILED" -ne 0 ]]; then
        echo "Build aborted. Full log: $LOGFILE" >&2
    fi
    return 0
}
trap cleanup EXIT

echo "==> Creating ${IMG_SIZE_MB} MiB sparse image: $OUT_IMG"
rm -f "$OUT_IMG"
truncate -s "${IMG_SIZE_MB}M" "$OUT_IMG"

echo "==> Partitioning (MBR, single ext4 root starting at sector $PART_START_SECTOR)"
# Use sfdisk for precise sector control (parted's "1MiB" doesn't align to sector 8192).
sfdisk "$OUT_IMG" <<EOF
label: dos
unit: sectors

start=$PART_START_SECTOR, type=83, bootable
EOF

echo "==> Attaching loop device"
LOOP="$(losetup --show -fP "$OUT_IMG")"
partprobe "$LOOP"
PART="${LOOP}p1"
[[ -b "$PART" ]] || { echo "ERROR: partition device $PART did not appear" >&2; exit 1; }

echo "==> Formatting $PART as ext4"
# Disable metadata_csum_seed/orphan_file: older U-Boot ext4 drivers don't grok them.
# (Mainline U-Boot 2024+ is fine, but Armbian-extracted blob predates some defaults.)
mkfs.ext4 -F -L ALARM_ROOT -O '^metadata_csum_seed,^orphan_file' "$PART"

echo "==> Mounting and extracting rootfs (this takes a minute)"
mkdir -p "$MOUNT_DIR"
mount "$PART" "$MOUNT_DIR"
# Use GNU tar instead of bsdtar: libarchive 3.8.5 fails on a handful of /var
# entries in the current ALARM aarch64 tarball ("Failed to create dir 'var'").
# GNU tar handles them fine. --numeric-owner avoids mapping the tarball's UIDs
# (root=0, http=33, alarm=1000, _talkd=100, etc.) through the host's /etc/passwd.
# --xattrs + --acls preserve security.capability on binaries like ping.
tar --numeric-owner --xattrs --xattrs-include='*' --acls -xpf "$ROOTFS_TAR" -C "$MOUNT_DIR"
sync

echo "==> Writing /etc/fstab"
ROOT_UUID="$(blkid -s UUID -o value "$PART")"
cat > "$MOUNT_DIR/etc/fstab" <<EOF
# <file system>                            <dir> <type> <options>      <dump> <pass>
UUID=$ROOT_UUID                            /     ext4   defaults,noatime  0   1
EOF

echo "==> Writing /boot/extlinux/extlinux.conf"
mkdir -p "$MOUNT_DIR/boot/extlinux"
cat > "$MOUNT_DIR/boot/extlinux/extlinux.conf" <<'EOF'
DEFAULT alarm
TIMEOUT 10
PROMPT 0

LABEL alarm
    MENU LABEL Arch Linux ARM (Orange Pi Prime)
    LINUX /boot/Image
    FDT /boot/dtbs/allwinner/sun50i-h5-orangepi-prime.dtb
    INITRD /boot/initramfs-linux.img
    APPEND console=ttyS0,115200 console=tty1 root=LABEL=ALARM_ROOT rw rootwait
EOF

# Verify the kernel + dtb actually exist in the rootfs. Missing = unbootable, so fail hard.
missing=()
for f in /boot/Image /boot/dtbs/allwinner/sun50i-h5-orangepi-prime.dtb /boot/initramfs-linux.img; do
    [[ -e "$MOUNT_DIR$f" ]] || missing+=("$f")
done
if (( ${#missing[@]} > 0 )); then
    echo "ERROR: required boot files missing from rootfs:" >&2
    printf '  - %s\n' "${missing[@]}" >&2
    echo "The image would not boot. Aborting." >&2
    exit 1
fi

echo "==> Installing first-boot resize service"
cat > "$MOUNT_DIR/usr/local/sbin/firstboot-resize.sh" <<'EOF'
#!/bin/bash
# Grow the root partition to fill the SD card, then expand the ext4 fs.
# Self-disables after first successful run.
set -euo pipefail

ROOT_DEV="$(findmnt -no SOURCE /)"             # e.g. /dev/mmcblk0p1 or /dev/disk/by-label/...
ROOT_DEV="$(readlink -f "$ROOT_DEV")"
PARENT="$(lsblk -no PKNAME "$ROOT_DEV" | head -n1)"
DISK="/dev/$PARENT"
PARTNUM="$(echo "$ROOT_DEV" | grep -oE '[0-9]+$')"

echo ", +" | sfdisk -N "$PARTNUM" --no-reread --force "$DISK"
partprobe "$DISK" || true
sleep 1
resize2fs "$ROOT_DEV"

systemctl disable firstboot-resize.service
rm -f /etc/systemd/system/firstboot-resize.service
rm -f /etc/systemd/system/multi-user.target.wants/firstboot-resize.service
rm -f /usr/local/sbin/firstboot-resize.sh
EOF
chmod +x "$MOUNT_DIR/usr/local/sbin/firstboot-resize.sh"

cat > "$MOUNT_DIR/etc/systemd/system/firstboot-resize.service" <<'EOF'
[Unit]
Description=Resize root partition and filesystem to fill SD card on first boot
DefaultDependencies=no
After=local-fs.target systemd-remount-fs.service
Before=basic.target sshd.service
ConditionPathExists=/usr/local/sbin/firstboot-resize.sh

[Service]
Type=oneshot
RemainAfterExit=no
ExecStart=/usr/local/sbin/firstboot-resize.sh

[Install]
WantedBy=multi-user.target
EOF

mkdir -p "$MOUNT_DIR/etc/systemd/system/multi-user.target.wants"
ln -sf /etc/systemd/system/firstboot-resize.service \
    "$MOUNT_DIR/etc/systemd/system/multi-user.target.wants/firstboot-resize.service"

echo "==> Unmounting"
sync
umount -R "$MOUNT_DIR"

echo "==> Writing U-Boot SPL + proper to sector 16"
dd if="$UBOOT_BLOB" of="$LOOP" bs=512 seek=16 conv=notrunc,fsync status=none

echo "==> Detaching loop device"
losetup -d "$LOOP"
LOOP=""

# Return ownership to the invoking user so they don't need sudo to flash/delete.
if [[ -n "${SUDO_USER:-}" ]] && id "$SUDO_USER" >/dev/null 2>&1; then
    chown "$SUDO_USER:$(id -gn "$SUDO_USER")" "$OUT_IMG"
fi

echo
echo "Done: $OUT_IMG ($(du -h "$OUT_IMG" | cut -f1) on-disk, $(du -h --apparent-size "$OUT_IMG" | cut -f1) apparent)"
echo
echo "Flash to SD card (replace /dev/sdX with your card):"
echo "  sudo dd if=$OUT_IMG of=/dev/sdX bs=4M conv=fsync status=progress"
echo "  sync"
echo
echo "Default login (Arch Linux ARM):  root / root   (also: alarm / alarm)"
echo "Serial console: 115200 8N1 on the debug UART pins."
