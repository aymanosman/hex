# Hex — Architecture

Four-file Odin program. Everything is `package main`. Read each file
top-to-bottom for the full picture; this doc is just the map.

## Files

| File | What's in it |
|---|---|
| `src/main.odin` | Entry point: window setup, per-frame loop, HUD drawing |
| `src/entity.odin` | Entity megastruct, pool + handle, create/destroy/lookup, scratch rebuild |
| `src/game.odin` | `Game` state, camera follow, per-kind setup + update/draw procs, combat and pickup resolution |
| `src/room.odin` | Hardcoded test room + wall AABB collision resolver |

## Frame loop

```
main()                                  main.odin
  InitWindow / SetTargetFPS(60)
  game_init()                           spawn room walls, player, grunts
  loop until WindowShouldClose:
    dt := GetFrameTime()
    game_update(dt)                     game.odin
      zero scratch
      entities_rebuild_scratch()        entity.odin — build this-frame handle list
      for h in scratch.entities:        calls update_proc, decays timers, destroys expired
      resolve_combat()                  hitbox AABB vs hostile team, apply damage + flash
      resolve_pickups()                 player AABB vs loot
      camera_update(dt)                 exp-decay lerp toward player
    BeginDrawing / ClearBackground
    BeginMode2D(camera)
      game_draw()                       each entity's draw_proc (or default AABB)
    EndMode2D
    draw_hud()                          screen-space text (HP, gold, hint, FPS)
    EndDrawing
    free_all(temp_allocator)
```

Variable timestep, clamped by `SetTargetFPS(60)`. No fixed-step yet;
add it if/when it starts to matter.

## Entity pool

`MAX_ENTITIES = 1024`. Dense array indexed from 1 (slot 0 is reserved
as the "zero entity" sentinel returned on invalid handle lookups, so
callers can chain without nil-checks). `entity_top` tracks the
high-water mark; `free_list` is a stack of reusable slots from
destroyed entities.

`Entity_Handle = {index, gen}`. On destroy, the entity's slot is
zeroed *but* the gen counter is preserved-and-incremented so an old
handle won't resolve to the reused slot. Lookup:

```odin
entity_get(h) -> (^Entity, bool) #optional_ok
```

Using `or_continue` in the per-entity loops is the idiomatic dead-handle skip.

The `Entity` struct is a flat megastruct: pos, size, color, team, hp,
damage, lifetime, hit_flash, attack_cd, plus two function pointers
(`update_proc`, `draw_proc`). Adding a "component" = adding a field.
Per-kind behaviour = assigning the two procs inside
`setup_<kind>(e)`.

## Rendering

raylib's immediate-mode API, no custom renderer. World space runs
inside `BeginMode2D(game.camera)`; screen space (HUD) outside it.
Camera zoom is 1.5, so the window shows a 640×360 world viewport at
the default 960×540 window.

No atlas yet — entities draw solid rectangles via `DrawRectangleRec`.
When we introduce sprites: `rl.LoadTexture` at init, keep a
`[Sprite_Name]rl.Texture2D` table in `Game`, swap `draw_entity_default`
to render sprite + hit-flash tint.

## Input

Direct raylib polling (`IsKeyDown`, `IsMouseButtonPressed`,
`GetMousePosition`). `GetScreenToWorld2D(mouse_pos, camera)` converts
cursor pixels to world coordinates for aimed attacks.

No action-map indirection yet. Add one when we want remappable
bindings or controller support.

## Collision

Two resolvers, both AABB:

- `resolve_wall_collisions(e)` — push `e` out of any `.wall` entity
  along the smaller-penetration axis. Called from player and grunt
  update procs.
- `resolve_combat()` — for each un-applied `.hitbox` entity, damage
  every overlapping entity on the opposite team. One-shot per hitbox
  (`did_damage` flag).
- `resolve_pickups()` — player AABB vs `.loot` entities.

Good enough at the current top speed (~220 u/s player, 90 u/s grunts).
If tunnelling shows up at higher speeds, swap the wall resolver for
swept AABB.

## What's explicitly out of the code today

- Sprites / textures / atlas
- Audio
- Menus / save system / settings
- Tiles / a real level format
- Stats, skills, inventory, levelling
- Seasons, always-online, co-op

All documented in `docs/roadmap.md`.
