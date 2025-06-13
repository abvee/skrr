const std = @import("std");
const rl = @cImport({
	@cInclude("raylib.h");
	@cInclude("raymath.h");
	@cInclude("rlgl.h");
});
const level = @import("level.zig");

const window_width = 1440;
const window_height = 900;

const TILE = @import("constants.zig").TILE;
const SPEED = 0.1;

// all coordinates are in world space
// center of the player rectangle
var player_pos: rl.Vector2 = rl.Vector2{.x = 0, .y = 0};
var player: rl.Rectangle = rl.Rectangle{
	.x = 0 - TILE / 2,
	.y = 0 - TILE / 2,
	.width = TILE,
	.height = TILE,
};

pub fn main() !void {
	// General purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) std.testing.expect(false)
			catch @panic("TEST FAIL");
    }

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

	// TODO:
	// yes, level loading
	const lvl = try level.load(allocator, "levels/level1");
	defer allocator.free(lvl);

	while (!rl.WindowShouldClose()) {

		var collision_rect: rl.Rectangle = player;
		// movement
		if (rl.IsKeyDown(rl.KEY_A))
			collision_rect.x -= SPEED
		else if (rl.IsKeyDown(rl.KEY_D))
			collision_rect.x += SPEED
		else if (rl.IsKeyDown(rl.KEY_W))
			collision_rect.y -= SPEED
		else if (rl.IsKeyDown(rl.KEY_S))
			collision_rect.y += SPEED;

		// Check for collisions
		if (
			for (lvl) |l| {
				if (rl.CheckCollisionRecs(l, collision_rect))
					break false;
			} else true
		) player = collision_rect;
		player_pos.x = player.x - TILE / 2;
		player_pos.y = player.y + TILE / 2;

		camera.target = player_pos;

		rl.BeginDrawing();
		defer rl.EndDrawing();

		rl.ClearBackground(rl.BLACK);

		rl.BeginMode2D(camera);
		defer rl.EndMode2D();

		rl.DrawRectangleRec(player, rl.RED);

		// draw level
		for (lvl) |l|
			rl.DrawRectangleRec(l, rl.RAYWHITE);
	}
}

test "hello world" {
	std.debug.print("Hello world\n", .{});
}

test "raylib test" {
	std.debug.print("x: {d:.0} y: {d:.0}  width: {d:.0} height: {d:.0}\n", player);
}
