#!/usr/bin/env bash

# load env variables.

# shellcheck source=./build.conf
source "$(pwd)/build.conf"

GOBIN=$(pwd)/bin
export GOBIN

# Run fyne-cross

go get github.com/lucor/fyne-cross/cmd/fyne-cross

./bin/fyne-cross \
  -appID com.skycoin.skyimager \
  -targets=linux/amd64,darwin/amd64,windows/amd64 \
  -icon=./cmd/skyimager-gui/assets/icon.png -v \
  ./cmd/skyimager-gui

# Compress bins.
FYNE=./fyne-cross/bin
TARGETS=("linux-amd64" "darwin-amd64" "windows-amd64")

for target in "${TARGETS[@]}"; do
  dst="$FYNE/skyimager-$target-$VERSION"

  tar -czf "$dst.tar" "$FYNE/$target"
  xz -vzT0 "$dst.tar"
done
