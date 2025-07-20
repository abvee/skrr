const std = @import("std");
const net = std.net;
const posix = std.posix;
const assert = std.debug.assert;
const tcp = @import("tcp.zig");
const udp = @import("udp.zig");
const NUM_PLAYERS = @import("constants.zig").NUM_PLAYERS;
const TICK = @import("constants.zig").TICK;

const stdin = std.io.getStdIn();

// These operations encode a hot loop
const ops = enum(u16) {
   DEFAULT = 0x100, // Should be unreachable
   HELLO = 0xff,
   DISCONNECT = 0x11,
   POS = 0x00,
   NP = 0x33, // new player

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

// This is supposed to be an rl.Vector2 for now, but it's kinda stupid linking
// raylib to the server. I mean, we're not rendering anything....
// So this will have to do. We can also add other things to this in the future
// to track player state and data and things like that
const pdata = struct {
   x: f32,
   y: f32,
   angle: f32,
};

// Okay, different idea
// what if I use TCP to send the UDP address lmao ?
// like, we could just send the UDP port through the TCP connection then use
// initIp4() to initialise.. this
// That sounds like a terrible idea, but whatever. Because the alternative is to
var conns: [NUM_PLAYERS]?net.Address = .{null} ** NUM_PLAYERS;
var tcp_conns: [NUM_PLAYERS]net.Address = undefined;
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
   
   // tcp acceptor thread
   _ = try std.Thread.spawn(.{}, acceptor, .{});
   // tcp reciever tread
   _ = try std.Thread.spawn(.{}, receiver, .{});

   _ = try std.Thread.spawn(.{}, pdata_sender, .{});
   // udp receiver
   // TODO: maybe make a unified packet handler
   _ = try std.Thread.spawn(.{}, pdata_receiver, .{});

   defer run_threads = false;

   // Break on reading anything
   var buf: [1]u8 = [_]u8{0};
   _ = try stdin.read(&buf);
}

