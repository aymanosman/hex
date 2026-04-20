package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

Damage_Popup :: struct {
	pos:         rl.Vector2,
	value:       int,
	t_remaining: f32,
}

POPUP_LIFETIME :: 0.7
POPUP_RISE     :: 24.0 // world units per second

Game :: struct {
	entities:  [MAX_ENTITIES]Entity,
	entity_top: int,
	free_list:  [dynamic]int,

	player: Entity_Handle,

	camera:       rl.Camera2D,
	shake_amount: f32,

	popups: [dynamic]Damage_Popup,

	gold:  int,
	time:  f64,
	ticks: u64,

	scratch: struct {
		entities: [dynamic]Entity_Handle,
	},
}

game: Game

PLAYER_SPEED :: 220.0

CAMERA_FOLLOW_RATE :: 6.0 // exp-decay follow; larger = snappier
CAMERA_ZOOM        :: 1.5

game_init :: proc() {
	build_test_room()

	p := entity_create(.player)
	game.player = p.handle

	spawn_grunt({-200, -120})
	spawn_grunt({ 260, -150})
	spawn_grunt({ 180,  180})
	spawn_grunt({-180,  200})

	game.camera = {
		target   = p.pos,
		offset   = {WINDOW_W * 0.5, WINDOW_H * 0.5},
		rotation = 0,
		zoom     = CAMERA_ZOOM,
	}
}

spawn_grunt :: proc(pos: rl.Vector2) {
	g := entity_create(.grunt)
	g.pos = pos
}

camera_update :: proc(dt: f32) {
	// exp-decay lerp toward player
	target := get_player().pos
	t := 1 - math.pow(f32(2), f32(-CAMERA_FOLLOW_RATE) * dt)
	game.camera.target = linalg.lerp(game.camera.target, target, t)

	if game.shake_amount > 0 {
		jx := (rand_f32() * 2 - 1) * game.shake_amount
		jy := (rand_f32() * 2 - 1) * game.shake_amount
		game.camera.target += {jx, jy}
		game.shake_amount = max(0, game.shake_amount - dt * 30)
	}

	// keep offset centered even when the window resizes
	game.camera.offset = {f32(rl.GetScreenWidth()) * 0.5, f32(rl.GetScreenHeight()) * 0.5}
}

rand_f32 :: proc() -> f32 {
	return f32(rl.GetRandomValue(0, 10_000)) / 10_000.0
}

game_update :: proc(dt: f32) {
	game.scratch = {}
	defer {
		game.time += f64(dt)
		game.ticks += 1
	}

	entities_rebuild_scratch()

	for h in game.scratch.entities {
		e := entity_get(h) or_continue
		if e.update_proc != nil {
			e.update_proc(e)
		}

		if e.knockback != {} {
			e.pos += e.knockback * dt
			e.knockback = linalg.lerp(e.knockback, rl.Vector2{}, min(1, dt * 12))
			if linalg.length(e.knockback) < 1 do e.knockback = {}
			if e.kind != .hitbox && e.kind != .loot {
				resolve_wall_collisions(e)
			}
		}

		if e.attack_cd > 0 do e.attack_cd = max(0, e.attack_cd - dt)
		if e.hit_flash > 0 do e.hit_flash = max(0, e.hit_flash - dt * 4)

		if e.lifetime > 0 {
			e.lifetime -= dt
			if e.lifetime <= 0 {
				entity_destroy(e)
				continue
			}
		}
	}

	resolve_combat()
	resolve_pickups()
	update_popups(dt)

	camera_update(dt)
}

// Damage pass: every active hitbox damages each overlapping entity on the
// opposite team once.
resolve_combat :: proc() {
	for h in game.scratch.entities {
		hb := entity_get(h) or_continue
		if hb.kind != .hitbox || hb.did_damage do continue
		hb.did_damage = true

		ra := entity_aabb(hb)
		for h2 in game.scratch.entities {
			target := entity_get(h2) or_continue
			if target.team == hb.team || target.team == .neutral do continue
			if !rl.CheckCollisionRecs(ra, entity_aabb(target)) do continue

			target.hp -= hb.damage
			target.hit_flash = 1

			dir := target.pos - hb.pos
			if linalg.length(dir) > 0.1 {
				target.knockback += linalg.normalize(dir) * 320
			}

			game.shake_amount = max(game.shake_amount, 5)
			spawn_popup(target.pos, hb.damage)
			play(sfx.hit)

			if target.hp <= 0 {
				on_entity_killed(target)
				entity_destroy(target)
			}
		}
	}
}

on_entity_killed :: proc(e: ^Entity) {
	if e.kind == .grunt {
		loot := entity_create(.loot)
		loot.pos = e.pos
	}
}

spawn_popup :: proc(pos: rl.Vector2, value: int) {
	// nudge the x a little so stacked hits don't overlap exactly
	jitter_x := (rand_f32() * 2 - 1) * 8
	append(&game.popups, Damage_Popup{
		pos         = pos + {jitter_x, -12},
		value       = value,
		t_remaining = POPUP_LIFETIME,
	})
}

