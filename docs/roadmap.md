# Hex — Roadmap

## Vertical-slice milestone (v0.1 "punch something")

Goal: one playable loop — spawn into a room, run around, hit an enemy,
kill it, pick up loot it drops. No menus, no UI polish, no saving.
Target: a 30-second demo we can run, show, and iterate from.

Scope (matches the brief):
- One character, WASD movement.
- Basic melee attack (one button, one swing arc or hitbox).
- One enemy type that moves toward the player and dies when hit.
- One small room with walls the player and enemy collide with.
- One loot drop on kill that the player can pick up.

Out of scope for v0.1: classes, skills, inventory UI, stats, levelling,
multiple rooms, saves, audio design (hook up, don't author), art
polish. We'll scaffold those after the slice.

## What the blueprint already gives us

- Window, main loop, variable delta. (`core_main.odin`)
- Sokol-based 2D pixel renderer with atlas, sprite strips, z-layers,
  drop-shadow text, screen/world/clip coord spaces.
  (`core_render.odin`, `core_draw.odin`)
- Keyboard + mouse input with edge/held state and consume semantics,
  plus an `Input_Action → Key_Code` binding map.
  (`core_input.odin`, `game_utils.odin`)
- Entity pool with 2048-slot flat megastruct, handles with IDs, update
  and draw procs per kind, per-frame scratch blocks. Animation update
  is already folded into the main loop. (`entity.odin`, `game.odin`)
- Camera follow and coord-space helpers. (`game_utils.odin`)
- FMOD-backed sound with one-shots and position-tracked continuous
  emitters. (`core_sound.odin`)
- Aseprite → PNG export pipeline via
  `asset_workbench/aseprite_asset_export.lua`.
- Build pipeline with per-platform shader cross-compile.
  (`sauce/build/build.odin`)

## What we need to build

- Tile/room representation (even if it's hardcoded bounds for now).
- AABB collision — `sauce/utils/shape/collision.odin` is present, but
  no entity-level collision usage yet. We need entity vs. wall and
  entity vs. entity queries.
- Hitboxes — spawn-on-attack, lifetime in frames, team/damage fields.
- Health / damage / death for entities.
- A simple enemy AI (chase the player).
- Loot drops — an item entity, a pickup hitbox, a tiny inventory
  counter (even just "gold: N" text).
- A couple of placeholder sprites we actually ship with the game
  (player already exists; we need enemy, wall tile, loot).

## Task breakdown

Each task is 1–4 hours. Order matters where noted. Flags:
(B) = blueprint already handles, just a configuration nudge.
(N) = net-new code.

### Phase 0 — Project hygiene (before gameplay)
1. **Rename the game.** Change `WINDOW_TITLE` to `"Hex"`, update
   `EXE_NAME` in `sauce/build/build.odin` to `hex`, bump `VERSION`.
   Remove the "hello world." debug text and the bald/fmod demo draws
   in `game_draw`. (B, 1h)
2. **Strip blueprint demo content.** Delete `.thing1`, `bald_logo`,
   `fmod_logo`, the `draw_sprite({10,10}, …)` / "sugon" text calls.
   Keep player + shadow + bg. Adjust `Sprite_Name` enum. (B, 1h)
3. **Baseline CI/build sanity.** First actual Windows build on the
   lead dev's machine; update `docs/setup.md` with any real steps
   that differed. (B, 1h)

### Phase 1 — Rooms and walls
4. **Room struct + hardcoded test room.** Add `Room` with an array of
   `Rect` wall segments and a spawn point. Place one 20×15 tile room
   at origin. Draw walls as solid-colour rects on `.playspace`. (N, 2h)
5. **AABB collision helper for entities.** Wire
   `utils/shape/collision.odin` into an `entity_vs_walls(e, room)` that
   resolves penetration on X then Y (classic swept-axis). Call it in
   the player update after movement. (N, 3h)
6. **Camera clamp to room.** Stop the follow camera from showing
   outside the room bounds. (N, 1h)

### Phase 2 — Combat
7. **Entity health + team fields.** Add `hp`, `max_hp`, `team`
   (`.player`/`.hostile`) to the `Entity` struct. Death = destroy
   entity when `hp <= 0`. (N, 1h)
8. **Attack input + swing hitbox entity.** On left-click, spawn a
   short-lived `attack_hitbox` entity in front of the player (using
   `last_known_x_dir`). Lives ~6 frames, then self-destroys. (N, 2h)
9. **Hitbox → damage resolution.** Each frame, test live hitboxes
   against hostile entities; apply damage, trigger `hit_flash`
   (already supported in `Entity.hit_flash`), consume the hitbox. (N, 3h)
10. **Enemy entity + chase AI.** New kind `.grunt`. `update_proc`
    moves toward the player at 60 u/s, with the same wall collision.
    Draws with existing shadow helper. Placeholder sprite recolour
    of `player_idle` is fine for now. (N, 3h)

### Phase 3 — Loot
11. **Item entity kind.** New kind `.loot_gold`. Spawns at the dead
    grunt's position with a tiny pop animation. (N, 2h)
12. **Pickup logic.** Player overlaps loot → destroy loot, increment
    `ctx.gs.gold` (new field). (N, 1h)
13. **Gold HUD string.** Draw "GOLD: N" top-right in screen space.
    Use existing `draw_text`. (B, 1h)

### Phase 4 — Feel
14. **Sound hookup.** Play `event:/schloop` (already in the bank) on
    attack. Continuous ambience via `sound_play_continuously` already
    wired — keep or mute. (B, 1h)
15. **Camera shake on hit.** 2-frame random offset added to
    `cam_pos`. (N, 1h)
16. **Damage numbers.** Floating-up text over hit target using a short
    timer + `draw_text` in world space. (N, 2h)

### Phase 5 — Playtest + cut
17. **Playtest pass.** Record a 30 s video. Note worst 3 feel issues.
    Fix whichever of the three fit in 2h. (0–2h, triage)
18. **Kill-switch.** If the slice feels bad, stop and re-scope before
    adding anything. Slice is a checkpoint, not a commitment.

**Rough total: 24–30 hours of focused work.** Spread over ~2 weeks at a
relaxed pace, or 3–4 days heads-down.

## Post-slice (not for this milestone, but useful to keep in mind)

- Replace the hardcoded room with a tile-grid + a tiny level format.
  Sets up procedural generation later.
- Data-driven item/enemy/skill tables. Move `Entity_Kind` behaviour
  out of `setup_*` procs into a data registry when we have >5 kinds.
- Save format — decide early so we don't paint into a corner. Notes
  below under open questions.
- Controller support (co-op question).
- Seasonal content architecture — defer until after the first real
  playable build; the brief is explicit about not building it yet.

## Open questions (need your call before deep work)

1. **Perspective.** Top-down or isometric? Blueprint is set up for
   top-down (shadow blob, `y` is world depth). Iso is doable but
   costs us art budget and rotation logic. Strong default: **top-down
   2D pixel art**, à la Brotato / early Nuclear Throne.

2. **Art direction.** Pixel art (matches blueprint), hand-painted 2D
   (fight the blueprint), or 2.5D 3D-in-2D-projection? Art budget is
   the single biggest long-term cost — we should commit before we
   scale up content. Default: **pixel art at `GAME_RES_480x270`**
   (blueprint's current setting), colour-palette driven.

3. **Combat feel target.** Which reference? Diablo 2 point-and-click,
   Hades twin-stick, Path of Exile hybrid, Zelda-like direct swing?
   This drives input, attack design, and early animation scope.

4. **Co-op scope.** Planned for day-one or post-v1? If day-one we need
   local split-screen or online from the start, which shapes input
   handling, entity ownership, and save files. Strong default for
   v0.1: **single-player only**, design with co-op-friendly patterns
   (no global singletons beyond `ctx.gs`, entity ownership via
   handles) but don't build it yet.

5. **Save format.** Options:
   - **Raw struct snapshot** of `Game_State` — fastest, but breaks on
     any layout change. Viable for pre-v1.
   - **Tagged / versioned binary** — slower to write, survives
     refactors.
   - **JSON/toml** — human-debuggable, slow for large worlds.
   Recommendation: raw snapshot + a `SAVE_VERSION` u32 header for
   pre-alpha, migrate to tagged binary before anyone cares about
   their save being stable.

6. **Always-online stance.** Offline + optional cloud sync? Co-op
   peer-to-peer vs. dedicated? Fully offline is the brief's "design
   around from day one" stance — confirm.

7. **Engine/runtime target platforms.** Windows first — agreed.
   Beyond that: Steam Deck (Proton) soon, native Linux later, Mac
   maybe, consoles never? Blueprint's Linux/Mac support is
   explicitly incomplete; need to know if we should invest now.

8. **Seasonal architecture decisions we should make cheap now.**
   Even though we won't build the season system, two choices
   front-load cheaply:
   - Should skills/items be hot-reloadable data files from v0.2?
   - Character stats as a schema-versioned struct from day one?

9. **Input binding exposure.** Is the `action_map` going to be
   user-remappable (needs settings file + UI) or locked? Decision
   affects whether we need a settings.json now or in six months.

10. **FMOD commitment.** The blueprint depends on FMOD, which means
    anyone who clones Hex needs a free FMOD account + SDK. That's
    friction for potential contributors. Stick with FMOD, or swap
    to `vendor:miniaudio` / similar before we add real audio?
    Recommendation: **stick for now**, revisit before first public
    contributor onboarding.

11. **Repo strategy for the vendored SDKs.** Right now `.gitignore`
    excludes FMOD SDK + sokol-shdc (per your "no binaries / no FMOD
    SDK" guardrail), and `docs/setup.md` documents the manual restore.
    If that friction proves painful, alternatives are: a bootstrap
    script (`scripts/setup.ps1`), Git LFS, or a private submodule.
    Flagging so we can decide before the next dev joins.

Ping me when you've got answers on 1–6; the rest can wait until we're
closer to needing them.
