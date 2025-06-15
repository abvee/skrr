const std = @import("std");
const net = std.net;
const posix = std.posix;
const assert = std.debug.assert;

const addr = net.Address.initIp4(
	[4]u8{127,0,0,1},
	12271,
); // the server address

var server: std.fs.File = undefined;

// start the socket
// connect to the server
pub fn init() !void {
	const sock = try posix.socket(
		posix.AF.INET,
		posix.SOCK.DGRAM,
		posix.IPPROTO.UDP,
	);
	errdefer posix.close(sock);

	// TODO: don't hardcode the server's address.
	try posix.connect(
		sock,
		&addr.any,
		addr.getOsSockLen(),
	);

	server = std.fs.File{
		.handle = sock
	};
	_ = try server.write("Hello world");
}

pub fn deinit() void {
	// TODO: assert that init() has been called
	server.close();
}
