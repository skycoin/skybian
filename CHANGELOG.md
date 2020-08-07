# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

<!--
This is a note for developers about the recommended tags to keep track of the changes:

- Added: for new features.
- Changed: for changes in existing functionality.
- Deprecated: for soon-to-be removed features.
- Removed: for now removed features.
- Fixed: for any bug fixes.
- Security: in case of vulnerabilities.

Dates must be YEAR-MONTH-DAY
-->

## [0.1.2] - 2020-04-20

### Changed

- Updated Skywire to `v0.2.3`.

### Fixed

- ` NetworkManager.service` should be running before the `skywire-startup.service` ([#23](https://github.com/skycoin/skybian/pull/23)).
- Fixed various boot errors ([e300f94eb1b22d30dd86a024e07f89a65ba0a12e](https://github.com/skycoin/skybian/pull/29/commits/e300f94eb1b22d30dd86a024e07f89a65ba0a12e)).

## [0.1.0] - 2020-04-09

### Added

- Introduced [`skyconf`](cmd/skyconf) to help orchestrate initial boot of Skybian.
- Introduced [`skyimager`](cmd/skyimager-gui) as a replacement for [`skyflash`](https://github.com/SkycoinProject/skyflash) and added [`build-skyimager.sh`](build-skyimager.sh) to orchestrate cross compiling of `skyimager`.

### Changed

- Updated Skywire to `v0.2.0`.
- Various changes and simplifications to files within [`static`](static), as well as to [`build.conf`](build.conf) and [`build.sh`](build.sh), in order to accommodate integration of Skywire `v0.2.0`.


## [0.0.5] - 2019-11-04

### Added

- Added new managerUI code.
- Updated the discovery address.

## [0.0.4] - 2019-04-18

### Added

- Added latest Skywire testnet code

### Changed

- OS upgraded to Armbian 5.75 with kernel 4.19.20
- Armbian changed the layout of the filesystem and the boot firmware, so we changed to adapt to that.
- Config offset is now at block #32768 (of 512 bytes) higher than in previous versions

## Deprecated

- Skyflash at this point needs to be modified to work with this because of the change on the filesystem layout of armbian


## [0.0.3] - 2019-02-23

### Added

- Skybian will be distributed as a single base image (saving user's time and bandwidth), from this image you can generate a manager and how many nodes/minions you need by using the Skyflash tool
- Explanatory document about the build process: [Build_Skybian.md](Build_Skybian.md)
- The README.md now has the RELEASE steps for reference
- Add a CHANGELOG.md file (this file)
- First working version of Skybian

### Changed

- Skybian is based in Armbian version 5.65
- Build script has now strict error checking
- Renamed the environment.txt file to build.conf to better represent that it is a configuration file.
- Travis yml build and deploy instructions update to match git flow logic.
- Updated README.md with a comment on the build process on the [Build_Skybian.md](Build_Skybian.md) file.
- Versioning for Skybian will match the Skywire ones, starting with 0.0.3
