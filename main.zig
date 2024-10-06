const std = @import("std");
const rl = @cImport({
	@cInclude("raylib.h");
	@cInclude("rlgl.h");
	@cInclude("raymath.h");
});

// settings
const tile_side = 40; // side length of a tile / square
const speed = 0.1;
const screen_width = 1920;
const screen_height = 1080;

pub fn main() void {

	rl.InitWindow(screen_width, screen_height, "skrr");
	defer rl.CloseWindow();

	// Main player
	var player: rl.Rectangle = rl.Rectangle{
		.x = 0 - tile_side / 2,
		.y = 0 - tile_side / 2,
		.width = tile_side,
		.height = tile_side,
	};

	// Camera
	var camera: rl.Camera2D = undefined;
	camera.offset = rl.Vector2{.x = screen_width / 2, .y = screen_height / 2};
	camera.rotation = 0;
	camera.zoom = 1.0;

	while (!rl.WindowShouldClose()) {
		// input. Only 1 key a frame for now
		if (rl.IsKeyDown(rl.KEY_W))
			player.y -= speed
		else if (rl.IsKeyDown(rl.KEY_S))
			player.y += speed
		else if (rl.IsKeyDown(rl.KEY_A))
			player.x -= speed
		else if (rl.IsKeyDown(rl.KEY_D))
			player.x += speed;

		camera.target = rl.Vector2{.x = player.x, .y = player.y};

		// Draw
		rl.BeginDrawing();
		defer rl.EndDrawing();

		rl.ClearBackground(rl.BLACK);

		// Player camera
		rl.BeginMode2D(camera);
		defer rl.EndMode2D();
		// reference rectangles
		rl.DrawRectangle(0, 0, tile_side, tile_side, rl.LIGHTGRAY);
		rl.DrawRectangle(0 + 2 * tile_side, 0, tile_side, tile_side, rl.LIGHTGRAY);

		rl.DrawRectangleRec(player, rl.RED);
	}
}
