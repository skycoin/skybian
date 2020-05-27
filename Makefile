.DEFAULT_GOAL := help

PROJECT_BASE := github.com/SkycoinProject/skybian
OPTS?=GO111MODULE=on GOBIN=$(PWD)/bin

TEST_OPTS_BASE:=-cover -timeout=5m

RACE_FLAG:=-race
GOARCH:=$(shell go env GOARCH)

ifneq (,$(findstring 64,$(GOARCH)))
    TEST_OPTS_BASE:=$(TEST_OPTS_BASE) $(RACE_FLAG)
endif

TEST_OPTS_NOCI:=-$(TEST_OPTS_BASE) -v
TEST_OPTS:=$(TEST_OPTS_BASE) -tags no_ci

IMG_BOOT_PARAMS:='[{"local_ip":"192.168.0.2","gateway_ip":"192.168.0.1","local_sk":"34992ada3a6daa4fbb5ad8b5b958d993ad4e5ed0f51b5ba822c8370212030826","hypervisor_pks":["027c823e9e183f3a89c5c200705f2017c0df253a66bdfae5aa0755d191713b7520"]}]'

PACKAGEVERSION := $(shell git describe --abbrev=0 --tags | tr --delete v)
PACKAGEARCH := $(shell dpkg --print-architecture)
PACKAGEDIR1 := $(shell echo "skybian-skywire-${PACKAGEVERSION}-amd64")
PACKAGEDIR1ARM64 := $(shell echo "skybian-skywire-${PACKAGEVERSION}-arm64")
PACKAGEDIR1ARMHF := $(shell echo "skybian-skywire-${PACKAGEVERSION}-armhf")
PACKAGEDIR2 := $(shell echo "skybian-${PACKAGEVERSION}-amd64")
PACKAGEDIR2ARM64 := $(shell echo "skybian-${PACKAGEVERSION}-arm64")
PACKAGEDIR2ARMHF := $(shell echo "skybian-${PACKAGEVERSION}-armhf")
SKYIMAGERPACKAGEDIR := $(shell echo "skyimager-gui-${PACKAGEVERSION}-amd64")


check: lint test ## Run linters and tests

install-linters: ## Install linters
	- VERSION=1.23.1 ./ci_scripts/install-golangci-lint.sh
	# GO111MODULE=off go get -u github.com/FiloSottile/vendorcheck
	# For some reason this install method is not recommended, see https://github.com/golangci/golangci-lint#install
	# However, they suggest `curl ... | bash` which we should not do
	# ${OPTS} go get -u github.com/golangci/golangci-lint/cmd/golangci-lint
	${OPTS} go get -u golang.org/x/tools/cmd/goimports

lint: ## Run linters. Use make install-linters first
	${OPTS} golangci-lint run -c .golangci.yml ./...
	# The govet version in golangci-lint is out of date and has spurious warnings, run it separately
	${OPTS} go vet -all ./...

format: ## Formats the code. Must have goimports installed (use make install-linters).
	${OPTS} goimports -w -local ${PROJECT_BASE} ./pkg
	${OPTS} goimports -w -local ${PROJECT_BASE} ./cmd
	${OPTS} goimports -w -local ${PROJECT_BASE} ./integration/cmd

test: ## Run tests
	-go clean -testcache &>/dev/null
	${OPTS} go test ${TEST_OPTS} ./pkg/...

integration: build-skyconf ## runs integration tests.
	./integration/run.sh
	sudo rm -rf ./integration/mnt

build-skyconf: ## builds skyconf.
	${OPTS} go install ./cmd/skyconf

