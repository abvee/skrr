const std = @import("std");

const rl = @cImport({
	@cInclude("raylib.h");
	@cInclude("rlgl.h");
	@cInclude("raymath.h");
});

pub fn main() void {
	const screenWidth = 1920;
	const screenHeight = 1080;

	rl.InitWindow(screenWidth, screenHeight, "skrr");
	defer rl.CloseWindow();

	while (!rl.WindowShouldClose()) {
		rl.BeginDrawing();
		defer rl.EndDrawing();

		rl.ClearBackground(rl.BLACK);
		rl.DrawText("Hello world", screenWidth / 2, screenHeight / 2, 20, rl.RAYWHITE);
	}
}
