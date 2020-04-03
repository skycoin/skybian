#!/usr/bin/env bash

# shellcheck source=./build.conf
source "$(pwd)/build.conf"
git tag "${VERSION}" || exit 1
git push origin "${VERSION}" || exit 1