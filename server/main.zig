const std = @import("std");
const net = std.net;
const posix = std.posix;
const assert = std.debug.assert;
const tcp = @import("tcp.zig");
const NUM_PLAYERS = @import("constants.zig").NUM_PLAYERS;

const ops = enum(u16) {
   DEFAULT = 0x100, // Should be unreachable
   HELLO = 0xff,
   DISCONNECT = 0x11,
   POS = 0x00,

   // check if the integer is a valid enum
   // Return the enum
   pub fn valid(in: @typeInfo(@This()).@"enum".tag_type) @This() {

      // loop through the enum and check if the integer is part of it
      inline for (@typeInfo(@This()).@"enum".fields) |field| {
         if (in == @intFromEnum(@field(@This(), field.name)))
            return @enumFromInt(in);
      }

      // if we have reached here, it's an invalid packet
      // Return the first entry. DEFAULT in this case
      return @field(@This(), @typeInfo(@This()).@"enum".fields[0].name);
   }
   // NOTE: I have tried to make this ^ function as generic as possible.
   // probably a bad idea
};

const addr = net.Address.initIp4(
   [4]u8{127,0,0,1},
   12271
);
var sock: posix.socket_t = undefined;

// This is supposed to be an rl.Vector2 for now, but it's kinda stupid linking
// raylib to the server. I mean, we're not rendering anything....
// So this will have to do. We can also add other things to this in the future
// to track player state and data and things like that
const pdata = struct {
   x: f32,
   y: f32,
};

var conns: [NUM_PLAYERS]?net.Address = .{null} ** NUM_PLAYERS;
var num_conns: u16 = 0; // number of active players
var players: [NUM_PLAYERS]pdata = undefined;

pub fn main() !void {
   // initialize
   try tcp.init();
   defer tcp.deinit();
   
   // start tcp acceptor thread
   _ = try std.Thread.spawn(.{}, acceptor, .{});
   while (true) {}
}

// pub fn main() !void {

//    // this buffer holds all our data
//    var buf: [1024]u8 = [_]u8{0} ** 1024;
//    var pkt: []u8 = undefined; // the packet
// 
//    var client: net.Address = undefined;
//    var client_len: posix.socklen_t = @sizeOf(net.Address);
// 
//    _ = try std.Thread.spawn(.{}, pdata_sender, .{});
// 
//    hot: switch (ops.DEFAULT) {
//       .DEFAULT => {
//          const n = try posix.recvfrom(
//             sock,
//             &buf,
//             0, // flags
//             &client.any, // client addr destination
//             &client_len, // client addr length
//          );
// 
//          pkt = buf[0..n]; // fill packet
// 
//          std.debug.print("Recieved packet: {x}\n", .{pkt});
// 
//          // valid() will return the enum in pkt[0] if it's valid, otherwise
//          // it'll return DEFAULT
//          continue :hot ops.valid(pkt[0]);
//       },
//       .HELLO => {
//          // TODO: assert to make sure the client exists before assigning
// 
//          // construct and send the hello packet
//          const i = hello(client) catch continue :hot ops.DEFAULT;
//          // TODO: do something if we fail to send the hello packet
// 
//          // set the client id
//          conns[i] = client;
//          continue :hot ops.DEFAULT;
//       },
//       .DISCONNECT => {
//          assert(pkt[0] == @intFromEnum(ops.DISCONNECT));
//          assert(pkt.len >= 2);
// 
//          const id = pkt[1];
// 
//          // before we close the connection, we should broadcast to everyone
//          // that the client has disconnected
//          const disconnect_pkt: [2]u8 = [_]u8{
//             @intFromEnum(ops.DISCONNECT),
//             id,
//          };
//          broadcast(id, &disconnect_pkt)
//             catch {};
//          // TODO: do something when broadcasting fails.
// 
//          conns[id] = null;
// 
//          // TODO: do some handshake to make sure any client cannot close any
//          // other client, either maliciously or by mistake
//          std.debug.print("Disconnected player w/ id: {}\n", .{id});
//          continue :hot ops.DEFAULT;
//       },
//       .POS => {
//          assert(pkt[0] == @intFromEnum(ops.POS));
//          const id = pkt[1];
// 
//          // verify that the client has the same id
//          if (conns[id] == null)
//             continue :hot ops.DEFAULT
//          else if (!conns[id].?.eql(client))
//             continue :hot ops.DEFAULT;
//          // TODO: someone might be intentionally trying to change another's
//          // position. Anticheat will come later
// 
//          // Update the positions
//          players[id] = std.mem.bytesToValue(
//             pdata,
//             pkt[2..],
//          );
// 
//          std.debug.print("Updated position for id {}: x: {d:.2} y: {d:.2}\n", .{
//             id, players[id].x, players[id].y
//          });
// 
//          continue :hot ops.DEFAULT;
//       },
//    }
// }

