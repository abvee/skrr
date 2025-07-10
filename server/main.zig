const std = @import("std");
const net = std.net;
const posix = std.posix;
const assert = std.debug.assert;
const tcp = @import("tcp.zig");
const udp = @import("udp.zig");
const NUM_PLAYERS = @import("constants.zig").NUM_PLAYERS;

const stdin = std.io.getStdIn();

// These operations encode a hot loop
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

var run_threads = true;

pub fn main() !void {
   std.debug.print("Press Enter to kill server\n", .{});

   // initialize
   try tcp.init();
   defer tcp.deinit();

   try udp.init();
   defer udp.deinit();
   
   // start tcp acceptor thread
   _ = try std.Thread.spawn(.{}, acceptor, .{});
   // start tcp reciever tread
   _ = try std.Thread.spawn(.{}, receiver, .{});

   defer run_threads = false;

   // Break on reading anything
   var buf: [1]u8 = [_]u8{0};
   _ = try stdin.read(&buf);
}

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
fn acceptor() !void {
   std.debug.print("Server is now accepting connections\n", .{});
   // we only accept if we have space
   while (run_threads) {
      // wait for a disconnect ??? 
      // No, wait this might kill a connect on the client side ?
      // We should instead accept a connection here and kill it right off
      // TODO: figure what we should do. I'm thinking just tcp.deny_con()
      // But that would requires us to check before we wait and check
      // everytime, so it's a mess.
      // frankly, I don't know what to do if the lobby is full. Maybe we do
      // need that semaphore after all, just to check if the... wait a second
      // We can just hang with a no-op here can we not ?
      // I mean, we are doing it now. num_conns is the semaphore right ?
      // Okay, hold on. is looping indefinitely bad ? I mean, who care right
      // now, but whatever, let's do it

      // semaphore loop
      // This means the lobby is full
      // We can only accept connections when someone has disconnected
      while (num_conns >= NUM_PLAYERS) {}

      // get the next free id
      var id: u16 = 0;
      for (conns, 0..) |conn, i| {
         if (conn == null) {
            id = @intCast(i);
            break;
         }
      }

      // get the client of new person
      conns[id] = try tcp.new_con(id);
      num_conns += 1;
      std.debug.print("New connection: {any}:{} id: {}\n", .{
         std.mem.asBytes(&conns[id].?.in.sa.addr),
         conns[id].?.getPort(),
         id,
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

// TCP receiver
// loop through the nonblocking sockets, and if there's a packet do something
// with it ig
fn receiver() !void {
   var buf: [1024]u8 = [_]u8{0} ** 1024;
   var pkt: []u8 = undefined;

   while (run_threads) : (
      std.time.sleep(std.time.ns_per_s)
   ) {
      for (conns, 0..) |conn, i| {
         // player exists
         if (conn) |c| {
            pkt = tcp.yoink(@intCast(i), &buf)
               catch |e| switch (e) {
                  error.WouldBlock => {
                     std.debug.print("id {} has no packets\n", .{i});
                     continue;
                  },
                  // ^ means no packet
                  else => return e,
               };
            std.debug.print("Recieved packet from {any}:{} - {x}\n", .{
               std.mem.asBytes(&c.in.sa.addr),
               c.getPort(),
               pkt,
            });
            // TODO: move this handling somewhere else
            // We should be able to read more and more packets ideally for both
            // TCP and UDP while still receiving them. This would require a
            // leaky bucket implementation on the UDP side, but TCP should do
            // with just a queue. We'll do this later.

            // each packet would need an operation and an assert
            const operation = ops.valid(pkt[0]);
            assert(i == pkt[1]);

            switch (operation) {
               ops.DISCONNECT => {
                  conns[i] = null;
                  num_conns -= 1;

                  tcp.disconnect(@intCast(i));
                  std.debug.print("Disconnected id {}\n", .{i});
               },
               else => {}, // Anything else for now, we ignore
            }
         }
      }
   }
}
