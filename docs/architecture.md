# Hex — Architecture (template walkthrough)

A map of the blueprint we're building on. Read this once; you shouldn't
need to re-read every `core_*` file afterwards. Scope: the pieces we'll
touch in the first few months.

All `.odin` files live under `sauce/` and share `package main`. There's
no module boundary between core and game — the author intentionally
dropped it, and any file can reach into any other.

## The frame

`core_main.odin` owns the entry point and the per-frame loop.

```
main()                              core_main.odin
  └─ sapp.run({                     Sokol app bootstrap
       init_cb   = core_app_init,     one-time setup
       frame_cb  = core_app_frame,    called every frame
       cleanup_cb= core_app_shutdown,
       event_cb  = event_callback,   all keyboard/mouse/resize events
     })

core_app_init()
  ├─ sound_init()                   boot FMOD (core_sound.odin)
  ├─ entity_init_core()             seed the zero-entity defaults
  ├─ new(Game_State)                one big megastruct
  ├─ render_init()                  Sokol pipeline, atlas pack, font bake
  └─ app_init()                     game-defined hook (game.odin)

core_app_frame()                    variable timestep
  ├─ compute frame_time (clamped to >= 1/20s)
  ├─ ctx.delta_t / ctx.gs wired up
  ├─ Alt+Enter → fullscreen
  ├─ core_render_frame_start()      reset per-frame draw buffers
  ├─ app_frame()                    ← game lives here
  ├─ core_render_frame_end()        flush quads → GPU, commit
  ├─ reset_input_state()            clear .pressed/.released bits
  └─ free_all(temp_allocator)
```

**Timestep.** Variable delta clamped to 1/20s. The author explicitly
defers fixed-timestep work until it's needed. `ctx.delta_t` is the only
thing gameplay code reads.

**Context.** A global `ctx: Core_Context` carries `{gs, delta_t}`. Every
gameplay function implicitly reaches through `ctx.gs` — this is by
design, not a mistake. The `push_ctx`/`set_ctx` pair exists for future
fixed-timestep sub-frames.

## Game state

`game.odin` defines `Game_State` — a big struct holding:
- `ticks`, `game_time_elapsed`, `cam_pos`
- The entity pool: `entities[MAX_ENTITIES]`, `entity_top_count`,
  `latest_entity_id`, `entity_free_list`
- Game-specific slots like `player_handle`
- A `scratch` sub-struct zeroed every `game_update()` for per-frame
  helpers (e.g. `all_entities` list built on the temp allocator)

One `Game_State` instance lives behind `_actual_game_state` and is
pointed at by `ctx.gs`. A future save/load system will serialise this
struct (minus the scratch block).

## Entities — the "megastruct ECS"

`entity.odin` is tiny (~90 lines). It defines `Entity_Handle{index, id}`
and four operations: `entity_create(kind)`, `entity_destroy(e)`,
`entity_from_handle(h)`, `is_valid(e)`. Plus a "zero entity" that's
returned when a handle doesn't resolve, so callers can chain without
nil-checks.

The interesting part lives in `game.odin`:

```odin
Entity :: struct {
    handle: Entity_Handle
    kind:   Entity_Kind     // .nil | .player | .thing1 | ...
    update_proc: proc(^Entity)
    draw_proc:   proc(Entity)
    pos, draw_offset: Vec2
    sprite: Sprite_Name
    anim_index, frame_duration, loop, next_frame_end_time, ...
    hit_flash, flip_x, last_known_x_dir, rotation, ...
    scratch: struct { col_override: Vec4 }   // zeroed each frame
}
```

It's one flat struct — no component composition. Every entity carries
every field. New "component" = add a field. Per-entity behaviour =
assign `update_proc` / `draw_proc` inside `entity_setup(e, kind)`.
`setup_player` in `game.odin:398` is the canonical example of the
pattern.

The update loop:
```
game_update():
    zero ctx.gs.scratch
    if ticks == 0: create player
    rebuild_scratch_helpers()           build the scratch.all_entities slice
    for handle in get_all_ents():
        e := entity_from_handle(handle)
        update_entity_animation(e)
        e.update_proc(e)
```

Iteration is index-ordered over a dense pool with a free-list for reuse.
2048-entity ceiling (`MAX_ENTITIES`).

## Rendering

Three files: `core_render.odin` (Sokol plumbing + atlas pack + font bake),
`core_draw.odin` (high-level drawing API), `core_draw_text.odin` (text).

**Atlas pipeline.** At init, `load_sprites_into_atlas()` reads every PNG
under `res/images/` matching a `Sprite_Name` enum entry, then packs them
into a single 1024×1024 atlas using `vendor:stb/rect_pack`. Atlas UVs
are cached per sprite. Adding art = drop the PNG in `res/images/` and
add the corresponding enum entry in `Sprite_Name` (`game.odin:158`).
Animations are single-row sprite strips; `sprite_data[.name].frame_count`
controls frame splitting.

