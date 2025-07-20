const std = @import("std");
const math = std.math;

pub const TILE = 80;
pub const NUM_PLAYERS = 8; // max players
pub const SPEED = 0.1;


pub const GUN_RADIUS = 20;
pub const RADIUS = @as(f32, @floatFromInt(TILE)) / math.sqrt2 + GUN_RADIUS;

// Just a standard measurement of time :D
pub const TICK = std.time.ns_per_s * 0.1;
