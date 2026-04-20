#!/bin/zsh
set -e

# One-command build for macOS.
# Handles first-run bootstrap of the third-party SDK files we don't
# commit, then builds. See docs/setup.md for the why.

ROOT="${0:A:h}"
cd "$ROOT"

# --- prerequisite check ----------------------------------------------------
if ! command -v odin >/dev/null 2>&1; then
  echo "error: odin not on PATH. Install with 'brew install odin'"
  echo "       or follow https://odin-lang.org/docs/install/"
  exit 1
fi
if ! command -v cc >/dev/null 2>&1; then
  echo "error: cc not on PATH. Install Xcode Command Line Tools with:"
  echo "       xcode-select --install"
  exit 1
fi

# --- bootstrap third-party SDK files --------------------------------------
BLUEPRINT_REPO="https://github.com/baldgg/blueprint.git"
CACHE_DIR=".cache/blueprint"

need_bootstrap=0
[ ! -d sauce/fmod ] && need_bootstrap=1
[ ! -d res/fmod ] && need_bootstrap=1
[ ! -x sokol-shdc-mac ] && need_bootstrap=1

if [ "$need_bootstrap" -eq 1 ]; then
  echo "Bootstrapping FMOD SDK and sokol-shdc from upstream blueprint..."
  if [ ! -d "$CACHE_DIR/.git" ]; then
    mkdir -p "$(dirname "$CACHE_DIR")"
    git clone --depth 1 "$BLUEPRINT_REPO" "$CACHE_DIR"
  fi

  [ ! -d sauce/fmod ] && cp -R "$CACHE_DIR/sauce/fmod" sauce/fmod
  [ ! -d res/fmod ]   && cp -R "$CACHE_DIR/res/fmod"   res/fmod
  if [ ! -x sokol-shdc-mac ]; then
    cp "$CACHE_DIR/sokol-shdc-mac" sokol-shdc-mac
    chmod +x sokol-shdc-mac
  fi
fi

# --- sokol C libs ----------------------------------------------------------
mkdir -p build/mac_debug

(
  cd ./sauce/sokol/ || exit 1
  if [ ! -e ./app/sokol_app_macos_arm64_metal_debug.a ]; then
    echo "Building sokol C libs for macOS..."
    zsh build_clibs_macos.sh
  fi
)

# --- build + run -----------------------------------------------------------
odin run ./sauce/build -- target:mac
