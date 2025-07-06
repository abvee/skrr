const std = @import("std");
const posix = std.posix;
const net = std.net;
const NUM_PLAYERS = @import("constants.zig").NUM_PLAYERS;
const assert = std.debug.assert;

var sock: posix.socket_t = undefined;
const addr = net.Address.initIp4(
   [4]u8{127,0,0,1},
   12271,
);

var clients: [NUM_PLAYERS]std.fs.File =
   [_]std.fs.File{std.fs.File{.handle=0}} ** NUM_PLAYERS;

// start socket and bind it
pub fn init() !void {
   sock = try posix.socket(
      posix.AF.INET,
      posix.SOCK.STREAM,
      posix.IPPROTO.TCP,
   );

   try posix.bind(
      sock,
      &addr.any,
      addr.getOsSockLen(),
   );

   try posix.listen(
      sock,
      NUM_PLAYERS * 2,
   );
}

pub fn deinit() void {
   posix.close(sock);

   for (clients) |client| {
      if (client.handle != 0)
         client.close();
   }
}

test "hello socket" {
   try init();
   defer deinit();
}

// return the client and fill in the id for the client fd
pub fn new_con(i: u16) !net.Address {

   // return the incoming client address
   var ret_client: net.Address = undefined;
   var ret_client_len: posix.socklen_t = @sizeOf(net.Address);

   const client_fd = try posix.accept(
      sock,
      &ret_client.any,
      &ret_client_len,
      posix.SOCK.NONBLOCK,
   );

   clients[i] = std.fs.File{
      .handle = client_fd,
   };

   return ret_client;
}

// write packet to that client
pub inline fn yeet(id: u16, pkt: []u8) !void {
   // TODO: assert that the file handle is not the default, ie, the client
   // exists
   assert(clients[id].handle != 0);

   _ = try clients[id].write(pkt);
}

// return packet from a client
pub inline fn yoink(id: u16, buf: []u8) ![]u8 {
   // TODO: assert that the file handle is not the default, ie, the client
   // exists
   assert(clients[id].handle != 0);

   const n = try clients[id].read(buf);
   return buf[0..n];
}
