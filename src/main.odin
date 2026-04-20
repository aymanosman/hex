package main

import rl "vendor:raylib"

WINDOW_W :: 960
WINDOW_H :: 540
PLAYER_SPEED :: 220.0

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(WINDOW_W, WINDOW_H, "Hex")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	player_pos := rl.Vector2{WINDOW_W / 2, WINDOW_H / 2}

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		dir: rl.Vector2
		if rl.IsKeyDown(.W) do dir.y -= 1
		if rl.IsKeyDown(.S) do dir.y += 1
		if rl.IsKeyDown(.A) do dir.x -= 1
		if rl.IsKeyDown(.D) do dir.x += 1
		if dir != {} {
			player_pos += rl.Vector2Normalize(dir) * PLAYER_SPEED * dt
		}

		rl.BeginDrawing()
		rl.ClearBackground({18, 20, 32, 255})
		rl.DrawRectangleV(player_pos - {16, 16}, {32, 32}, rl.RAYWHITE)
		rl.DrawText("hex — wasd to move", 12, 12, 20, rl.LIGHTGRAY)
		rl.DrawFPS(WINDOW_W - 100, 12)
		rl.EndDrawing()
	}
}