// UDP thread to constantly broadcast player data
fn pdata_sender() !void {
   var pkt: [2 + @sizeOf(pdata)]u8 =
      [_]u8{0} ** (2 + @sizeOf(pdata));

   while (run_threads) : (
      std.time.sleep(TICK)
   ) {

      // TODO: We are currently sending each player's position, one at a time.
      // Look into maybe sending all the positions at once to each player
      for (conns, 0..) |conn, i|
         if (conn) |_| {
            // This is bad code. We are relying on a number of things here
            // that might not be true always.

            // Future me: Why was this bad code again ?
            pkt[0] = @intFromEnum(ops.POS);
            pkt[1] = @intCast(i);
            std.mem.copyForwards(
               u8,
               pkt[2..],
               std.mem.asBytes(&players[i]),
            );
            udp.broadcast(@intCast(i), &pkt, &conns);
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

// Accept new connections
// We have to rework this
// I think it would be better if there was an async implementation that could
// deal with all the handshaking that comes with accepting a new connection

// I mean, we have to send a hello packet, we have to receive a packet and then
// broadcast to everyone else that a new player has joined.
// I was thinking of moving all of this to a new file in itself called
// "handshaking.zig".

// Because we haven't even scratched the surface here. There is so much
// handshaking to do before ever joining a single match. We have to deal with
// levels, naming, secrets and anti-cheat, colour, gamemode, character and a
// ton of other stuff

// And dumping all that in this acceptor thread that's supposed to block and
// listen of new connections only makes 0 sense.

// so there is that future refactor to do. I'll make an async implementation,
// probably a thread pool to do all that work for me.

// for now though, I'll just broadcast the writing everywhere
fn acceptor() !void {
   std.debug.print("Server is now accepting connections\n", .{});
   while (run_threads) {
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
      tcp_conns[id] = try tcp.new_con(id);
      std.debug.print("New connection: {any}:{} id: {}\n", .{
         std.mem.asBytes(&tcp_conns[id].in.sa.addr),
         tcp_conns[id].getPort(),
         id,
      });

      // send hello packet
      var buf: [1024]u8 = [_]u8{0} ** 1024;
      const pkt = hello(id, &buf);
      try tcp.yeet(id, pkt); // sending a packet should not fail
      std.debug.print("Sent id {} hello packet: {x}\n", .{id, pkt});

      // Wait for the response. We shouldn't do anything until then
      // NOTE: this might never come, which would hang the acceptor thread forever.
      // The solution would possibly be to offload the entire hand shake
      // process (hello packet and it's response) to another async thingy
      // TODO: What I said above ^

      // blocks until id is ready to read
      try tcp.block(id);
      const response_pkt = try tcp.yoink(id, &buf);
      std.debug.print("Received hello packet from id {}: {x}\n", .{
         id,
         response_pkt,
      });

      // TODO: anti cheat stuff here
      assert(response_pkt[0] == @intFromEnum(ops.HELLO));
      assert(response_pkt[1] == id);
      // NOTE: this ^ can be safely removed
      // We know it's from this id, so the client doesn't need to send it.

      conns[id] = tcp_conns[id];
      conns[id].?.setPort(
         std.mem.bytesToValue(u16, response_pkt[2..4]),
      );
      num_conns += 1;

      // we then broadcast to everyone that a new player has joined
      buf[0] = @intFromEnum(ops.NP);
      buf[1] = @intCast(id); // id of the new player
      tcp.broadcast(id, buf[0..2]);
      std.debug.print("Broadcasted new player packet for id {}: {x}\n",
         .{id, buf[0..2]}
      );
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
      std.time.sleep(TICK)
   ) {
      for (conns, 0..) |conn, i| {
         // player exists
         if (conn) |_| {
            pkt = tcp.yoink(@intCast(i), &buf)
               catch |e| switch (e) {
                  error.WouldBlock => {
                     std.debug.print("id {} has no TCP packets\n", .{i});
                     continue;
                  },
                  // ^ means no packet
                  else => return e,
               };
            std.debug.print("Recieved TCP packet from id {}:- {x}\n", .{
               i,
               pkt,
            });

            // each packet would need an operation and an assert
            const operation = ops.valid(pkt[0]);
            assert(i == pkt[1]);

            // TODO: move this handling somewhere else
            // We should be able to read more and more packets ideally for both
            // TCP and UDP while still receiving them. This would require a
            // leaky bucket implementation on the UDP side, but TCP should do
            // with just a queue. We'll do this later.
            switch (operation) {
               ops.DISCONNECT => {
                  conns[i] = null;
                  num_conns -= 1;

                  tcp.disconnect(@intCast(i));
                  tcp.broadcast(@intCast(i), &.{
                     @intFromEnum(ops.DISCONNECT),
                     @intCast(i),
                  });
                  std.debug.print("Disconnected id {}\n", .{i});
               },
               else => {}, // Anything else for now, we ignore
            }
         }
      }
   }
}

// UDP receiver
fn pdata_receiver() !void {
   var buf: [1024]u8 = [_]u8{0} ** 1024;
   var pkt: []u8 = undefined;

   hot: switch (ops.DEFAULT) {
      ops.DEFAULT => {
         var client: net.Address = undefined;
         pkt = udp.yoink(&buf, &client)
            catch continue :hot ops.DEFAULT;
         const id = pkt[1];
         std.debug.print("Received UDP packet from id {}: {x}\n", .{id,pkt});

         // verify that the client is who the id claims
         // TODO: anti cheat handle this
         assert(conns[id] != null);

         // assert(conns[id].?.eql(client));
         // NOTE: we can't do this ^. conns stores the TCP socket, while
         // recvfrom get's the client's UDP socket address.

         // For now, we can just assume everything is fine, but we should
         // probably send a UDP hello packet with a secret or something as well
         // from the client, so we can record their UDP connection as well

         continue :hot ops.valid(pkt[0]);
      },
      ops.POS => {
         const id = pkt[1];
         players[id] = std.mem.bytesToValue(
            pdata,
            pkt[2..],
         );
         continue :hot ops.DEFAULT;
      },
      else => continue :hot ops.DEFAULT,
   }
}
