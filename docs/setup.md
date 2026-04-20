# Hex — Setup

Hex is based on the [baldgg/blueprint](https://github.com/baldgg/blueprint)
template (Odin + Sokol + FMOD). This doc covers getting a clean clone to
build and run on Windows, plus known friction points.

## Honest caveat
This repo was initialised from a Linux sandbox. I could not perform a
Windows build to verify. Everything below is derived from reading the
blueprint scripts (`build.bat`, `sauce/build/build.odin`) and the
blueprint author's README. Treat the Windows steps as the
documented-but-unverified path; confirm on first run and edit this file
if you hit anything surprising.

## Prerequisites

1. **Odin compiler.** Install from https://odin-lang.org/docs/install/.
   Any recent release should work — the blueprint's `build.odin` uses
   `os/os2` and `#+feature dynamic-literals`, which need a reasonably
   current Odin. Put `odin.exe` on PATH.
2. **FMOD Studio API (Windows, 64-bit).** Download from
   https://www.fmod.com/download (free account required). Install the
   "FMOD Engine" (sometimes labelled "FMOD Studio API"). This is NOT
   redistributed in this repo for licensing reasons — see next section.
3. **Visual Studio Build Tools** (or full Visual Studio). Odin on Windows
   uses the MSVC linker for C ABI interop. Install the "Desktop
   development with C++" workload.
4. **(Optional) RAD Debugger** — the blueprint author recommends it for
   step-through debugging. Grab from
   https://github.com/EpicGamesExt/raddebugger/releases.
5. **(Optional) Aseprite** — needed for asset iteration via
   `asset_workbench/aseprite_asset_export.lua`. Not required to build.

## One-time asset + SDK restore

A few large binary assets are deliberately NOT committed to this repo
(see `.gitignore`). You need to fetch them once after cloning:

### FMOD SDK (required to build)
The blueprint ships the FMOD headers and libs inside `sauce/fmod/`. We
do not redistribute them. To restore:

```
# From the root of your Hex checkout:
git clone --depth 1 https://github.com/baldgg/blueprint.git .blueprint-src
robocopy .blueprint-src\sauce\fmod sauce\fmod /E
robocopy .blueprint-src\res\fmod  res\fmod  /E
rmdir /s /q .blueprint-src
```

(Or copy manually from a fresh blueprint clone — the relevant trees are
`sauce/fmod/` for SDK headers+libs, and `res/fmod/*.bank` for the
placeholder banks.) Long term we'll replace the banks with our own.

### sokol-shdc (required to build)
The shader cross-compiler. The blueprint commits all three (win/mac/linux)
binaries; we don't — they're ~40 MB combined. Download the matching one
from https://github.com/floooh/sokol-tools-bin/tree/master/bin and place
it next to `build.bat`:

- Windows → `sokol-shdc-win.exe`
- Mac     → `sokol-shdc-mac`
- Linux   → `sokol-shdc-linux`

### Sokol DLLs
These live under `sauce/sokol/` and **are** committed (small, required at
link time, no licensing concern). If they ever go missing, regenerate
with `sauce/sokol/build_clibs_windows.cmd`.

## Building (Windows)

```
build.bat
```

Under the hood this runs `odin run sauce\build -debug -- testarg`, which
compiles and runs the build driver in `sauce/build/build.odin`. The
driver:
1. Writes `sauce/generated.odin` with the current target/platform.
2. Invokes `sokol-shdc-win.exe` to compile `sauce/shader.glsl` into
   `sauce/generated_shader.odin`.
3. Calls `odin build sauce` to produce `build/windows_debug/game.exe`.
4. Copies the FMOD DLLs next to the exe.

Run the game by double-clicking `build/windows_debug/game.exe`, or launch
it from RAD Debugger. **It must be launched from the repo root** (the
game reads `res/` relative to the cwd).

## Building on other platforms

- **Mac**: `./build_mac.sh`. FMOD dylibs expected at
  `sauce/fmod/*/lib/darwin/`. Blueprint author notes this is untested.
- **Linux**: `./build_linux.sh`. Blueprint README states FMOD support on
  Linux is a TODO — the build script skips copying FMOD libs but the
  Odin code still links FMOD, so expect link errors until we either
  stub FMOD on Linux or wire the Linux SDK in. Not a priority; we're
  Windows-first.

## Friction / things to fix later

- `core_main.odin` unconditionally imports `core:sys/windows` and calls
  `win32.FreeConsole()` (guarded behind `when ODIN_OS == .Windows` but
  the import is top-level; Odin may or may not elide it cleanly on other
  OSes — the blueprint has a `// wait, how is this building on mac?`
  comment right there).
- The game's window title is still `"Template [bald]"` in `game.odin`.
  Will change when we rename to Hex properly.
- `atlas.png` and `font.png` are dumped to the repo root on Windows
  builds (see `load_sprites_into_atlas`). They're in `.gitignore`.
- Generated files `sauce/generated.odin` and
  `sauce/generated_shader.odin` are produced every build and gitignored.

## Verification

On a fresh clone, after the SDK restore, a successful `build.bat` should:
- Produce `build/windows_debug/game.exe` (~a few MB).
- Launch a 1280x720 window titled "Template [bald]" showing a pixel-art
  player sprite, a red-tinted copy of the player, "sugon" text, a
  "hello world." UI string, and a repeating background.
- WASD moves the player. Alt+Enter toggles fullscreen. Left click logs a
  "schloop at …" line and plays a sound if FMOD is wired up.

If any of that fails, log the failure + your workaround in this file.
