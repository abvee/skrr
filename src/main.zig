const std = @import("std");
const rl = @cImport({
	@cInclude("raylib.h");
	@cInclude("raymath.h");
	@cInclude("rlgl.h");
});
const level = @import("level.zig");
const network = @import("network.zig");

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
}; // the player rectangle

// other player positions
var others: [8]?rl.Vector2 = .{null} ** 8;
var others_rec: [8]rl.Rectangle = [_]rl.Rectangle{
	rl.Rectangle{
		.width = TILE,
		.height = TILE,
	},
} ** 8;
// this ^ might be unnecessary

pub fn main() !void {
	// General purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        // can't try in defer as defer is executed after we return
        if (deinit_status == .leak) std.testing.expect(false)
			catch @panic("Memory leak");
    }

	// This needs to be set for making the window tiling on sway
	rl.SetConfigFlags(rl.FLAG_WINDOW_RESIZABLE);

	rl.InitWindow(window_width, window_height, "skrr");
	defer rl.CloseWindow();

	// connect to server
	try network.init();
	defer network.deinit();

	// get player position data and your id
	// only run when you newly join a server
	network.new_join(&others) catch {};
	defer network.disconnect();
	// TODO: make level loading also done with this ?
	// TODO: handle errors. It's fine to ignore them as others just becomes
	// null for now, but we shouldn't.

	var camera: rl.Camera2D = rl.Camera2D{
		.target = player_pos,
		.offset = rl.Vector2{.x = window_width/2, .y = window_height/2},
		.rotation = 0,
		.zoom = 1, // TODO: maybe change this for resolution resizing stuff ? 
	};

	// yes, level loading
	const lvl = try level.load(allocator, "levels/level1");
	defer allocator.free(lvl);

	// load player start position
	player_pos = try level.start_position("levels/level1");
	player.x = player_pos.x - TILE / 2;
	player.y = player_pos.y - TILE / 2;

	std.debug.print("{d:.2} {d:.2}\n", player_pos);

	// start the physics thread
	_ = try std.Thread.spawn(.{}, physics, .{});

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
		player_pos.x = player.x + TILE / 2;
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

		// draw other players
		draw_others();
	}
}

test "hello world" {
	std.debug.print("Hello world\n", .{});
}

test "raylib test" {
	std.debug.print("x: {d:.0} y: {d:.0}  width: {d:.0} height: {d:.0}\n", player);
}

// While the function is called physics, it refers to anything that needs a
// fixed timing
fn physics() void {
	while (true) {
		std.time.sleep(std.time.ns_per_s * 0.5);

		network.send_pos(player_pos)
			catch {};
	}
}


// should be called inside raylib BeginMode2D
inline fn draw_others() void {
	for (others,0..) |o,i| {
		if (o) |_| {

			// update the rectangle position. we can do this just before
			// drawing, it's fine. I'm not sure I'll keep others_rec around
			// anyways. The source of truth is always others: []?rl.Vector2
			others_rec[i].x = o.?.x - TILE / 2;
			others_rec[i].y = o.?.y - TILE / 2;

			rl.DrawRectangleRec(others_rec[i], rl.SKYBLUE);
		}
	}
}
