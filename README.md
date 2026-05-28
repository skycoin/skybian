# Skybian Image

Skybian is a Debian/Armbian-derived ARM image preconfigured to run [skywire](https://github.com/skycoin/skywire) for the [Skyminer](https://github.com/skycoin/skyminer-hardware).

Supported SBCs:

* Orange Pi Prime  (Armbian, arm64)
* Orange Pi 3      (Armbian, arm64)
* Raspberry Pi 3   (Raspberry Pi OS, armhf)
* Raspberry Pi 4   (Raspberry Pi OS, arm64)

ArchLinuxARM variants are available via [`skyalarm.prime.IMGBUILD`](skyalarm.prime.IMGBUILD)
(Orange Pi Prime, aarch64) and [`skyalarm.rpi.IMGBUILD`](skyalarm.rpi.IMGBUILD) (RPi armv7
and aarch64). They ship the same `skymanager` / `srvpk` / `skylog` autoconfig, but install
`skywire-bin` from the AUR on first boot rather than baking it into the image.

## Layout

This repo contains two related build flavors:

* **[PKGBUILD](PKGBUILD)** — builds the per-arch `skybian.deb` shipping only the autoconfig
  (`skymanager`, `skybian-reset`, motd snippets).
  Apt-repo configuration and the `install-skywire` service live in the `skyrepo` deb built
  out of [skycoin/apt-repo](https://github.com/skycoin/apt-repo); `skybian.deb`
  `Depends:` on `skyrepo` and `skywire-bin`.

* **[IMGBUILD](skybian.prime.IMGBUILD)s** — drive the per-board image builds. Each IMGBUILD
  sources [`skybian-conf.sh`](skybian-conf.sh) (Armbian-based) or
  [`skyraspbian-conf.sh`](skyraspbian-conf.sh) (Raspbian-based), downloads the upstream
  image, mounts it via loop device, and installs three debs into the chroot in this order:

  1. `skyrepo` — adds `deb.skywire.skycoin.com` apt source + `install-skywire.service`
  2. `skywire-bin` — the skywire binaries + systemd units
  3. `skybian` — autoconfig (skymanager + motd)

Release images: <https://deb.skywire.skycoin.com/img/>

## Build dependencies

Host: Arch Linux, ~15 GB free.

```
yay -S arch-install-scripts aria2 dpkg dtrx qemu-arm-static qemu-user-static \
       qemu-user-static-binfmt gnome-disk-utility zip
```

## Build the skybian.deb

```
./skybian.sh
```

This regenerates `skybian-script.tar.gz` / `skybian-static.tar.gz` from `script/` and
`static/`, refreshes `pkgver` checksums, and runs `makepkg` against `PKGBUILD`. Output:
`skybian-${pkgver}-${pkgrel}-${arch}.deb` for arm64 and armhf.

## Build an image

```
SKYBIAN=skybian.prime.IMGBUILD ./image.sh            # OPi Prime, no autopeering
ENABLEAUTOPEER="-autopeer" SKYBIAN=skybian.prime.IMGBUILD ./image.sh   # OPi Prime w/ autopeer
SKYBIAN=skybian.opi3.IMGBUILD       ./image.sh       # OPi 3
SKYBIAN=skyraspbian.rpi3.IMGBUILD   ./image.sh       # RPi 3 (armhf)
SKYBIAN=skyraspbian.rpi4.IMGBUILD   ./image.sh       # RPi 4 (arm64)
```

`./image.sh 1` builds without compression (faster, for iterating). `./image.sh zip` adds a
`.zip` for the Windows imagers. `./image.sh 0` only refreshes source checksums.

Build all five at once:
```
./images.sh        # production
./images.sh 0      # refresh checksums only
```

`build.sh` provides a `dialog`-based menu for the same operations.

### ArchLinuxARM images

```
makepkg -fp skyalarm.prime.IMGBUILD          # OPi Prime aarch64
makepkg -fp skyalarm.rpi.IMGBUILD            # RPi (armv7 + aarch64, one PKGBUILD produces both)
```

`skyalarm.prime.IMGBUILD` extracts the sunxi U-Boot SPL+proper blob from an Armbian image
on first run and caches it as `../u-boot-sunxi-with-spl.bin`. Subsequent builds reuse the
cache. The ALARM rootfs itself comes straight from
[archlinuxarm.org](http://os.archlinuxarm.org/os).

On first boot the [`skyalarm-firstboot.service`](script/skyalarm-firstboot.service)
runs `pacman -Syyu && yay-equivalent skywire-bin` (precompiled tarball, no Go build on
the board) and then enables `skymanager`. After that, autoconfig behaves identically to
the deb-based images: `.2` becomes hypervisor, everyone else joins as visors. The first
boot consumes one connected-to-internet window on the order of 10–15 minutes; subsequent
boots are fast.

## Testing repo deployment

`TESTDEPLOYMENT=1` causes the chroot config to set `VISORISPUBLIC=1` and
`NOAUTOCONNECT=1` in `/etc/profile.d/skyenv.sh`. The actual apt-repo URL switching is
handled by the `skyrepo` deb (which ships all three mirror URLs by default).

## First-boot auto-config

When the image boots for the first time:

1. `install-skywire.service` (from `skyrepo`) runs `apt update && apt reinstall
   skywire-bin` and then self-disables. This guarantees the latest skywire is on the
   board even if the image is months stale.
2. `skymanager.service` (from `skybian`, ordered `After=install-skywire.service`)
   writes `ENABLEPKENDPOINT=true` into `/etc/skywire.conf` so every
   subsequent `skywire cli config gen` flips on the unauthenticated
   `GET /api/pk` route in the generated config, then probes
   `<gateway>.2:8000/api/ping`:
   * **Nothing there** → claim `.2` as static IP and `skywire autoconfig 0`
     (local hypervisor with UI on `:8000` and `/api/pk` registered).
   * **Already taken** → `skywire autoconfig 1` first (materializes the
     visor config + keypair, no remote hypervisor wired yet), then
     `curl -H "SW-Public: <our-pk>" http://<gw>.2:8000/api/pk` to discover
     the hypervisor's pk, then `skywire autoconfig <hv-pk>` to register it
     (`-r` retention keeps our keypair stable across the second regen).

   The `/api/pk` route landed in skywire develop
   ([#2895](https://github.com/skycoin/skywire/pull/2895),
   [#2896](https://github.com/skycoin/skywire/pull/2896)). It's gated on
   `EnablePKEndpoint` in `HypervisorConfig`, off by default. The toggle has
   to live in the **SKYENV file** (`/etc/skywire.conf`) — not OS env, not
   `/etc/profile.d/skyenv.sh` — because `cmdutil.SkyenvFile.Eval` reads
   only from the parsed env file (no `os.Getenv` fallback).
3. After successful configuration, `skymanager` self-disables. On reboot, no further
   network changes happen unless the operator runs `skybian-reset` to redo the dance.

User experience target: flash → boot → browse to `http://<gw>.2:8000`. No SSH, no
pre-flash imager, no manual configuration.

See [`script/skymanager.sh`](script/skymanager.sh) for the detection logic.

## APT repository

The Skycoin apt repository is at <https://deb.skywire.skycoin.com> with mirrors at
<https://deb.theskywirenetwork.net> and <https://deb.skywire.dev> (the latter is the
release-candidate channel). Configuration ships in the `skyrepo` deb — install it on any
debian-derived arm/arm64/amd64 system to make `apt install skywire-bin` work. Testing
images live at <https://deb.skywire.dev/img/>.

## Script and service reference

* [`skymanager.sh`](script/skymanager.sh) — static-IP claim + hypervisor election (called by `skymanager.service` on first boot)
* [`skymanager.service`](script/skymanager.service) — runs `skymanager` after `network-online.target`
* [`skybian-chrootconfig.sh`](script/skybian-chrootconfig.sh) — called from `postinst`, sets env defaults and enables `skymanager` under `CHROOTCONFIG=1`
* [`skybian-reset.sh`](script/skybian-reset.sh) — disables skywire services and removes generated config, for re-running first-boot autoconfig
* [`skyenv.sh`](script/skyenv.sh) — defaults sourced by `skywire-autoconfig` on first run when `/etc/skywire.conf` is absent

The actual skywire configuration is produced by `skywire-autoconfig` (shipped with
`skywire-bin`); see <https://github.com/skycoin/skywire> for the upstream script.
