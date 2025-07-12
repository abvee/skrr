const std = @import("std");
const net = std.net;
const posix = std.posix;
const tcp = @import("tcp.zig");
const udp = @import("udp.zig");
const assert = std.debug.assert;
const rl = @cImport({
   @cInclude("raylib.h");
   @cInclude("raymath.h");
   @cInclude("rlgl.h");
});

const NUM_PLAYERS = @import("constants.zig").NUM_PLAYERS;
var id: u8 = undefined; // the id the server assigns us

pub const ops = enum(u8) {
   NULL = 0x01, // this is just to make the valid function work
   HELLO = 0xff,
   DISCONNECT = 0x11,
   POS = 0x00,

   // return the enum
   pub fn valid(in: @typeInfo(@This()).@"enum".tag_type) @This() {
      // loop through the enum and check if the integer is part of it
      inline for (@typeInfo(@This()).@"enum".fields) |field| {
         if (in == @intFromEnum(@field(@This(), field.name)))
            return @enumFromInt(in);
      }
      return @field(@This(), @typeInfo(@This()).@"enum".fields[0].name);
   }
};

// start the socket
// connect to the server
pub fn init() !void {
   try tcp.init();
   try udp.init();
}

pub fn deinit() void {
   tcp.deinit();
   udp.deinit();
}

test "init" {
   try init();
   defer tcp.deinit();
}

const PlayerError = error {
   PlayerAlreadyConnected,
};

// recieve the hello packet and set the others to not null
pub fn new_join(others: []?rl.Vector2) !void {
   // get hello packet from server
   var buf: [1024]u8 = [_]u8{0} ** 1024;
   const pkt = try tcp.yoink(&buf);

   // we should get the first byte as the op for hello
   assert(pkt[0] == @intFromEnum(ops.HELLO));
   assert(pkt[1] < NUM_PLAYERS); // make sure we don't get an id that's out of bounds

   id = buf[1];

   // for each id, set that position to not null
   for (pkt[2..]) |i| {
      assert(i < NUM_PLAYERS);

      if (others[i] != null)
         return PlayerError.PlayerAlreadyConnected;

      // hmm, perhaps we should have a more sensible default position ?
      // Setting it to (0,0) works ig, but who knows where that would be in
      // world space
      others[i] = rl.Vector2{.x = 0, .y = 0};
   }
}

pub fn disconnect() void {
   const disconnect_pkt = .{@intFromEnum(ops.DISCONNECT), id};
   tcp.yeet(&disconnect_pkt) catch {};
   // ^ We don't care if disconnecting to the server fails
}

test "A connect and disconnect test" {
   try init();
   defer deinit();

   var others: [NUM_PLAYERS]?rl.Vector2 = .{null} ** NUM_PLAYERS;

   try new_join(&others);
   defer disconnect();

   const stdin = std.io.getStdIn();
   var x: [1]u8 = .{0};
   _ = try stdin.read(&x);
}

pub fn send_pos(position: rl.Vector2) void {
   var buf: [2 + @sizeOf(rl.Vector2)]u8 =
      [_]u8{0} ** (2 + @sizeOf(rl.Vector2));

   buf[0] = @intFromEnum(ops.POS);
   buf[1] = id;
   std.mem.copyForwards(
      u8,
      buf[2..],
      std.mem.asBytes(&position),
   );

   std.debug.print("Client sent position: {d:.2} {d:.2}\n", position);
   udp.yeet(&buf) catch {};
}

// the UDP receiver that updates our positions
pub fn receiver(others: []?rl.Vector2) void {
   var buf: [1024]u8 = [_]u8{0} ** 1024;
   var pkt: []u8 = undefined;

   hot: switch (ops.NULL) {
      ops.NULL => {
         pkt = udp.yoink(&buf)
            catch continue :hot ops.NULL;
         std.debug.print("Got packet: {x}\n", .{pkt});
         const player_id = pkt[1];

         // The server is never supposed to be wrong, so this assert can stay
         // forever
         assert(others[player_id] != null);
         continue :hot ops.valid(pkt[0]);
      },
      ops.POS => {
         others[pkt[1]] = std.mem.bytesToValue(
            rl.Vector2,
            pkt[2..2 + @sizeOf(rl.Vector2)],
         );
         continue :hot ops.NULL;
      },
      else => unreachable,
      // change this to continue in the final build, right
      // now it's useful for debugging
   }
}
