.DEFAULT_GOAL := help

PROJECT_BASE := github.com/SkycoinProject/skybian
OPTS?=GO111MODULE=on

TEST_OPTS_BASE:=-cover -timeout=5m

RACE_FLAG:=-race
GOARCH:=$(shell go env GOARCH)

ifneq (,$(findstring 64,$(GOARCH)))
    TEST_OPTS_BASE:=$(TEST_OPTS_BASE) $(RACE_FLAG)
endif

TEST_OPTS_NOCI:=-$(TEST_OPTS_BASE) -v
TEST_OPTS:=$(TEST_OPTS_BASE) -tags no_ci

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
	${OPTS} goimports -w -local ${PROJECT_BASE} ./internal

test: ## Run tests
	-go clean -testcache &>/dev/null
	${OPTS} go test ${TEST_OPTS} ./internal/...
	${OPTS} go test ${TEST_OPTS} ./pkg/...

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
