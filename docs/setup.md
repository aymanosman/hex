# Hex — Setup

## One command

```
./build.sh
./build/hex
```

## Prerequisites

- **Odin compiler** on PATH. `brew install odin` on macOS; see
  https://odin-lang.org/docs/install/ for everywhere else. Current
  stable (`dev-2026-04` at time of writing) works; no version pin.
- **A C toolchain** (gcc/clang). The Odin linker invokes it. Xcode
  Command Line Tools on macOS, `build-essential` on Linux, MSVC Build
  Tools on Windows.

No other dependencies. `vendor:raylib` is bundled with Odin and ships
prebuilt static libraries for Linux, macOS (Intel + ARM), Windows, and
WASM targets.

## History

Earlier iterations of this project tried to build on top of the
[baldgg/blueprint](https://github.com/baldgg/blueprint) Sokol+FMOD
template. That path turned out to be high-friction (unmaintained Linux
support, licensed FMOD SDK, sokol-shdc↔sokol-odin version skew,
recently-removed `core:os/os2`). See
[`doc/log/2026-04-20-upstream-linux-blockers.org`](../doc/log/2026-04-20-upstream-linux-blockers.org)
for the full post-mortem. We dropped blueprint in favour of raylib;
zero-prereq build was worth more than the sokol control we gave up.
