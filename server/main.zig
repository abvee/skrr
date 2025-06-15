const std = @import("std");
const net = std.net;
const posix = std.posix;

const addr = net.Address.initIp4(
	[4]u8{127,0,0,1},
	12271
);

pub fn main() !void {
	// create socket and bind
	const sock = try posix.socket(
		posix.AF.INET,
		posix.SOCK.DGRAM,
		posix.IPPROTO.UDP,
	);

	try posix.bind(
		sock,
		&addr.any,
		addr.getOsSockLen()
	);

	// for now, accept a client and print what they send you
	var buf: [1024]u8 = [_]u8{0} ** 1024;
	const n = try posix.recvfrom(
		sock,
		&buf,
		0, // flags
		null, // client addr destination
		null, // client addr length
	);

	std.debug.print("{s}\n", .{buf[0..n]});
}
