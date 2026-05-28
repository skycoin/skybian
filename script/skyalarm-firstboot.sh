#!/bin/bash
# /usr/bin/skyalarm-firstboot
#
# First-boot installer for skybian-style ArchLinuxARM images.
# Installs skywire-bin from the AUR (precompiled tarball — no compilation
# happens locally), then enables skymanager.service which runs the static-IP
# claim / hypervisor election dance. Self-disables on success.
#
# Boot 1: this service runs after network-online; installs skywire,
#         then enables+starts skymanager, then disables itself.
# Boot 2+: nothing happens here — skymanager already self-disabled after
#          configuration succeeded on Boot 1.
set -Eeuo pipefail

LOG=/var/log/skyalarm-firstboot.log
exec > >(tee -a "$LOG") 2>&1
echo "[$(date -Is)] skyalarm-firstboot starting"

# Refuse to run twice. The systemd unit also has ConditionPathExists=! on
# the marker, but belt-and-braces in case someone runs the script manually.
MARKER=/var/lib/skyalarm/firstboot-done
if [[ -f "$MARKER" ]]; then
    echo "marker exists ($MARKER) — already ran. exiting."
    exit 0
fi

# 1. Sync repos + base packages we'll need to build from AUR.
#    --noconfirm so this is truly unattended on first boot.
pacman-key --init
pacman-key --populate archlinuxarm
pacman -Syyu --noconfirm
pacman -S --needed --noconfirm git base-devel sudo

# 2. makepkg refuses to run as root. Create an unprivileged builder.
if ! id builder >/dev/null 2>&1; then
    useradd -m -G wheel builder
    echo "builder ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-skyalarm-builder
    chmod 0440 /etc/sudoers.d/99-skyalarm-builder
fi

# 3. Build + install skywire-bin from the canonical AUR clone. The AUR
#    PKGBUILD downloads a precompiled per-arch tarball — no Go toolchain
#    compilation happens on the board.
BUILDDIR=/var/tmp/skyalarm-build
rm -rf "$BUILDDIR"
sudo -u builder mkdir -p "$BUILDDIR"
sudo -u builder git -C "$BUILDDIR" clone https://aur.archlinux.org/skywire-bin.git
sudo -u builder bash -c "cd $BUILDDIR/skywire-bin && makepkg -si --noconfirm"

# 4. Set ENABLEPKENDPOINT=true so any future `skywire-cli config gen`
#    (notably skywire-autoconfig calls) keeps the /api/pk route registered
#    on this hypervisor — `config gen -r` retains hypervisors but not
#    EnablePKEndpoint. skymanager exports it inline too; this is for the
#    longer-lived path.
mkdir -p /etc/profile.d
if ! grep -q ENABLEPKENDPOINT /etc/profile.d/skyenv.sh 2>/dev/null ; then
    echo 'export ENABLEPKENDPOINT=true' >> /etc/profile.d/skyenv.sh
fi

# 5. Enable + start the skywire autoconfig pieces. skymanager runs the
#    static-IP claim + hypervisor pubkey fetch. After it succeeds it
#    self-disables (see /usr/bin/skymanager).
systemctl enable --now skymanager.service

# 6. Mark done and self-disable.
mkdir -p "$(dirname "$MARKER")"
date -Is > "$MARKER"
systemctl disable skyalarm-firstboot.service
echo "[$(date -Is)] skyalarm-firstboot complete"
