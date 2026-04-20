package main

import rl "vendor:raylib"

MAX_ENTITIES :: 1024

Entity_Kind :: enum u8 {
	nil,
	player,
	grunt,
	hitbox,
	loot,
	wall,
}

Team :: enum u8 {
	neutral,
	player,
	hostile,
}

Entity_Handle :: struct {
	index: int,
	gen:   int,
}

Entity :: struct {
	handle: Entity_Handle,
	kind:   Entity_Kind,

	pos:  rl.Vector2,
	vel:  rl.Vector2,
	size: rl.Vector2, // full AABB size; pos is the center

	color: rl.Color,
	team:  Team,
	hp, max_hp: int,
	damage: int, // applied by hitboxes on overlap

	// lifetime > 0 counts down; entity destroyed when it hits zero.
	lifetime: f32,

	// visual 0..1, decays over time
	hit_flash: f32,

	// hitbox already applied damage this frame
	did_damage: bool,

	attack_cd: f32,

	update_proc: proc(^Entity),
	draw_proc:   proc(^Entity),
}

// sentinel returned on invalid-handle lookups so callers can chain safely
zero_entity: Entity

entity_get :: proc(h: Entity_Handle) -> (^Entity, bool) #optional_ok {
	if h.index <= 0 || h.index > game.entity_top {
		return &zero_entity, false
	}
	e := &game.entities[h.index]
	if e.handle.gen != h.gen || e.kind == .nil {
		return &zero_entity, false
	}
	return e, true
}

entity_create :: proc(kind: Entity_Kind) -> ^Entity {
	idx: int
	if len(game.free_list) > 0 {
		idx = pop(&game.free_list)
	} else {
		game.entity_top += 1
		assert(game.entity_top < MAX_ENTITIES, "ran out of entity slots")
		idx = game.entity_top
	}

	e := &game.entities[idx]
	gen := e.handle.gen + 1 // preserve + bump across reuse
	e^ = {}
	e.handle = {index = idx, gen = gen}
	e.kind = kind
	entity_setup(e, kind)
	return e
}

entity_destroy :: proc(e: ^Entity) {
	idx := e.handle.index
	gen := e.handle.gen
	e^ = {}
	e.handle.gen = gen + 1
	append(&game.free_list, idx)
}

entity_aabb :: proc(e: ^Entity) -> rl.Rectangle {
	return {e.pos.x - e.size.x * 0.5, e.pos.y - e.size.y * 0.5, e.size.x, e.size.y}
}

entities_rebuild_scratch :: proc() {
	game.scratch.entities = make([dynamic]Entity_Handle, 0, MAX_ENTITIES, allocator = context.temp_allocator)
	for i in 1 ..= game.entity_top {
		e := &game.entities[i]
		if e.kind == .nil do continue
		append(&game.scratch.entities, e.handle)
	}
}