skybian-skywire-package-amd64: #native build
	sudo mkdir -p ${PACKAGEDIR1}/DEBIAN ${PACKAGEDIR1}/usr/bin ${PACKAGEDIR1}/etc/systemd/system
	sudo echo "Package: skybian-skywire" > control
	sudo echo "Version: ${PACKAGEVERSION}" >> control
	sudo echo "Priority: optional" >> control
	sudo echo "Section: web" >> control
	sudo echo "Architecture: amd64" >> control
	sudo echo "Depends: skywire" >> control
	sudo echo "Maintainer: SkycoinProject" >> control
	sudo echo "Description: Skywire helper scripts" >> control
	sudo mv control ${PACKAGEDIR1}/DEBIAN/control
	sudo cat ${PACKAGEDIR1}/DEBIAN/control
	sudo ${OPTS} GOARCH="amd64" go build ${BUILD_OPTS} -o ./${PACKAGEDIR1}/usr/bin/skyconf ./cmd/skyconf
	sudo cp -b static/skybian-firstrun ${PACKAGEDIR1}/usr/bin/skybian-firstrun
	sudo chmod 755 ${PACKAGEDIR1}/usr/bin/skybian-firstrun
	sudo cp -b static/skybian-firstrun.service  ${PACKAGEDIR1}/etc/systemd/system/skybian-firstrun.service
	sudo chmod 644 ${PACKAGEDIR1}/etc/systemd/system/skybian-firstrun.service
	sudo dpkg-deb --build ${PACKAGEDIR1}
	sudo rm -rf ${PACKAGEDIR1}

skybian-skywire-package-arm64: #need a more efficient method
	sudo mkdir -p ${PACKAGEDIR1ARM64}/DEBIAN ${PACKAGEDIR1ARM64}/usr/bin ${PACKAGEDIR1ARM64}/etc/systemd/system
	sudo echo "Package: skybian-skywire" > control
	sudo echo "Version: ${PACKAGEVERSION}" >> control
	sudo echo "Priority: optional" >> control
	sudo echo "Section: web" >> control
	sudo echo "Architecture: arm64" >> control
	sudo echo "Depends: skywire" >> control
	sudo echo "Maintainer: SkycoinProject" >> control
	sudo echo "Description: Skywire helper scripts" >> control
	sudo mv control ${PACKAGEDIR1ARM64}/DEBIAN/control
	sudo cat ${PACKAGEDIR1ARM64}/DEBIAN/control
	sudo ${OPTS} env GOOS=linux GOARCH=arm64 go build ${BUILD_OPTS} -o ./${PACKAGEDIR1ARM64}/usr/bin/skyconf ./cmd/skyconf
	sudo cp -b static/skybian-firstrun ${PACKAGEDIR1ARM64}/usr/bin/skybian-firstrun
	sudo chmod 755 ${PACKAGEDIR1ARM64}/usr/bin/skybian-firstrun
	sudo cp -b static/skybian-firstrun.service  ${PACKAGEDIR1ARM64}/etc/systemd/system/skybian-firstrun.service
	sudo chmod 644 ${PACKAGEDIR1ARM64}/etc/systemd/system/skybian-firstrun.service
	sudo dpkg-deb --build ${PACKAGEDIR1ARM64}
	sudo rm -rf ${PACKAGEDIR1ARM64}

skybian-skywire-package-armhf: #need a more efficient method
	sudo mkdir -p ${PACKAGEDIR1ARMHF}/DEBIAN ${PACKAGEDIR1ARMHF}/usr/bin ${PACKAGEDIR1ARMHF}/etc/systemd/system
	sudo echo "Package: skybian-skywire" > control
	sudo echo "Version: ${PACKAGEVERSION}" >> control
	sudo echo "Priority: optional" >> control
	sudo echo "Section: web" >> control
	sudo echo "Architecture: armhf" >> control
	sudo echo "Depends: skywire" >> control
	sudo echo "Maintainer: SkycoinProject" >> control
	sudo echo "Description: Skywire helper scripts" >> control
	sudo mv control ${PACKAGEDIR1ARMHF}/DEBIAN/control
	sudo cat ${PACKAGEDIR1ARMHF}/DEBIAN/control
	sudo ${OPTS} env GOOS=linux GOARCH=arm GOARM=6 go build ${BUILD_OPTS} -o ./${PACKAGEDIR1ARMHF}/usr/bin/skyconf ./cmd/skyconf
	sudo cp -b static/skybian-firstrun ${PACKAGEDIR1ARMHF}/usr/bin/skybian-firstrun
	sudo chmod 755 ${PACKAGEDIR1ARMHF}/usr/bin/skybian-firstrun
	sudo cp -b static/skybian-firstrun.service  ${PACKAGEDIR1ARMHF}/etc/systemd/system/skybian-firstrun.service
	sudo chmod 644 ${PACKAGEDIR1ARMHF}/etc/systemd/system/skybian-firstrun.service
	sudo dpkg-deb --build ${PACKAGEDIR1ARMHF}
	sudo rm -rf ${PACKAGEDIR1ARMHF}

