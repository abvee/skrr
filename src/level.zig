const std = @import("std");
const rl = @cImport({
	@cInclude("raylib.h");
	@cInclude("raymath.h");
	@cInclude("rlgl.h");
});
const assert = std.debug.assert;

const constants = @import("constants.zig");
const TILE = constants.TILE;

var offset: u64 = 0; // offset of the level file after load is called
// This is housekeeping that is used in start_position and other functions

// NOTE that the level files have coordinates in with 1 tile as 1 unit
pub fn load(allocator: std.mem.Allocator, path: []const u8) ![]rl.Rectangle {
	const file = try std.fs.cwd().openFile(path, .{});
	defer file.close();
	const reader = file.reader();

	// set file offset to 0. Keeping track of which file the offset is for is
	// not our concern here
	offset = 0;
	defer offset = file.getPos() catch 0;
	// NOTE: we assert that offset is not 0 later

	// We load the level into this
	var bigboi: [2048]rl.Rectangle = [_]rl.Rectangle{
		rl.Rectangle{.x=0,.y=0,.width=0,.height=0}
	} ** 2048;
	var bigboi_index: u32 = 0;

	// read through the file, and load into rectangles
	var buf: [1024]u8 = undefined;

	var line: []u8 = try reader.readUntilDelimiter(&buf, '\n');
	// EOF here ^ is breaking

	// what is this abomination
	while (line.len != 0) :
	(
		line = reader.readUntilDelimiter(&buf, '\n')
			catch |e| switch (e) {
				error.EndOfStream => break,
				else => return e,
			}
	) {
		var it = std.mem.tokenizeAny(u8, line, ",");

		// fill the struct with tokenized results
		inline for (@typeInfo(rl.Rectangle).@"struct".fields) |field| {

			if (it.next()) |num| @field(bigboi[bigboi_index], field.name) =
				@floatFromInt((std.fmt.parseInt(u32, num, 10) catch 0) * TILE);
				// we catch 0 because what could possibly go wrong ?
		}
		bigboi_index += 1;

	}


	const ret = try allocator.alloc(rl.Rectangle, bigboi_index);
	std.mem.copyForwards(rl.Rectangle, ret, bigboi[0..bigboi_index]);
	return ret;
}

test "level loading" {
	var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
	defer arena.deinit();
	const allocator = arena.allocator();

	const level = load(allocator, "levels/level1")
		catch |e| {
			std.debug.print("{any}\n", .{e});
			return e;
		};
	std.debug.print("length: {d}\n", .{level.len});
	for (level) |l|
		std.debug.print("x: {d:.0} y: {d:.0} width: {d:.0} height: {d:.0}\n", l);
	std.debug.print("File Offset: {d}\n", .{offset});
}

// return a start position for the player
pub fn start_position(path: []const u8) !rl.Vector2 {
	assert(offset != 0);
	// the level file is very broken if offset is either 0 or getPos() from
	// std.fs.File could not be called

	const file = try std.fs.cwd().openFile(path, .{});
	defer file.close();

	// go to offset
	file.seekTo(offset);
}
