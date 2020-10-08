#!/usr/bin/env bash

# load env variables.

# shellcheck source=./build.conf
source "$(pwd)/build.conf"

GOBIN=$(pwd)/bin
export GOBIN

# Run fyne-cross

go get github.com/lucor/fyne-cross/cmd/fyne-cross || exit 1

./bin/fyne-cross \
  -appID com.skycoin.skyimager \
  -targets=linux/amd64,darwin/amd64,windows/amd64 \
  -icon=./cmd/skyimager-gui/assets/icon.png -v \
  ./cmd/skyimager-gui || exit 1

# Compress bins.
FYNE=$(pwd)/fyne-cross/bin
TARGETS=("linux-amd64" "darwin-amd64" "windows-amd64")

for target in "${TARGETS[@]}"; do
  cd "$FYNE" || exit 1
  dst="./skyimager-$target-$VERSION"
  tar -czf "$dst.tar.gz" "$target"/* || exit 1
done

cd "$(pwd)" || 0
