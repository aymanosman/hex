# Hex — Roadmap

## Status

**v0.1 slice is playable.** Running the binary gives you: WASD
movement with wall collision, mouse-aimed melee with a 0.25 s
cooldown, four chase-AI grunts, hit-flash + knockdown-and-destroy on
death, gold drops, pickup, HUD (HP / gold / FPS).

Stack: Odin + raylib (dropped the Sokol+FMOD blueprint — see
[`docs/setup.md`](./setup.md#history)). 476 LoC across four files in
`src/`, no SDKs, no build-time codegen, cross-platform via raylib's
bundled libs.

## Next milestones (unordered, pick based on what hurts most)

### v0.2 — Feel
The slice is correct but wooden. Tune until combat reads well before
adding more content.

- Knockback on hit (push target along hit-direction).
- Camera shake on attack connect (decay over ~0.15 s).
- Damage numbers (floating text, short lifetime, rise + fade).
- Attack windup / recovery (even 80 ms of anticipation transforms feel).
- Audio — `vendor:miniaudio` or raylib's `raudio`. Whoosh on swing,
  thud on connect, coin-pickup jingle. 2-3 free sounds from
  freesound.org will do.

### v0.3 — Sprites
Replace all the coloured rectangles with real art. Decision gate
before starting: pick perspective (top-down vs iso) and art style —
see open questions.

- `Sprite_Name` enum + `[Sprite_Name]rl.Texture2D` table, loaded from
  `res/sprites/<name>.png` at init.
- `draw_entity_default` renders the texture with hit-flash tint
  (raylib supports this via `DrawTextureV` + a colour modulation).
- Animation strips — frame_count, frame_duration, anim_index. Cribbed
  from blueprint's `update_entity_animation`.
- Z-order — draw sorted by y-position (classic top-down ordering).

### v0.4 — Content
With feel + art baseline, scale out:

- Two more enemy kinds (ranged + tanky).
- A second room with a door/transition.
- A basic drop table (small/medium/large loot).
- A health potion item.

### v0.5 — Systems
Back-end work that pays off across all future content:

- Save/load. Raw snapshot of `Game` with a `SAVE_VERSION` header;
  migrate to versioned tagged binary before external testers.
- Controller support via raylib's gamepad API.
- Settings file (JSON or toml) for keybinds, volumes, resolution.

## Open questions (blocking v0.3+)

1. **Perspective.** Top-down flat vs iso 2D vs Zelda-like 3/4? Default
   recommendation: top-down.
2. **Art direction.** Pixel art (blueprint era default), hand-painted,
   or a style we haven't considered? Biggest long-term cost driver.
3. **Combat feel target.** Diablo 2 click, Hades twin-stick, PoE
   hybrid, Zelda direct swing? Shapes input, attack design, early
   animation scope.
4. **Co-op scope.** Single-player v1 with co-op patterns baked in, or
   co-op day-one? Affects input handling, entity ownership, saves.
5. **Always-online.** Brief said "design around offline/co-op from day
   one". Confirming as hard constraint.
6. **Save format commitment.** See v0.5.
7. **Platform targets beyond Windows/Mac.** Steam Deck (Proton) soon?
   Native Linux later? Consoles never?

Answer 1-3 before v0.3 starts; 4-7 can wait.

## Post-v0.5 wishlist

- Seasonal content architecture (hot-reloadable data files).
- Procgen levels.
- Skill tree / passive tree.
- Itemisation with affixes.
- Boss encounters.
