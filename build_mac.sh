#!/bin/zsh
set -e

# One-command build for macOS.
# Handles first-run bootstrap of the Odin compiler + third-party SDK
# files we don't commit, then builds. See docs/setup.md for the why.

ROOT="${0:A:h}"
cd "$ROOT"

# --- prerequisite check ----------------------------------------------------
if ! command -v cc >/dev/null 2>&1; then
  echo "error: cc not on PATH. Install Xcode Command Line Tools with:"
  echo "       xcode-select --install"
  exit 1
fi

# --- pinned Odin toolchain -------------------------------------------------
# We pin to a specific release because blueprint code uses
# `core:os/os2`, which was merged into `core:os` in newer Odin.
# Bump this version + port the os2 calls when we want to move forward.
ODIN_VERSION="dev-2025-12"
ODIN_CACHE=".cache/odin"
ODIN_BIN="$ODIN_CACHE/odin"

if [ ! -x "$ODIN_BIN" ]; then
  echo "Downloading pinned Odin $ODIN_VERSION..."
  arch="$(uname -m)"
  case "$arch" in
    arm64|aarch64) odin_arch="arm64" ;;
    x86_64|amd64)  odin_arch="amd64" ;;
    *) echo "error: unsupported arch $arch"; exit 1 ;;
  esac
  url="https://github.com/odin-lang/Odin/releases/download/$ODIN_VERSION/odin-macos-$odin_arch-$ODIN_VERSION.tar.gz"
  mkdir -p "$ODIN_CACHE"
  tmp_tar="$(mktemp -t odin-XXXXXX.tar.gz)"
  curl -fsSL --retry 3 -o "$tmp_tar" "$url"
  extract_dir="$(mktemp -d -t odin-extract-XXXXXX)"
  tar xzf "$tmp_tar" -C "$extract_dir"
  # Release tarballs extract to odin-macos-<arch>-nightly+<date>/ — pick it.
  inner="$(find "$extract_dir" -maxdepth 1 -mindepth 1 -type d | head -1)"
  rm -rf "$ODIN_CACHE"
  mv "$inner" "$ODIN_CACHE"
  rm -f "$tmp_tar"
  rm -rf "$extract_dir"
fi

# Prepend our pinned Odin to PATH for the rest of the script.
PATH="$ROOT/$ODIN_CACHE:$PATH"
export PATH

# --- bootstrap third-party SDK files --------------------------------------
BLUEPRINT_REPO="https://github.com/baldgg/blueprint.git"
CACHE_BLUEPRINT=".cache/blueprint"

need_bootstrap=0
[ ! -d sauce/fmod ] && need_bootstrap=1
[ ! -d res/fmod ] && need_bootstrap=1
[ ! -x sokol-shdc-mac ] && need_bootstrap=1

if [ "$need_bootstrap" -eq 1 ]; then
  echo "Bootstrapping FMOD SDK and sokol-shdc from upstream blueprint..."
  if [ ! -d "$CACHE_BLUEPRINT/.git" ]; then
    mkdir -p "$(dirname "$CACHE_BLUEPRINT")"
    git clone --depth 1 "$BLUEPRINT_REPO" "$CACHE_BLUEPRINT"
  fi

  [ ! -d sauce/fmod ] && cp -R "$CACHE_BLUEPRINT/sauce/fmod" sauce/fmod
  [ ! -d res/fmod ]   && cp -R "$CACHE_BLUEPRINT/res/fmod"   res/fmod
  if [ ! -x sokol-shdc-mac ]; then
    cp "$CACHE_BLUEPRINT/sokol-shdc-mac" sokol-shdc-mac
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
