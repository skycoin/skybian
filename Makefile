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
PACKAGEDIR1 := $(shell echo "skybian-skywire-${PACKAGEVERSION}-${PACKAGEARCH}")
PACKAGEDIR1ARM64 := $(shell echo "skybian-skywire-${PACKAGEVERSION}-arm64")
PACKAGEDIR1ARMHF := $(shell echo "skybian-skywire-${PACKAGEVERSION}-armhf")
PACKAGEDIR2 := $(shell echo "skybian-${PACKAGEVERSION}-${PACKAGEARCH}")
PACKAGEDIR2ARM64 := $(shell echo "skybian-${PACKAGEVERSION}-arm64")
PACKAGEDIR2ARMHF := $(shell echo "skybian-${PACKAGEVERSION}-armhf")
SKYIMAGERPACKAGEDIR := $(shell echo "skyimager-gui-${PACKAGEVERSION}-${PACKAGEARCH}")

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

build-skybian-img: ## builds skybian base image.
	rm -rf ./output
	./build.sh -c 2>&1 /dev/null
	./build.sh
	./build.sh -p

skybian-skywire-package-amd64: #native build
	mkdir -p ${PACKAGEDIR1}/DEBIAN ${PACKAGEDIR1}/usr/bin ${PACKAGEDIR1}/etc/systemd/system ${PACKAGEDIR1}/var/cache/apt/repo
	echo "Package: skybian-skywire" > ${PACKAGEDIR1}/DEBIAN/control
	echo "Version: ${PACKAGEVERSION}" >> ${PACKAGEDIR1}/DEBIAN/control
	echo "Priority: optional" >> ${PACKAGEDIR1}/DEBIAN/control
	echo "Section: web" >> ${PACKAGEDIR1}/DEBIAN/control
	echo "Architecture: amd64" >> ${PACKAGEDIR1}/DEBIAN/control
	echo "Depends: skywire" >> ${PACKAGEDIR1}/DEBIAN/control
	echo "Maintainer: SkycoinProject" >> ${PACKAGEDIR1}/DEBIAN/control
	echo "Description: Skywire helper scripts" >> ${PACKAGEDIR1}/DEBIAN/control
	${OPTS} GOARCH="amd64" go build ${BUILD_OPTS} -o ./${PACKAGEDIR1}/usr/bin/readonlycache ./static/readonlycache.go
	${OPTS} GOARCH="amd64" go build ${BUILD_OPTS} -o ./${PACKAGEDIR1}/usr/bin/skyconf ./cmd/skyconf
	cp -b static/skywire ${PACKAGEDIR1}/usr/bin/skywire
	chmod 755 ${PACKAGEDIR1}/usr/bin/skywire
	cp -b static/skywire ${PACKAGEDIR1}/usr/bin/skybian-firstrun
	chmod 755 ${PACKAGEDIR1}/usr/bin/skybian-firstrun
	cp -b static/skybian-firstrun.service  ${PACKAGEDIR1}/etc/systemd/system/skybian-firstrun.service
	chmod 644 ${PACKAGEDIR1}/etc/systemd/system/skybian-firstrun.service
	cp -b static/local-deb-repo ${PACKAGEDIR1}/usr/bin/local-deb-repo
	chmod 755 ${PACKAGEDIR1}/usr/bin/local-deb-repo
	cp -b static/remote-deb-repo ${PACKAGEDIR1}/usr/bin/remote-deb-repo
	chmod 755 ${PACKAGEDIR1}/usr/bin/remote-deb-repo
	dpkg-deb --build ${PACKAGEDIR1}
	rm -rf ${PACKAGEDIR1}

