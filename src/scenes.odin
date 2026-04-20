package main

import rl "vendor:raylib"

// Named setup procs for one-shot render mode (--scene=NAME).
// Each one builds game state from scratch — no time advance, so exact
// field values (hit_flash, knockback, popup age, ...) end up exactly
// as set here.

scene_setup :: proc(name: string) -> bool {
	switch name {
	case "default": scene_default()
	case "combat":  scene_combat()
	case "kill":    scene_kill()
	case "loot":    scene_loot()
	case:           return false
	}
	return true
}

// Same layout game_init produces. Baseline for comparison.
scene_default :: proc() {
	build_test_room()
	p := entity_create(.player)
	game.player = p.handle
	spawn_grunt({-200, -120})
	spawn_grunt({ 260, -150})
	spawn_grunt({ 180,  180})
	spawn_grunt({-180,  200})
	camera_center_on_player()
}

// Player mid-melee: grunt right next to player, hit_flash mid-fade,
// knockback still active, damage popup hovering above.
scene_combat :: proc() {
	build_test_room()

	p := entity_create(.player)
	game.player = p.handle

	// grunt 1: just got hit
	g1 := entity_create(.grunt)
	g1.pos = {34, -6}
	g1.hp = 1
	g1.hit_flash = 0.7
	g1.knockback = {220, -40}
	spawn_popup(g1.pos + {0, -4}, 2)
	game.popups[len(game.popups) - 1].t_remaining = 0.55 // slightly aged

	// a second grunt still approaching
	g2 := entity_create(.grunt)
	g2.pos = {-90, 60}

	game.shake_amount = 4
	camera_center_on_player()
}

// One-hit kill imminent — grunt on 1 hp with a hitbox live on top.
scene_kill :: proc() {
	build_test_room()
	p := entity_create(.player)
	game.player = p.handle

	g := entity_create(.grunt)
	g.pos = {30, 0}
	g.hp  = 1
	g.hit_flash = 0.4

	hb := entity_create(.hitbox)
	hb.pos = {30, 0}
	hb.team = .player
	hb.damage = PLAYER_ATTACK_DMG

	camera_center_on_player()
}

// Player sitting on a pile of loot with gold already banked.
scene_loot :: proc() {
	build_test_room()
	p := entity_create(.player)
	game.player = p.handle

	for i in 0 ..< 5 {
		loot := entity_create(.loot)
		loot.pos = {f32(i) * 12 - 24, 10}
	}
	game.gold = 3

	camera_center_on_player()
}

camera_center_on_player :: proc() {
	p := get_player()
	game.camera = {
		target   = p.pos,
		offset   = {WINDOW_W * 0.5, WINDOW_H * 0.5},
		rotation = 0,
		zoom     = CAMERA_ZOOM,
	}
}

// Renders one frame of the named scene to `out_path` and returns true
// on success. Does NOT run game_update, so time never advances.
render_scene :: proc(name: string, out_path: string) -> bool {
	rl.SetConfigFlags({.WINDOW_HIDDEN})
	rl.InitWindow(WINDOW_W, WINDOW_H, "Hex (scene render)")
	defer rl.CloseWindow()

	if !scene_setup(name) do return false

	entities_rebuild_scratch()

	rl.BeginDrawing()
	rl.ClearBackground({18, 20, 32, 255})
	rl.BeginMode2D(game.camera)
	game_draw()
	rl.EndMode2D()
	draw_hud()
	rl.EndDrawing()

	img := rl.LoadImageFromScreen()
	defer rl.UnloadImage(img)

	out_c := cstring_from_string(out_path)
	defer delete(out_c)
	return rl.ExportImage(img, out_c)
}

cstring_from_string :: proc(s: string) -> cstring {
	// rl.ExportImage takes a null-terminated C string; make a cloned,
	// owned copy so the caller doesn't have to care.
	buf := make([]u8, len(s) + 1)
	copy(buf, transmute([]u8)s)
	buf[len(s)] = 0
	return cstring(raw_data(buf))
}
