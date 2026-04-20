# Hex — Setup

Hex is based on the [baldgg/blueprint](https://github.com/baldgg/blueprint)
template (Odin + Sokol + FMOD).

## TL;DR (macOS)

```
./build_mac.sh
./build/mac_debug/game
```

First run of `build_mac.sh` takes a minute or two — it fetches the FMOD
SDK + sokol-shdc (we don't commit those) and compiles the sokol C
shims. Subsequent runs skip all of that. The game must be launched
from the repo root (it reads `res/` relative to cwd).

## Honest caveat

This repo was initialised from a Linux sandbox. I can't actually run a
macOS build from here, so the `build_mac.sh` path is plausible but
unverified. If it breaks, paste the error and we'll fix it. The
blueprint author's README also flags the macOS path as "untested".

## Prerequisites (macOS)

1. **Xcode Command Line Tools.** `xcode-select --install` — the sokol
   C shims are compiled from Objective-C via `cc`.
2. **Git + curl.** For the first-run bootstrap (see below). Both are
   part of Command Line Tools.

Odin is **not** a prerequisite — `build_mac.sh` downloads and pins a
specific Odin release into `.cache/odin/`. We do this because the
blueprint imports `core:os/os2`, which was merged into `core:os` in
current Odin releases. A `brew install odin` would install the latest,
which doesn't parse the blueprint code. The pinned version is set at
the top of `build_mac.sh`; bump it when we port the os2 call sites.

Mac FMOD dylibs are shipped as universal binaries (x86_64 + arm64 in
the same file), so the build works on both Intel and Apple Silicon.

**Optional:** Aseprite, if you want to iterate on sprites via
`asset_workbench/aseprite_asset_export.lua`. Not required to build.

## What `build_mac.sh` does

The script is the one-command entry point. On each run it:

1. Checks that `cc` is on PATH.
2. **Odin bootstrap** (first run only): downloads the pinned Odin
   release into `.cache/odin/` and uses it for the remainder of the
   build. Any system-installed `odin` is ignored.
3. **SDK bootstrap** (first run only): if `sauce/fmod/`, `res/fmod/`,
   or `sokol-shdc-mac` is missing, shallow-clones the upstream
   blueprint into `.cache/blueprint/` and copies the three pieces in.
   We don't commit the FMOD SDK (licensing) or the ~40 MB sokol-shdc
   binaries.
4. Builds the sokol C libraries once (`sauce/sokol/build_clibs_macos.sh`).
5. Runs `odin run ./sauce/build -- target:mac`, which generates
   `sauce/generated.odin` + `sauce/generated_shader.odin`, compiles
   `sauce`, and copies FMOD dylibs into `build/mac_debug/`.

## Windows path (not yet verified)

Install Odin + MSVC Build Tools + FMOD Engine. For the bootstrap
equivalent, run from the repo root:

```
git clone --depth 1 https://github.com/baldgg/blueprint.git .cache\blueprint
robocopy .cache\blueprint\sauce\fmod sauce\fmod /E
robocopy .cache\blueprint\res\fmod  res\fmod  /E
copy    .cache\blueprint\sokol-shdc-win.exe sokol-shdc-win.exe
```

Then `build.bat` and `build\windows_debug\game.exe`. We'll fold this
into a `build_win.bat` when someone actually needs it.

## Linux path

Blueprint's Linux FMOD support is explicitly a TODO; the build script
skips copying FMOD libs but the Odin code still links FMOD. Expect
link errors until we either stub FMOD on Linux or wire the Linux SDK
in. Not a priority.

## Friction / things to fix later

- `core_main.odin:28` unconditionally imports `core:sys/windows`. The
  `FreeConsole()` call is guarded by `when ODIN_OS == .Windows`, but
  the import is top-level. Appears to compile on macOS regardless
  (blueprint author notes "wait, how is this building on mac?").
  If it ever breaks, split into `core_main_windows.odin` using Odin's
  filename-suffix compilation rules.
- The game's window title is still `"Template [bald]"` in
  `game.odin`. Changes during Phase 0.
- `atlas.png` is dumped to the repo root on Windows builds only (see
  `load_sprites_into_atlas`), already gitignored.
- Generated files `sauce/generated.odin` and
  `sauce/generated_shader.odin` are produced every build and
  gitignored.

## Verification

A successful first run should:
- Bootstrap the SDK files into `sauce/fmod/`, `res/fmod/`, and
  `sokol-shdc-mac` (~70 MB of blueprint content cached in
  `.cache/blueprint/`).
- Build `build/mac_debug/game` alongside `libfmod.dylib`,
  `libfmodstudio.dylib`, and their `L.dylib` debug variants.
- Launch a 1280x720 window titled "Template [bald]" showing a
  pixel-art player sprite, a red-tinted copy, "sugon" text, a
  "hello world." string, and a repeating background.
- WASD moves the player. Alt+Enter toggles fullscreen. Left click
  logs "schloop at …" and plays a sound.

If any of that fails, log the failure and the workaround in this
file.
