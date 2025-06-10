const std = @import("std");

const rl = @cImport({
	@cInclude("raylib.h");
	@cInclude("raymath.h");
	@cInclude("rlgl.h");
});

const window_width = 1440;
const window_height = 900;

const TILE = 120;
const SPEED = 0.5;

// all coordinates are in world space
// center of the player rectangle
var player_pos: rl.Vector2 = rl.Vector2{.x = 0, .y = 0};
var player: rl.Rectangle = rl.Rectangle{
	.x = 0 - TILE / 2,
	.y = 0 - TILE / 2,
	.width = TILE,
	.height = TILE,
};

pub fn main() void {
	// This needs to be set for making the window tiling on sway
	rl.SetConfigFlags(rl.FLAG_WINDOW_RESIZABLE);

	rl.InitWindow(window_width, window_height, "skrr");
	defer rl.CloseWindow();

	var camera: rl.Camera2D = rl.Camera2D{
		.target = player_pos,
		.offset = rl.Vector2{.x = window_width/2, .y = window_height/2},
		.rotation = 0,
		.zoom = 1, // TODO: maybe change this for resolution resizing stuff ? 
	};

	while (!rl.WindowShouldClose()) {
		if (rl.IsKeyDown(rl.KEY_A))
			player_pos.x -= SPEED
		else if (rl.IsKeyDown(rl.KEY_D))
			player_pos.x += SPEED
		else if (rl.IsKeyDown(rl.KEY_W))
			player_pos.y -= SPEED
		else if (rl.IsKeyDown(rl.KEY_S))
			player_pos.y += SPEED;

		player.x = player_pos.x;
		player.y = player_pos.y;

		camera.target = player_pos;

		rl.BeginDrawing();
		defer rl.EndDrawing();

		rl.ClearBackground(rl.BLACK);

		rl.BeginMode2D(camera);
		defer rl.EndMode2D();

		rl.DrawRectangleRec(player, rl.RED);

		// Reference rectangle
		rl.DrawRectangle(TILE / 2, -TILE / 2, TILE, TILE, rl.RAYWHITE);
	}
}

test "hello world" {
	std.debug.print("Hello world\n", .{});
}
