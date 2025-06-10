const std = @import("std");

const rl = @cImport({
	@cInclude("raylib.h");
	@cInclude("raymath.h");
	@cInclude("rlgl.h");
});

const window_width = 1440;
const window_height = 900;

pub fn main() void {

	rl.SetConfigFlags(rl.FLAG_WINDOW_RESIZABLE);
	rl.InitWindow(window_width, window_height, "skrr");
	defer rl.CloseWindow();

	while (!rl.WindowShouldClose()) {
		rl.BeginDrawing();
		defer rl.EndDrawing();

		rl.ClearBackground(rl.BLACK);
		rl.DrawText("Hello world", window_width / 2, window_height / 2, 20, rl.RAYWHITE);
	}

	std.debug.print("Hello world\n", .{});
}

test "hello world" {
	std.debug.print("Hello world\n", .{});
}
