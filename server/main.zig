const std = @import("std");
const net = std.net;
const posix = std.posix;

const ops = enum(u16) {
	DEFAULT,
	HELLO = 0xff,
};

const addr = net.Address.initIp4(
	[4]u8{127,0,0,1},
	12271
);
var sock: posix.socket_t = undefined;

pub fn main() !void {
	// create socket and bind
	sock = try posix.socket(
		posix.AF.INET,
		posix.SOCK.DGRAM,
		posix.IPPROTO.UDP,
	);

	try posix.bind(
		sock,
		&addr.any,
		addr.getOsSockLen()
	);

	// this buffer holds all our data
	var buf: [1024]u8 = [_]u8{0} ** 1024;
	var pkt: []u8 = undefined; // the packet

	_ = hot: switch (ops.DEFAULT) {
		.DEFAULT => {
			const n = try posix.recvfrom(
				sock,
				&buf,
				0, // flags
				null, // client addr destination
				null, // client addr length
			);
			pkt = buf[0..n]; // fill packet
			std.debug.print("{s}\n", .{pkt}); // print
			break :hot ops.DEFAULT;
		},
		.HELLO => {
			// TODO: fill this
			break :hot ops.DEFAULT;
		},
	};
}

test "Hello world" {
	std.debug.print("Hello world\n", .{});
}
