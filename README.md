# Skybian Image

Skybian is a Debian/Armbian-derived ARM image preconfigured to run [skywire](https://github.com/skycoin/skywire) for the [Skyminer](https://github.com/skycoin/skyminer-hardware).

Supported SBCs:

* Orange Pi Prime  (Armbian, arm64)
* Orange Pi 3      (Armbian, arm64)
* Raspberry Pi 3   (Raspberry Pi OS, armhf)
* Raspberry Pi 4   (Raspberry Pi OS, arm64)

ArchLinuxARM variants are available via [`skyalarm.prime.IMGBUILD`](skyalarm.prime.IMGBUILD)
(Orange Pi Prime, aarch64) and [`skyalarm.rpi.IMGBUILD`](skyalarm.rpi.IMGBUILD) (RPi armv7
and aarch64). They ship the same `skymanager` autoconfig but install `skywire-bin` from
the AUR on first boot rather than baking it into the image.

## Layout

This repo only contains the per-board `.IMGBUILD` files and the shared `*-conf.sh` build
logic. There is no longer a `skybian.deb` — its old payload (skymanager, skybian-reset,
motd snippets, skyenv defaults) moved into the `skyrepo` deb in [skycoin/apt-repo](https://github.com/skycoin/apt-repo).
Each image build now installs only two debs in chroot:

1. `skyrepo` — adds `deb.skywire.skycoin.com` apt source + `install-skywire.service` +
   the autoconfig payload (skymanager + skybian-reset + motd + skyenv).
2. `skywire-bin` — the skywire binaries + systemd units.

Release images: <https://deb.skywire.skycoin.com/img/>

## Build dependencies

Host: Arch Linux, ~15 GB free.

```
sudo pacman -S --needed arch-install-scripts aria2 dpkg dtrx gnome-disk-utility \
                        qemu-user-static qemu-user-static-binfmt zip
```

Note: the official `qemu-user-static` from `extra` covers all archs in one package — do
not install the AUR per-arch `qemu-*-static-bin` variants; they collide on
`/usr/bin/qemu-aarch64-static`.

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
makepkg -fp skyalarm.prime.IMGBUILD          # OPi Prime aarch64 (with skybian autoconfig)
makepkg -fp skyalarm.rpi.IMGBUILD            # RPi (armv7 + aarch64, one PKGBUILD produces both)
```

For the bare ALARM image (no skywire, no skymanager — useful as a base for
operators who want to install skywire themselves, or for QA/repro work):

```
BASEONLY=1 makepkg -fp skyalarm.prime.IMGBUILD       # → skyalarm-orangepiprime-base-*.img
BASEONLY=1 makepkg -fp skyalarm.rpi.IMGBUILD         # → skyalarm-rpi-base-*-{armv7,aarch64}.img
```

ALARM IMGBUILDs download `skyrepo_*.deb` and `dpkg-deb -x` it to lift the autoconfig
files (skymanager + skybian-reset + motd + skyenv) into the ALARM rootfs — no chroot
needed because we're not dpkg-installing on Arch. `skyalarm.prime.IMGBUILD` additionally
extracts the sunxi U-Boot SPL+proper blob from an Armbian image on first run and caches
it as `../u-boot-sunxi-with-spl.bin`; subsequent builds reuse the cache. The ALARM rootfs
itself comes straight from [archlinuxarm.org](http://os.archlinuxarm.org/os).

On first boot the [`skyalarm-firstboot.service`](script/skyalarm-firstboot.service) runs
`pacman -Syyu && yay-equivalent skywire-bin` (precompiled tarball, no Go build on the
board) and then enables `skymanager`. After that, autoconfig behaves identically to the
deb-based images: `.2` becomes hypervisor, everyone else joins as visors. The first boot
consumes one connected-to-internet window on the order of 10–15 minutes; subsequent boots
are fast.

## Testing repo deployment

`TESTDEPLOYMENT=1` causes the chroot config to set `VISORISPUBLIC=1` and
`NOAUTOCONNECT=1` in `/etc/profile.d/skyenv.sh`. The actual apt-repo URL switching is
handled by the `skyrepo` deb (which ships all three mirror URLs by default).

## First-boot auto-config

When the image boots for the first time:

1. `install-skywire.service` (from `skyrepo`, `Type=oneshot RemainAfterExit=yes`) runs
   `apt update && apt reinstall skywire-bin` and then self-disables. This guarantees the
   latest skywire is on the board even if the image is months stale.
2. `skymanager.service` (also from `skyrepo`, ordered `After=install-skywire.service`)
   writes `ENABLEPKENDPOINT=true` into `/etc/skywire.conf` so every subsequent
   `skywire cli config gen` flips on the unauthenticated `GET /api/pk` route in the
   generated config, then **polls** `<gateway>.2:8000/api/ping` every 5s for up to 2
   minutes:
   * **Nothing there after the full window** → sleep a random 0–30s (race-break for the
     case where all 8 boards reach timeout at once), re-probe one more time, and if still
     nothing claim `.2` as static IP and `skywire autoconfig 0` (local hypervisor with UI
     on `:8000` and `/api/pk` registered). If the final re-probe finds something, fall
     through to the visor path.
   * **Pong** → `skywire autoconfig 1` first (materializes the visor config + keypair, no
     remote hypervisor wired yet), then
     `curl -H "SW-Public: <our-pk>" http://<gw>.2:8000/api/pk` to discover the
     hypervisor's pk, then `skywire autoconfig <hv-pk>` to register it (`-r` retention
     keeps our keypair stable across the second regen).

   The polling window accommodates the skyminer power-bus hardware constraint: when the
   main switch turns on all 8 boards at once, voltage dips can stall the (preboot'd)
   hypervisor's startup for tens of seconds. A single-shot probe would race ahead and
   visors would try to claim `.2` themselves.

   The `/api/pk` route landed in skywire develop
   ([#2895](https://github.com/skycoin/skywire/pull/2895),
   [#2896](https://github.com/skycoin/skywire/pull/2896)). It's gated on
   `EnablePKEndpoint` in `HypervisorConfig`, off by default. The toggle has to live in
   the **SKYENV file** (`/etc/skywire.conf`) — not OS env, not `/etc/profile.d/skyenv.sh`
   — because `cmdutil.SkyenvFile.Eval` reads only from the parsed env file (no
   `os.Getenv` fallback).
3. After successful configuration, `skymanager` self-disables. On reboot, no further
   network changes happen unless the operator runs `skybian-reset` to redo the dance.

User experience target: flash → boot → browse to `http://<gw>.2:8000`. No SSH, no
pre-flash imager, no manual configuration.

The `skymanager.sh` source of truth lives in
[apt-repo/script/skymanager.sh](https://github.com/skycoin/apt-repo/blob/master/script/skymanager.sh)
(packaged into `skyrepo.deb` and lifted into ALARM images via `dpkg-deb -x` at build
time).

## APT repository

The Skycoin apt repository is at <https://deb.skywire.skycoin.com> with mirrors at
<https://deb.theskywirenetwork.net> and <https://deb.skywire.dev> (the latter is the
release-candidate channel). Configuration ships in the `skyrepo` deb — install it on any
debian-derived arm/arm64/amd64 system to make `apt install skywire-bin` work. Testing
images live at <https://deb.skywire.dev/img/>.
