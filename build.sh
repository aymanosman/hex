#!/bin/bash
# Scratch-path build. Requires `odin` on PATH (brew install odin, or
# https://odin-lang.org/docs/install/). No other prerequisites —
# raylib libs ship with Odin for Linux, macOS, and Windows targets.
set -e

cd "$(dirname "$0")"
mkdir -p build

odin build ./src -out:build/hex -debug
echo "built build/hex"