skybian-skywire-package-arm64: #need a more efficient method
	mkdir -p ${PACKAGEDIR1ARM64}/DEBIAN ${PACKAGEDIR1ARM64}/usr/bin ${PACKAGEDIR1ARM64}/etc/systemd/system ${PACKAGEDIR1ARM64}/var/cache/apt/repo
	echo "Package: skybian-skywire" > ${PACKAGEDIR1ARM64}/DEBIAN/control
	echo "Version: ${PACKAGEVERSION}" >> ${PACKAGEDIR1ARM64}/DEBIAN/control
	echo "Priority: optional" >> ${PACKAGEDIR1ARM64}/DEBIAN/control
	echo "Section: web" >> ${PACKAGEDIR1ARM64}/DEBIAN/control
	echo "Architecture: arm64" >> ${PACKAGEDIR1ARM64}/DEBIAN/control
	echo "Depends: skywire" >> ${PACKAGEDIR1ARM64}/DEBIAN/control
	echo "Maintainer: SkycoinProject" >> ${PACKAGEDIR1ARM64}/DEBIAN/control
	echo "Description: Skywire helper scripts" >> ${PACKAGEDIR1ARM64}/DEBIAN/control
	${OPTS} env GOOS=linux GOARCH=arm64 go build ${BUILD_OPTS} -o ./${PACKAGEDIR1ARM64}/usr/bin/readonlycache ./static/readonlycache.go
	${OPTS} env GOOS=linux GOARCH=arm64 go build ${BUILD_OPTS} -o ./${PACKAGEDIR1ARM64}/usr/bin/skyconf ./cmd/skyconf
	cp -b static/skywire ${PACKAGEDIR1ARM64}/usr/bin/skywire
	chmod 755 ${PACKAGEDIR1ARM64}/usr/bin/skywire
	cp -b static/skywire ${PACKAGEDIR1ARM64}/usr/bin/skybian-firstrun
	chmod 755 ${PACKAGEDIR1ARM64}/usr/bin/skybian-firstrun
	cp -b static/skybian-firstrun.service  ${PACKAGEDIR1ARM64}/etc/systemd/system/skybian-firstrun.service
	chmod 644 ${PACKAGEDIR1ARM64}/etc/systemd/system/skybian-firstrun.service
	cp -b static/local-deb-repo ${PACKAGEDIR1ARM64}/usr/bin/local-deb-repo
	chmod 755 ${PACKAGEDIR1ARM64}/usr/bin/local-deb-repo
	cp -b static/remote-deb-repo ${PACKAGEDIR1ARM64}/usr/bin/remote-deb-repo
	chmod 755 ${PACKAGEDIR1ARM64}/usr/bin/remote-deb-repo
	dpkg-deb --build ${PACKAGEDIR1ARM64}
	rm -rf ${PACKAGEDIR1ARM64}

skybian-skywire-package-armhf: #need a more efficient method
	mkdir -p ${PACKAGEDIR1ARMHF}/DEBIAN ${PACKAGEDIR1ARMHF}/usr/bin ${PACKAGEDIR1ARMHF}/etc/systemd/system ${PACKAGEDIR1ARMHF}/var/cache/apt/repo
	echo "Package: skybian-skywire" > ${PACKAGEDIR1ARMHF}/DEBIAN/control
	echo "Version: ${PACKAGEVERSION}" >> ${PACKAGEDIR1ARMHF}/DEBIAN/control
	echo "Priority: optional" >> ${PACKAGEDIR1ARMHF}/DEBIAN/control
	echo "Section: web" >> ${PACKAGEDIR1ARMHF}/DEBIAN/control
	echo "Architecture: armhf" >> ${PACKAGEDIR1ARMHF}/DEBIAN/control
	echo "Depends: skywire" >> ${PACKAGEDIR1ARMHF}/DEBIAN/control
	echo "Maintainer: SkycoinProject" >> ${PACKAGEDIR1ARMHF}/DEBIAN/control
	echo "Description: Skywire helper scripts" >> ${PACKAGEDIR1ARMHF}/DEBIAN/control
	${OPTS} env GOOS=linux GOARCH=arm GOARM=6 go build ${BUILD_OPTS} -o ./${PACKAGEDIR1ARMHF}/usr/bin/readonlycache ./static/readonlycache.go
	${OPTS} env GOOS=linux GOARCH=arm GOARM=6 go build ${BUILD_OPTS} -o ./${PACKAGEDIR1ARMHF}/usr/bin/skyconf ./cmd/skyconf
	cp -b static/skywire ${PACKAGEDIR1ARMHF}/usr/bin/skywire
	chmod 755 ${PACKAGEDIR1ARMHF}/usr/bin/skywire
	cp -b static/skywire ${PACKAGEDIR1ARMHF}/usr/bin/skybian-firstrun
	chmod 755 ${PACKAGEDIR1ARMHF}/usr/bin/skybian-firstrun
	cp -b static/skybian-firstrun.service  ${PACKAGEDIR1ARMHF}/etc/systemd/system/skybian-firstrun.service
	chmod 644 ${PACKAGEDIR1ARMHF}/etc/systemd/system/skybian-firstrun.service
	cp -b static/local-deb-repo ${PACKAGEDIR1ARMHF}/usr/bin/local-deb-repo
	chmod 755 ${PACKAGEDIR1ARMHF}/usr/bin/local-deb-repo
	cp -b static/remote-deb-repo ${PACKAGEDIR1ARMHF}/usr/bin/remote-deb-repo
	chmod 755 ${PACKAGEDIR1ARMHF}/usr/bin/remote-deb-repo
	dpkg-deb --build ${PACKAGEDIR1ARMHF}
	rm -rf ${PACKAGEDIR1ARMHF}

