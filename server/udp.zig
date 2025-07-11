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

pub inline fn yeet(client: net.Address, pkt: []const u8) !void {
   _ = try posix.sendto(
      sock,
      pkt,
      0,
      &client.any,
      client.getOsSockLen(),
   );
}

pub inline fn yoink(buf: []u8, client: *net.Address) ![]u8 {
   // NOTE: we should do something about using @sizeOf everywhere
   // It does not work on macOS
   var client_len: posix.socklen_t = @sizeOf(net.Address);
   // we throw this away ^

   const n = try posix.recvfrom(
      sock,
      buf,
      0,
      &client.any,
      &client_len,
   );

   return buf[0..n];
}
