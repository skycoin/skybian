#!/usr/bin/env bash

# shellcheck source=./build.conf
source "$(pwd)/build.conf" && git tag "${VERSION}"