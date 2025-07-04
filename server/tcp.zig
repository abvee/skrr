const std = @import("std");
const posix = std.posix;
const net = std.net;
const NUM_PLAYERS = @import("constants.zig").NUM_PLAYERS;

var sock: posix.socket_t = undefined;
const addr = net.Address.initIp4(
   [4]u8{127,0,0,1},
   12271,
);
var clients: [NUM_PLAYERS]std.fs.File = undefined;

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
}

test "hello socket" {
   try init();
   defer deinit();
}

// return the client and fill in the id for the client fd
pub fn new_con(i: u8) !net.Address {
   _ = i;
}
