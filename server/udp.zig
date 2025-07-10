const std = @import("std");
const posix = std.posix;
const net = std.net;

const addr = net.Address.initIp4(
   [4]u8{127,0,0,1},
   12271
);
var sock: posix.socket_t = undefined;

pub fn init() !void {
   sock = try posix.socket(
      posix.AF.INET,
      posix.SOCK.DGRAM,
      posix.IPPROTO.UDP,
   );

   try posix.bind(
      sock,
      &addr.any,
      addr.getOsSockLen(),
   );
}

pub fn deinit() void {
   posix.close(sock);
}
