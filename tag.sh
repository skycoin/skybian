#!/usr/bin/env bash

# shellcheck source=./build.conf
source "$(pwd)/build.conf"
git tag -f "${VERSION}"
git push -f origin "${VERSION}" || exit 1