update_popups :: proc(dt: f32) {
	#reverse for &p, i in game.popups {
		p.t_remaining -= dt
		p.pos.y -= POPUP_RISE * dt
		if p.t_remaining <= 0 {
			unordered_remove(&game.popups, i)
		}
	}
}

draw_popups :: proc() {
	for p in game.popups {
		alpha := u8(rl.Clamp(p.t_remaining / POPUP_LIFETIME, 0, 1) * 255)
		col := rl.Color{255, 230, 120, alpha}
		txt := fmt.ctprintf("%d", p.value)
		// DrawText takes i32 screen coords but BeginMode2D applies the
		// camera transform first, so these "screen" coords are world
		// units while inside the Begin/End block.
		rl.DrawText(txt, i32(p.pos.x), i32(p.pos.y), 12, col)
	}
}

// Pickup pass: player overlaps loot → grant gold, destroy loot.
resolve_pickups :: proc() {
	p := get_player()
	if p.kind == .nil do return
	pr := entity_aabb(p)
	for h in game.scratch.entities {
		item := entity_get(h) or_continue
		if item.kind != .loot do continue
		if rl.CheckCollisionRecs(pr, entity_aabb(item)) {
			game.gold += 1
			entity_destroy(item)
			play(sfx.pickup)
		}
	}
}

game_draw :: proc() {
	for h in game.scratch.entities {
		e := entity_get(h) or_continue
		if e.draw_proc != nil {
			e.draw_proc(e)
		} else {
			draw_entity_default(e)
		}
	}
	draw_popups()
}

draw_entity_default :: proc(e: ^Entity) {
	col := e.color
	if e.hit_flash > 0 {
		col = rl.ColorLerp(col, rl.WHITE, e.hit_flash)
	}
	rl.DrawRectangleRec(entity_aabb(e), col)
}

get_player :: proc() -> ^Entity {
	p, _ := entity_get(game.player)
	return p
}

// ---------- entity setup dispatch ----------

entity_setup :: proc(e: ^Entity, kind: Entity_Kind) {
	switch kind {
	case .nil:
	case .player: setup_player(e)
	case .grunt:  setup_grunt(e)
	case .hitbox: setup_hitbox(e)
	case .loot:   setup_loot(e)
	case .wall:   setup_wall(e)
	}
}

// ---------- player ----------

PLAYER_ATTACK_CD    :: 0.25
PLAYER_ATTACK_RANGE :: 44
PLAYER_ATTACK_DMG   :: 2

setup_player :: proc(e: ^Entity) {
	e.size = {28, 28}
	e.color = rl.RAYWHITE
	e.team = .player
	e.hp, e.max_hp = 10, 10

	e.update_proc = proc(e: ^Entity) {
		dt := rl.GetFrameTime()

		dir: rl.Vector2
		if rl.IsKeyDown(.W) do dir.y -= 1
		if rl.IsKeyDown(.S) do dir.y += 1
		if rl.IsKeyDown(.A) do dir.x -= 1
		if rl.IsKeyDown(.D) do dir.x += 1
		if dir != {} {
			dir = linalg.normalize(dir)
			e.pos += dir * PLAYER_SPEED * dt
		}
		resolve_wall_collisions(e)

		if rl.IsMouseButtonPressed(.LEFT) && e.attack_cd <= 0 {
			mouse := rl.GetScreenToWorld2D(rl.GetMousePosition(), game.camera)
			to_mouse := mouse - e.pos
			if linalg.length(to_mouse) > 1 {
				aim := linalg.normalize(to_mouse)
				spawn_player_hitbox(e.pos + aim * PLAYER_ATTACK_RANGE * 0.6)
				e.attack_cd = PLAYER_ATTACK_CD
				play(sfx.swing)
			}
		}
	}
}

spawn_player_hitbox :: proc(pos: rl.Vector2) {
	hb := entity_create(.hitbox)
	hb.pos = pos
	hb.team = .player
	hb.damage = PLAYER_ATTACK_DMG
}

// ---------- stubs filled in later phases ----------

GRUNT_SPEED :: 90.0

setup_grunt :: proc(e: ^Entity) {
	e.size = {24, 24}
	e.color = rl.MAROON
	e.team = .hostile
	e.hp, e.max_hp = 3, 3

	e.update_proc = proc(e: ^Entity) {
		p := get_player()
		if p.kind == .nil do return
		to := p.pos - e.pos
		d := linalg.length(to)
		if d > 1 {
			e.pos += (to / d) * GRUNT_SPEED * rl.GetFrameTime()
		}
		resolve_wall_collisions(e)
	}
}

setup_hitbox :: proc(e: ^Entity) {
	e.size = {40, 40}
	e.color = {255, 255, 255, 90}
	e.lifetime = 0.1
}

setup_loot :: proc(e: ^Entity) {
	e.size = {10, 10}
	e.color = rl.GOLD
	e.team = .neutral
}

setup_wall :: proc(e: ^Entity) {
	e.color = {60, 62, 80, 255}
	e.team = .neutral
}
