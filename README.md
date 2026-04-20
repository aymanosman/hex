# Hex

An ARPG in [Odin](https://odin-lang.org) + [raylib](https://www.raylib.com).

## Build and run

```
./build.sh
./build/hex
```

Requires `odin` on PATH (`brew install odin` on macOS, or see
https://odin-lang.org/docs/install/). No other prerequisites — raylib
ships prebuilt for Linux, macOS, and Windows inside Odin's vendor
tree.

## Controls (v0.1)

- `WASD` — move
- `Left click` — melee attack toward the cursor
- `ESC` / close window — quit

## Layout

- `src/` — game code (4 files, single `package main`)
- `docs/` — architecture, roadmap, setup notes
- `doc/log/` — dated session notes