fn pdata_sender() !void {
   var pkt: [2 + @sizeOf(pdata)]u8 =
      [_]u8{0} ** (2 + @sizeOf(pdata));

   while (true) {
      std.time.sleep(std.time.ns_per_s * 0.1);

      // TODO: We are currently sending each player's position, one at a time.
      // Look into maybe sending all the positions at once to each player

      for (conns, 0..) |conn, i|
         if (conn) |_| {
            // This is bad code. We are relying on a number of things here
            // that might not be true always.
            pkt[0] = @intFromEnum(ops.POS);
            pkt[1] = @intCast(i);
            std.mem.copyForwards(
               u8,
               pkt[2..],
               std.mem.asBytes(&players[i]),
            );
            broadcast(@intCast(i), &pkt)
               catch {};
         };
   }
}


test "hello packet" {
   const client = net.Address.initIp4(
      [4]u8{127,0,0,1},
      12271,
   );

   const id = try hello(client);
   std.debug.print("{}\n", .{id});
}

// broadcast packet to everyone except conns_id
inline fn broadcast(conns_id: u8, pkt: []const u8) !void {
   for (conns, 0..) |conn, i| {
      if (i == conns_id) continue;

      if (conn) |c|
         _ = try posix.sendto(
            sock,
            pkt,
            0,
            &c.any,
            c.getOsSockLen(),
         );
   }
}

// Accept new connections
// Do the handshake
fn acceptor() !void {
   std.debug.print("Server is now accepting connections\n", .{});
   // we only accept if we have space
   while (num_conns < NUM_PLAYERS) {

      var id: u16 = 0;
      var i: u8 = 0; // we check this later
      for (conns) |conn| {
         if (conn == null) {
            id = @intCast(i);
            break;
         }
         i += 1;
      }
      std.debug.print("Found id: {}\n", .{id});

      // get the client of new person
      conns[id] = try tcp.new_con(id);
      num_conns += 1;
      std.debug.print("New connection: {any}:{}\n", .{
         std.mem.asBytes(&conns[id].?.in.sa.addr),
         conns[id].?.getPort(),
      });

      // send hello packet
      var buf: [1024]u8 = [_]u8{0} ** 1024;
      const pkt = hello(id, &buf);
      try tcp.yeet(id, pkt); // sending a packet should not fail
   }
}

// send the client his hello packet
inline fn hello(id: u16, buf: []u8) []u8 {
   buf[0] = @intCast(@intFromEnum(ops.HELLO)); // the op code
   buf[1] = @intCast(id);
   var buf_index: u32 = 2;

   for (conns, 0..) |conn, i| {
      // skip our player
      if (i == id) continue;

      // if player exists, add it
      if (conn) |_| {
         buf[buf_index] = @intCast(i);
         buf_index += 1;
      }
   }
   return buf[0..buf_index];
}
test "hello" {
   std.debug.print("HELLO PKT\n", .{});
   const pkt = hello();
   std.debug.print("{x}\n", .{pkt});
}
