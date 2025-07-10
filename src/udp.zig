const std = @import("std");
const net = std.net;
const posix = std.posix;

const addr = net.Address.initIp4(
   [4]u8{127,0,0,1},
   12271,
);

var server: std.fs.File = undefined;

pub fn init() !void {
   const sock = try posix.socket(
      posix.AF.INET,
      posix.SOCK.DGRAM,
      posix.IPPROTO.UDP,
   );

   try posix.connect(
      sock,
      &addr.any,
      comptime addr.getOsSockLen(),
   );

   server = std.fs.File{
      .handle = sock,
   };
}

pub fn deinit() void {
   server.close();
}

pub inline fn yeet(pkt: []const u8) !void {
   _ = try server.write(pkt);
}
