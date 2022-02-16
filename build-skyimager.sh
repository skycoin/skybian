#!/usr/bin/env bash

# load env variables.

# shellcheck source=./build.conf
source "$(pwd)/build.conf"

GOBIN=$(pwd)/bin
export GOBIN

# Run fyne-cross
go get -d github.com/fyne-io/fyne-cross || exit 1

./bin/fyne-cross \
  linux \
  -app-id com.skycoin.skyimager \
  -arch amd64 \
  -icon ./cmd/skyimager-gui/static/icon.png \
  ./cmd/skyimager-gui
  
./bin/fyne-cross \
  windows \
  -app-id com.skycoin.skyimager \
  -arch amd64 \
  -icon ./cmd/skyimager-gui/static/icon.png \
  ./cmd/skyimager-gui || exit 1

# Darwin image needs to be built seperatly and can oly be with xcode
docker pull skycoin/fyne-cross:latest
docker tag skycoin/fyne-cross:latest fyneio/fyne-cross:1.1-darwin
./bin/fyne-cross \
  darwin \
  -app-id com.skycoin.skyimager \
  -arch amd64 \
  -icon ./cmd/skyimager-gui/static/icon.png \
  ./cmd/skyimager-gui || exit 1

# Compress bins.
FYNE=$(pwd)/fyne-cross/bin
TARGETS=("linux-amd64" "windows-amd64" "darwin-amd64")

for target in "${TARGETS[@]}"; do
  cd "$FYNE" || exit 1
  dst="./skyimager-$target-$VERSION"
  if [ $target == "linux-amd64" ]
  then
    tar -czf "$dst.tar.gz" "$target"/* || exit 1
  else
    zip "$dst.zip" "$target"/* || exit 1
  fi
done

cd "$(pwd)" || 0
