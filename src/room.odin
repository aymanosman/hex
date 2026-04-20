package main

import rl "vendor:raylib"

TILE :: 32

// Hardcoded test room. Border walls + a couple of obstacles.
build_test_room :: proc() {
	// 40 x 25 tile room = 1280 x 800 world pixels, centered on origin.
	cols, rows :: 40, 25
	w, h := f32(cols * TILE), f32(rows * TILE)
	ox, oy := -w * 0.5, -h * 0.5

	wall :: proc(x, y, w, h: f32) {
		e := entity_create(.wall)
		e.pos = {x + w * 0.5, y + h * 0.5}
		e.size = {w, h}
	}

	// borders
	wall(ox, oy,                    w,           TILE)          // top
	wall(ox, oy + h - TILE,         w,           TILE)          // bottom
	wall(ox, oy + TILE,             TILE,        h - TILE * 2)  // left
	wall(ox + w - TILE, oy + TILE,  TILE,        h - TILE * 2)  // right

	// two internal obstacles
	wall(ox + 8 * TILE,  oy + 8 * TILE,  TILE * 4, TILE)
	wall(ox + 24 * TILE, oy + 14 * TILE, TILE,     TILE * 5)
}

// Pushes an AABB entity out of any wall AABB it overlaps.
// Resolves the smaller-penetration axis first, one wall at a time.
// Good enough at moderate speeds; swap for swept AABB if we see tunnelling.
resolve_wall_collisions :: proc(e: ^Entity) {
	for h in game.scratch.entities {
		w := entity_get(h) or_continue
		if w.kind != .wall do continue
		resolve_aabb_push_out(e, w)
	}
}

resolve_aabb_push_out :: proc(a, b: ^Entity) {
	ra, rb := entity_aabb(a), entity_aabb(b)
	if !rl.CheckCollisionRecs(ra, rb) do return

	// overlap on each axis
	ox := min(ra.x + ra.width, rb.x + rb.width) - max(ra.x, rb.x)
	oy := min(ra.y + ra.height, rb.y + rb.height) - max(ra.y, rb.y)

	if ox < oy {
		// push on X
		a.pos.x += (a.pos.x < b.pos.x) ? -ox : ox
	} else {
		a.pos.y += (a.pos.y < b.pos.y) ? -oy : oy
	}
}
