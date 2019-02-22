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

## [0.0.3] - 2019-02-22

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