skybian-package-amd64:
	mkdir -p ${PACKAGEDIR2}/DEBIAN ${PACKAGEDIR2}/usr/bin ${PACKAGEDIR2}/etc/profile.d ${PACKAGEDIR2}/etc/update-motd.d/
	echo "Package: skybian" > ${PACKAGEDIR2}/DEBIAN/control
	echo "Version: ${PACKAGEVERSION}" >> ${PACKAGEDIR2}/DEBIAN/control
	echo "Priority: optional" >> ${PACKAGEDIR2}/DEBIAN/control
	echo "Section: web" >> ${PACKAGEDIR2}/DEBIAN/control
	echo "Architecture: amd64" >> ${PACKAGEDIR2}/DEBIAN/control
	echo "Maintainer: SkycoinProject" >> ${PACKAGEDIR2}/DEBIAN/control
	echo "Description: Skybian image configuration" >> ${PACKAGEDIR2}/DEBIAN/control
	cp -b "static/armbian-check-first-login.sh"  "${PACKAGEDIR2}/etc/profile.d/armbian-check-first-login.sh"
	chmod 755 "${PACKAGEDIR2}/etc/profile.d/armbian-check-first-login.sh"
	cp -b "static/armbian-check-first-login.sh" "${PACKAGEDIR2}/etc/profile.d/armbian-check-first-login.sh"
	chmod 755 "${PACKAGEDIR2}/etc/profile.d/armbian-check-first-login.sh"
	cp -b "static/10-skybian-header" "${PACKAGEDIR2}/etc/update-motd.d/"
	chmod 755 "${PACKAGEDIR2}/etc/update-motd.d/10-skybian-header"
	cp -b "static/armbian-motd" "${PACKAGEDIR2}/etc/default"
	dpkg-deb --build ${PACKAGEDIR2}
	rm -rf ${PACKAGEDIR2}

skybian-package-arm64:
	mkdir -p ${PACKAGEDIR2ARM64}/DEBIAN ${PACKAGEDIR2ARM64}/usr/bin ${PACKAGEDIR2ARM64}/etc/profile.d ${PACKAGEDIR2ARM64}/etc/update-motd.d/
	echo "Package: skybian" > ${PACKAGEDIR2ARM64}/DEBIAN/control
	echo "Version: ${PACKAGEVERSION}" >> ${PACKAGEDIR2ARM64}/DEBIAN/control
	echo "Priority: optional" >> ${PACKAGEDIR2ARM64}/DEBIAN/control
	echo "Section: web" >> ${PACKAGEDIR2ARM64}/DEBIAN/control
	echo "Architecture: arm64" >> ${PACKAGEDIR2ARM64}/DEBIAN/control
	echo "Maintainer: SkycoinProject" >> ${PACKAGEDIR2ARM64}/DEBIAN/control
	echo "Description: Skybian image configuration" >> ${PACKAGEDIR2ARM64}/DEBIAN/control
	cp -b "static/armbian-check-first-login.sh"  "${PACKAGEDIR2ARM64}/etc/profile.d/armbian-check-first-login.sh"
	chmod 755 "${PACKAGEDIR2ARM64}/etc/profile.d/armbian-check-first-login.sh"
	cp -b "static/armbian-check-first-login.sh" "${PACKAGEDIR2ARM64}/etc/profile.d/armbian-check-first-login.sh"
	chmod 755 "${PACKAGEDIR2ARM64}/etc/profile.d/armbian-check-first-login.sh"
	cp -b "static/10-skybian-header" "${PACKAGEDIR2ARM64}/etc/update-motd.d/"
	chmod 755 "${PACKAGEDIR2ARM64}/etc/update-motd.d/10-skybian-header"
	cp -b "static/armbian-motd" "${PACKAGEDIR2ARM64}/etc/default"
	dpkg-deb --build ${PACKAGEDIR2ARM64}
	rm -rf ${PACKAGEDIR2ARM64}

