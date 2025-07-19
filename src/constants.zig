pub const TILE = 80;

pub const NUM_PLAYERS = 8; // max players

const std = @import("std");
const math = std.math;

pub const GUN_RADIUS = 10;
pub const RADIUS = @as(f32, @floatFromInt(TILE)) / math.sqrt2 + GUN_RADIUS;
