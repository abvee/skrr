const std = @import("std");
const net = std.net;
const posix = std.posix;
const tcp = @import("tcp.zig");
const assert = std.debug.assert;
const rl = @cImport({
   @cInclude("raylib.h");
   @cInclude("raymath.h");
   @cInclude("rlgl.h");
});

const NUM_PLAYERS = @import("constants.zig").NUM_PLAYERS;

const addr = net.Address.initIp4(
   [4]u8{127,0,0,1},
   12271,
); // the server address
var server: std.fs.File = undefined;
var id: u8 = undefined; // the id the server assigns us

pub const ops = enum(u8) {
   NULL = 0x01, // this is just to make the valid function work
   HELLO = 0xff,
   DISCONNECT = 0x11,
   POSITION = 0x00,

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
}

pub fn deinit() void {
   tcp.deinit();
}

test "init" {
   try init();
   defer tcp.deinit();
}

const PlayerError = error {
   PlayerAlreadyConnected,
};

pub fn new_join(others: []?rl.Vector2) !void {
   // send the hello packet
   try hello();

   // get hello packet back
   var buf: [1024]u8 = [_]u8{0} ** 1024;
   const n = try server.read(&buf);

   // we should get the first byte as the op for hello
   assert(buf[0] == @intFromEnum(ops.HELLO));

   // load your id
   assert(buf[1] < NUM_PLAYERS); // make sure we don't get an id that's out of bounds
   id = buf[1];


   // load everyone else's positions
   var i: usize = 2;
   while (i < n) : (i += @sizeOf(rl.Vector2) + 1) {
      // id of the other person
      const other_id = buf[i];

      if (others[other_id] == null) {
         others[other_id] = std.mem.bytesToValue(
            rl.Vector2,
            buf[i + 1..i + @sizeOf(rl.Vector2) + 1]
         );
      }
      else return PlayerError.PlayerAlreadyConnected;
   }
}

// construct and send the hello packet
inline fn hello() !void {
   const pkt: [1]u8 = [1]u8{0xff};
   // for now, the hello packet is just a single byte with the OP
   _ = try server.write(&pkt);
}

pub inline fn disconnect() void {
   // just write the disconnect
   // ideally, this cannot fail....
   // Even if it does, a server timeout should take the player out of
   // comission
   const pkt: [2]u8 = [_]u8{
      @intFromEnum(ops.DISCONNECT),
      id,
   };
   _ = server.write(&pkt)
      catch {};
}


// send our player's position
pub fn send_pos(position: rl.Vector2) !void {
   var pkt: [2 + @sizeOf(rl.Vector2)]u8 =
      [_]u8{0} ** (2 + @sizeOf(rl.Vector2));

   pkt[0] = @intFromEnum(ops.POSITION);
   pkt[1] = id;  // player's id

   std.mem.copyForwards(
      u8,
      pkt[2..],
      std.mem.asBytes(&position),
   );
   _ = try server.write(&pkt);
}

pub inline fn recv_pkt(buf: []u8) []u8 {
   return buf[0..server.read(buf) catch 1];
   // TODO: do something about this ^
}