skybian-package-armhf:
	mkdir -p ${PACKAGEDIR2ARMHF}/DEBIAN ${PACKAGEDIR2ARMHF}/usr/bin ${PACKAGEDIR2ARMHF}/etc/profile.d ${PACKAGEDIR2ARMHF}/etc/update-motd.d/
	echo "Package: skybian" > ${PACKAGEDIR2ARMHF}/DEBIAN/control
	echo "Version: ${PACKAGEVERSION}" >> ${PACKAGEDIR2ARMHF}/DEBIAN/control
	echo "Priority: optional" >> ${PACKAGEDIR2ARMHF}/DEBIAN/control
	echo "Section: web" >> ${PACKAGEDIR2ARMHF}/DEBIAN/control
	echo "Architecture: armhf" >> ${PACKAGEDIR2ARMHF}/DEBIAN/control
	echo "Maintainer: SkycoinProject" >> ${PACKAGEDIR2ARMHF}/DEBIAN/control
	echo "Description: Skybian image configuration" >> ${PACKAGEDIR2ARMHF}/DEBIAN/control
	cp -b "static/armbian-check-first-login.sh"  "${PACKAGEDIR2ARMHF}/etc/profile.d/armbian-check-first-login.sh"
	chmod 755 "${PACKAGEDIR2ARMHF}/etc/profile.d/armbian-check-first-login.sh"
	cp -b "static/armbian-check-first-login.sh" "${PACKAGEDIR2ARMHF}/etc/profile.d/armbian-check-first-login.sh"
	chmod 755 "${PACKAGEDIR2ARMHF}/etc/profile.d/armbian-check-first-login.sh"
	cp -b "static/10-skybian-header" "${PACKAGEDIR2ARMHF}/etc/update-motd.d/"
	chmod 755 "${PACKAGEDIR2ARMHF}/etc/update-motd.d/10-skybian-header"
	cp -b "static/armbian-motd" "${PACKAGEDIR2ARMHF}/etc/default"
	dpkg-deb --build ${PACKAGEDIR2ARMHF}
	rm -rf ${PACKAGEDIR2ARMHF}

all-packages:	skybian-skywire-package-amd64	skybian-skywire-package-arm64	skybian-skywire-package-armhf skybian-package-amd64 skybian-package-arm64 skybian-package-armhf

build-skyimager-gui: ## builds skyimager GUI
	./build-skyimager.sh

skyimager-gui-package: ##package skyimager gui. Manually because above is broken.
	mkdir -p ${SKYIMAGERPACKAGEDIR}/DEBIAN ${SKYIMAGERPACKAGEDIR}/usr/bin
	echo "Package: skyimager" > ${SKYIMAGERPACKAGEDIR}/DEBIAN/control
	echo "Version: ${PACKAGEVERSION}" >> ${SKYIMAGERPACKAGEDIR}/DEBIAN/control
	echo "Priority: optional" >> ${SKYIMAGERPACKAGEDIR}/DEBIAN/control
	echo "Section: web" >> ${SKYIMAGERPACKAGEDIR}/DEBIAN/control
	echo "Architecture: amd64" >> ${SKYIMAGERPACKAGEDIR}/DEBIAN/control
	echo "Maintainer: SkycoinProject" >> ${SKYIMAGERPACKAGEDIR}/DEBIAN/control
	echo "Description: Skybian image creation and configuration tool" >> ${SKYIMAGERPACKAGEDIR}/DEBIAN/control
	${OPTS} GOARCH="amd64" go build ${BUILD_OPTS} -o ./${SKYIMAGERPACKAGEDIR}/usr/bin/skyimager-gui ./cmd/skyimager-gui
	dpkg-deb --build ${SKYIMAGERPACKAGEDIR}
	rm -rf ${SKYIMAGERPACKAGEDIR}

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
