#!/usr/bin/env bash

# load env variables.

# shellcheck source=./build.conf
source "$(pwd)/build.conf"

GOBIN=$(pwd)/bin
export GOBIN

# Run fyne-cross
go get github.com/fyne-io/fyne-cross || exit 1

./bin/fyne-cross \
  linux \
  -app-id com.skycoin.skyimager \
  -arch amd64 \
  -icon ./cmd/skyimager-gui/static/icon.png \
  ./cmd/skyimager-gui || exit 1
  
./bin/fyne-cross \
  windows \
  -app-id com.skycoin.skyimager \
  -arch amd64 \
  -icon ./cmd/skyimager-gui/static/icon.png \
  ./cmd/skyimager-gui || exit 1

# Darwin image needs to be built seperatly and can oly be with xcode
# ./bin/fyne-cross \
#   darwin \
#   -app-id com.skycoin.skyimager \
#   -arch amd64 \
#   -icon ./cmd/skyimager-gui/static/icon.png \
#   ./cmd/skyimager-gui || exit 1

# Compress bins.
FYNE=$(pwd)/fyne-cross/bin
TARGETS=("linux-amd64" "windows-amd64")

for target in "${TARGETS[@]}"; do
  cd "$FYNE" || exit 1
  dst="./skyimager-$target-$VERSION"
  tar -czf "$dst.tar.gz" "$target"/* || exit 1
done

cd "$(pwd)" || 0