skybian-package-amd64:
	sudo mkdir -p ${PACKAGEDIR2}/DEBIAN ${PACKAGEDIR2}/usr/bin ${PACKAGEDIR2}/etc/profile.d ${PACKAGEDIR2}/etc/update-motd.d ${PACKAGEDIR2}/etc/default
	sudo echo "Package: skybian" > control
	sudo echo "Version: ${PACKAGEVERSION}" >> control
	sudo echo "Priority: optional" >> control
	sudo echo "Section: web" >> control
	sudo echo "Architecture: amd64" >> control
	sudo echo "Maintainer: SkycoinProject" >> control
	sudo echo "Description: Skybian image configuration" >> control
	sudo mv control ${PACKAGEDIR2}/DEBIAN/control
	sudo cat ${PACKAGEDIR2}/DEBIAN/control
	sudo cp -b "static/armbian-check-first-login.sh"  "${PACKAGEDIR2}/etc/profile.d/armbian-check-first-login.sh"
	sudo chmod 755 "${PACKAGEDIR2}/etc/profile.d/armbian-check-first-login.sh"
	sudo cp -b "static/armbian-check-first-login.sh" "${PACKAGEDIR2}/etc/profile.d/armbian-check-first-login.sh"
	sudo chmod 755 "${PACKAGEDIR2}/etc/profile.d/armbian-check-first-login.sh"
	sudo cp -b "static/10-skybian-header" "${PACKAGEDIR2}/etc/update-motd.d/"
	sudo chmod 755 "${PACKAGEDIR2}/etc/update-motd.d/10-skybian-header"
	sudo cp -b "static/armbian-motd" "${PACKAGEDIR2}/etc/default/"
	sudo dpkg-deb --build ${PACKAGEDIR2}
	sudo rm -rf ${PACKAGEDIR2}

skybian-package-arm64:
	sudo mkdir -p ${PACKAGEDIR2ARM64}/DEBIAN ${PACKAGEDIR2ARM64}/usr/bin ${PACKAGEDIR2ARM64}/etc/profile.d ${PACKAGEDIR2ARM64}/etc/update-motd.d/ ${PACKAGEDIR2ARM64}/etc/default
	sudo echo "Package: skybian" > control
	sudo echo "Version: ${PACKAGEVERSION}" >> control
	sudo echo "Priority: optional" >> control
	sudo echo "Section: web" >> control
	sudo echo "Architecture: arm64" >> control
	sudo echo "Maintainer: SkycoinProject" >> control
	sudo echo "Description: Skybian image configuration" >> control
	sudo mv control ${PACKAGEDIR2ARM64}/DEBIAN/control
	sudo cat ${PACKAGEDIR2ARM64}/DEBIAN/control
	sudo cp -b "static/armbian-check-first-login.sh" "${PACKAGEDIR2ARM64}/etc/profile.d/armbian-check-first-login.sh"
	sudo chmod 755 "${PACKAGEDIR2ARM64}/etc/profile.d/armbian-check-first-login.sh"
	sudo cp -b "static/10-skybian-header" "${PACKAGEDIR2ARM64}/etc/update-motd.d/"
	sudo chmod 755 "${PACKAGEDIR2ARM64}/etc/update-motd.d/10-skybian-header"
	sudo cp -b "static/armbian-motd" "${PACKAGEDIR2ARM64}/etc/default/"
	sudo dpkg-deb --build ${PACKAGEDIR2ARM64}
	sudo rm -rf ${PACKAGEDIR2ARM64}