**Draw API.** Gameplay code calls `draw_sprite(pos, .player_idle, ...)`,
`draw_rect(rect, ...)`, `draw_text(pos, "...")`. Each call pushes a
`Quad` (4 verts) into one of a handful of `ZLayer` buckets
(`draw_frame.quads[.playspace]`, etc). At `core_render_frame_end()` the
buckets are concatenated in enum order (`.background` → `.top`) into one
vertex buffer and submitted as a single `sg.draw` call.

**Coordinate spaces.** `push_coord_space(get_world_space())` vs
`push_coord_space(get_screen_space())`. World space is an ortho projection
scaled so `GAME_RES_HEIGHT` pixels map to `window_h` pixels — the camera
is `ctx.gs.cam_pos`. Screen space is pixel-accurate UI space. There's a
clip-space mode used for the shader-driven background.

**Shader.** Single quad shader at `sauce/shader.glsl` compiled via
`sokol-shdc` at build time to `sauce/generated_shader.odin`. `Quad_Flags`
is a shared bit-set between game code and shader for per-quad effects
(e.g. the scrolling background uses `.background_pixels`).

## Input

`core_input.odin` wraps Sokol's event callback into a snapshot-style
state. On each frame the game reads `key_pressed/down/released` and then
`reset_input_state()` clears the edge flags at the end of the frame.

Notable: mouse buttons are merged into the same `Key_Code` enum as
keyboard keys (`LEFT_MOUSE = 400` etc), so the `action_map` in
`game.odin` can be a single `Input_Action → Key_Code` map.

The game-layer helpers live in `game_utils.odin`:
`is_action_down(.left)`, `get_input_vector()`,
`mouse_pos_in_current_space()`, `consume_key_pressed`.

Consuming keys is a deliberate pattern: if a UI layer handles a click,
it calls `consume_key_pressed(.LEFT_MOUSE)` so later systems don't
double-handle it.

## Sound

`core_sound.odin` wraps FMOD Studio. `sound_init()` loads
`res/fmod/Master.bank` + strings bank. `sound_play("event:/schloop")`
fires a one-shot with cooldown. `sound_play_continuously(name, id, pos)`
reference-counts an emitter by `id` — as long as you call it each frame
it keeps playing; stop calling and it auto-stops.

Position-based sounds use FMOD's 3D attributes with `y=0`, treating the
game as top-down audio: `{pos.x, 0, pos.y}`.

## Build pipeline

`build.bat` → `odin run sauce/build -debug -- …` → `sauce/build/build.odin`.
The build script:
1. Emits `sauce/generated.odin` holding `PLATFORM`/`GAME_KIND` constants.
2. Runs `sokol-shdc` to translate `sauce/shader.glsl` per-backend
   (HLSL5 on Windows, GLSL430 on Linux, Metal on Mac) and writes
   `sauce/generated_shader.odin`.
3. `odin build sauce -out:build/<platform>_<config>/game.exe [-debug]`.
4. Copies FMOD runtime DLLs next to the exe.
5. On release, copies `res/` into the output dir.

## File map cheat sheet

| File | What's in it |
|---|---|
| `sauce/core_main.odin` | Entry point, `main()`, per-frame loop, `ctx` |
| `sauce/core_render.odin` | Sokol pipeline, atlas pack, font bake, draw_frame |
| `sauce/core_draw.odin` | `draw_sprite`, `draw_rect`, `draw_rect_xform` |
| `sauce/core_draw_text.odin` | `draw_text` with drop shadow |
| `sauce/core_input.odin` | `Input` state, event callback, `Key_Code` enum |
| `sauce/core_sound.odin` | FMOD init + helpers (`sound_play`, emitters) |
| `sauce/entity.odin` | Pool, handle, create/destroy, valid-check |
| `sauce/game.odin` | `Game_State`, `Entity` fields, `Entity_Kind`, `Sprite_Name`, `ZLayer`, `app_frame`, `game_update`, `game_draw`, `setup_player` |
| `sauce/game_utils.odin` | `Vec2/3/4`, coord-space helpers, action input, `now()`, `time_since`, screen pivots, `mouse_pos_in_current_space` |
| `sauce/build/build.odin` | Build driver (shader gen + odin build) |
| `sauce/utils/` | Math/color/shape helpers shared across `core_` |
| `sauce/shader.glsl` | The quad shader — one draw call does everything |
| `sauce/fmod/`, `sauce/sokol/`, `sauce/steamworks/` | Vendored third-party |

## Where we'll live

For the vertical slice, 90% of changes will land in `game.odin`. We'll
touch `core_render.odin` only to add ZLayers, `entity.odin` only if we
need handle semantics beyond what's there, and `core_sound.odin` only
when we wire real audio. Everything else — weapons, loot, enemies,
rooms, damage numbers — goes in `game.odin` or new `game_*.odin` files.
