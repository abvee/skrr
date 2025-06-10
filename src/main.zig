const std = @import("std");

pub fn main() void {
	std.debug.print("Hello world\n", .{});
}

test "hello world" {
	std.debug.print("Hello world\n", .{});
}