skybian-package-armhf:
	sudo mkdir -p ${PACKAGEDIR2ARMHF}/DEBIAN ${PACKAGEDIR2ARMHF}/usr/bin ${PACKAGEDIR2ARMHF}/etc/profile.d ${PACKAGEDIR2ARMHF}/etc/update-motd.d/ ${PACKAGEDIR2ARMHF}/etc/default
	sudo echo "Package: skybian" > control
	sudo echo "Version: ${PACKAGEVERSION}" >> control
	sudo echo "Priority: optional" >> control
	sudo echo "Section: web" >> control
	sudo echo "Architecture: armhf" >> control
	sudo echo "Maintainer: SkycoinProject" >> control
	sudo echo "Description: Skybian image configuration" >> control
	sudo mv control ${PACKAGEDIR2ARMHF}/DEBIAN/control
	sudo cat ${PACKAGEDIR2ARMHF}/DEBIAN/control
	sudo cp -b "static/armbian-check-first-login.sh"  "${PACKAGEDIR2ARMHF}/etc/profile.d/armbian-check-first-login.sh"
	sudo chmod 755 "${PACKAGEDIR2ARMHF}/etc/profile.d/armbian-check-first-login.sh"
	sudo cp -b "static/10-skybian-header" "${PACKAGEDIR2ARMHF}/etc/update-motd.d/"
	sudo chmod 755 "${PACKAGEDIR2ARMHF}/etc/update-motd.d/10-skybian-header"
	sudo cp -b "static/armbian-motd" "${PACKAGEDIR2ARMHF}/etc/default/"
	sudo dpkg-deb --build ${PACKAGEDIR2ARMHF}
	sudo rm -rf ${PACKAGEDIR2ARMHF}

all-packages:	skybian-skywire-package-amd64	skybian-skywire-package-arm64	skybian-skywire-package-armhf skybian-package-amd64 skybian-package-arm64 skybian-package-armhf

skyimager-gui-package: ##package skyimager gui. Manually because above is broken.
	sudo mkdir -p ${SKYIMAGERPACKAGEDIR}/DEBIAN ${SKYIMAGERPACKAGEDIR}/usr/bin
	sudo echo "Package: skyimager" > control
	sudo echo "Version: ${PACKAGEVERSION}" >> control
	sudo echo "Priority: optional" >> control
	sudo echo "Section: web" >> control
	sudo echo "Architecture: amd64" >> control
	sudo echo "Maintainer: SkycoinProject" >> control
	sudo echo "Description: Skybian image creation and configuration tool" >> control
	sudo mv control ${SKYIMAGERPACKAGEDIR}/DEBIAN/control
	sudo cat ${SKYIMAGERPACKAGEDIR}/DEBIAN/control
	sudo ${OPTS} GOARCH="amd64" go build ${BUILD_OPTS} -o ./${SKYIMAGERPACKAGEDIR}/usr/bin/skyimager-gui ./cmd/skyimager-gui
	sudo dpkg-deb --build ${SKYIMAGERPACKAGEDIR}
	sudo rm -rf ${SKYIMAGERPACKAGEDIR}

build-skybian-img: ## builds skybian base image.
	rm -rf ./output
	./build.sh -c 2>&1 /dev/null
	./build.sh
	./build.sh -p

build-skyimager-gui: ## builds skyimager GUI
	./build-skyimager.sh

run-skyimager: ## Run skyimager
	echo ${IMG_BOOT_PARAMS} | go run ./cmd/skyimager/skyimager.go

run-skyimager-gui: ## Builds skyimager GUI
	mkdir -p ./bin
	${OPTS} GOBIN=${PWD}/bin go get github.com/rakyll/statik
	./bin/statik -src=./cmd/skyimager-gui/assets -dest ./cmd/skyimager-gui -f
	${OPTS} go run ./cmd/skyimager-gui/skyimager-gui.go -debug -scale "-1.0"

tag: ## Make git tag using VERSION in build.conf
	./tag.sh

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
