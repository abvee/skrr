const std = @import("std");
const net = std.net;
const posix = std.posix;
const assert = std.debug.assert;
const rl = @cImport({
	@cInclude("raylib.h");
	@cInclude("raymath.h");
	@cInclude("rlgl.h");
});

const addr = net.Address.initIp4(
	[4]u8{127,0,0,1},
	12271,
); // the server address
var server: std.fs.File = undefined;
var id: u8 = undefined; // the id the server assigns us

const ops = enum(u8) {
	HELLO = 0xff,
	DISCONNECT = 0x11,
	POSITION = 0x00,
};

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
}

pub fn deinit() void {
	// TODO: assert that init() has been called
	server.close();
}

const PlayerError = error {
	PlayerAlreadyConnected,
};

pub fn new_join(others: []?rl.Vector2) !void {
	// send the hello packet
	try hello();

	// get hello packet back
	var buf: [1024]u8 = [_]u8{0} ** 1024;
	const n = try server.read(&buf);

	// we should get the first byte as the op for hello
	assert(buf[0] == @intFromEnum(ops.HELLO));

	// load your id
	assert(buf[1] < 8); // make sure we don't get an id that's out of bounds
	id = buf[1];


	// load everyone else's positions
	var i: usize = 2;
	while (i < n) : (i += @sizeOf(rl.Vector2) + 1) {
		// id of the other person
		const other_id = buf[i];

		if (others[other_id] == null) {
			others[other_id] = std.mem.bytesToValue(
				rl.Vector2,
				buf[i + 1..i + @sizeOf(rl.Vector2) + 1]
			);
		}
		else return PlayerError.PlayerAlreadyConnected;
	}
}

// construct and send the hello packet
inline fn hello() !void {
	const pkt: [1]u8 = [1]u8{0xff};
	// for now, the hello packet is just a single byte with the OP
	_ = try server.write(&pkt);
}

pub inline fn disconnect() void {
	// just write the disconnect
	// ideally, this cannot fail....
	// Even if it does, a server timeout should take the player out of
	// comission
	const pkt: [2]u8 = [_]u8{
		@intFromEnum(ops.DISCONNECT),
		id,
	};
	_ = server.write(&pkt)
		catch {};
}

test "new join" {
	try init();
	defer deinit();

	var others: [8]?rl.Vector2 = .{null} ** 8;
	try new_join(&others);

	std.debug.print("{}\n", .{id});
	for (others, 0..) |o, i|
		if (o) |_|
			std.debug.print("id: {} x: {} y: {}\n", .{i, o.?.x, o.?.y});
}

// send our player's position
pub fn send_pos(position: rl.Vector2) !void {
	var pkt: [2 + @sizeOf(rl.Vector2)]u8 =
		[_]u8{0} ** (2 + @sizeOf(rl.Vector2));

	pkt[0] = @intFromEnum(ops.POSITION);
	pkt[1] = id;  // player's id

	std.mem.copyForwards(
		u8,
		pkt[2..],
		std.mem.asBytes(&position),
	);
	_ = try server.write(&pkt);
}
