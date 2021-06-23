.DEFAULT_GOAL := help

PROJECT_BASE := github.com/skycoin/skybian
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

.PHONY: dep

dep:
	GO111MODULE=on go mod vendor -v

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
	rm -rf ./output/*
	./build.sh -c 2>&1 /dev/null
	./build.sh
	./build.sh -p

build-skyimager-gui: ## builds skyimager GUI
	./build-skyimager.sh

run-skyimager: ## Run skyimager
	echo ${IMG_BOOT_PARAMS} | go run ./cmd/skyimager/skyimager.go

run-skyimager-gui: ## Builds skyimager GUI
	mkdir -p ./bin
	${OPTS} go run ./cmd/skyimager-gui/skyimager-gui.go

tag: ## Make git tag using VERSION in build.conf
	./tag.sh

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
