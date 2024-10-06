const std = @import("std");
const rl = @cImport({
	@cInclude("raylib.h");
	@cInclude("rlgl.h");
	@cInclude("raymath.h");
});

// settings
const tile_side = 80; // side length of a tile / square
const player_side = 40; // side length of a player sized square
const speed = 0.05;
const screen_width = 1920;
const screen_height = 1080;

pub fn main() void {

	rl.InitWindow(screen_width, screen_height, "skrr");
	defer rl.CloseWindow();

	// Main player
	var player: rl.Rectangle = rl.Rectangle{
		.x = 0 - player_side / 2,
		.y = 0 - player_side / 2,
		.width = player_side,
		.height = player_side,
	};

	// level
	const level: [2]rl.Rectangle = [_]rl.Rectangle{
		rl.Rectangle{.x = 0 + tile_side, .y = 0, .width = tile_side, .height = tile_side},
		rl.Rectangle{.x = 0 + 3 * tile_side, .y = 0, .width = tile_side, .height = tile_side},
	};

	// Camera
	var camera: rl.Camera2D = undefined;
	camera.offset = rl.Vector2{.x = screen_width / 2, .y = screen_height / 2};
	camera.rotation = 0;
	camera.zoom = 1.0;

	while (!rl.WindowShouldClose()) {
		// Rectangle for checking player collision
		var player_collision: rl.Rectangle = player;

		// input. Only 1 key a frame for now
		if (rl.IsKeyDown(rl.KEY_W))
			player_collision.y -= speed
		else if (rl.IsKeyDown(rl.KEY_S))
			player_collision.y += speed
		else if (rl.IsKeyDown(rl.KEY_A))
			player_collision.x -= speed
		else if (rl.IsKeyDown(rl.KEY_D))
			player_collision.x += speed;

		// only update player position of player_collision hasn't collided.
		if (
			for (level) |rect| {
				if (rl.CheckCollisionRecs(rect, player_collision))
					break false;
			}
			else true
		) player = player_collision;

		camera.target = rl.Vector2{.x = player.x, .y = player.y};

		// Draw
		rl.BeginDrawing();
		defer rl.EndDrawing();

		rl.ClearBackground(rl.BLACK);

		// Player camera
		rl.BeginMode2D(camera);
		defer rl.EndMode2D();
		// draw level
		for (level) |rect|
			rl.DrawRectangleRec(rect, rl.LIGHTGRAY);

		rl.DrawRectangleRec(player, rl.RED);
	}
}
