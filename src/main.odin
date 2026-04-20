package main

import "core:fmt"

import rl "vendor:raylib"

WINDOW_W :: 960
WINDOW_H :: 540

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(WINDOW_W, WINDOW_H, "Hex")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	game_init()

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		game_update(dt)

		rl.BeginDrawing()
		rl.ClearBackground({18, 20, 32, 255})

		rl.BeginMode2D(game.camera)
		game_draw()
		rl.EndMode2D()

		draw_hud()
		rl.EndDrawing()

		free_all(context.temp_allocator)
	}
}

draw_hud :: proc() {
	rl.DrawText("hex — wasd: move  |  left click: attack", 12, 12, 18, rl.LIGHTGRAY)

	p := get_player()
	if p.kind != .nil {
		hp := fmt.ctprintf("HP %d/%d", p.hp, p.max_hp)
		rl.DrawText(hp, 12, rl.GetScreenHeight() - 28, 20, rl.RAYWHITE)
	}

	gold := fmt.ctprintf("GOLD %d", game.gold)
	rl.DrawText(gold, rl.GetScreenWidth() - 140, rl.GetScreenHeight() - 28, 20, rl.GOLD)

	rl.DrawFPS(rl.GetScreenWidth() - 100, 12)
}
