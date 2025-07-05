const std = @import("std");
const net = std.net;
const posix = std.posix;

const addr = net.Address.initIp4(
   [4]u8{127,0,0,1},
   12271,
);

var server: std.fs.File = undefined;

// create and connect socket
pub fn init() !void {
   const sock = try posix.socket(
      posix.AF.INET,
      posix.SOCK.STREAM,
      posix.IPPROTO.TCP,
   );

   // connect
   try posix.connect(
      sock,
      &addr.any,
      addr.getOsSockLen(),
   );

   server = std.fs.File{
      .handle = sock,
   };
}

pub fn deinit() void {
   server.close();
   // this ^ should close the socket
}
