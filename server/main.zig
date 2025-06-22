const std = @import("std");
const net = std.net;
const posix = std.posix;
const assert = std.debug.assert;

const ops = enum(u16) {
	DEFAULT = 0x100, // Should be unreachable
	HELLO = 0xff,
	DISCONNECT = 0x11,
	POS = 0x00,

	// check if the integer is a valid enum
	// Return the enum
	pub fn valid(in: @typeInfo(@This()).@"enum".tag_type) @This() {

		// loop through the enum and check if the integer is part of it
		inline for (@typeInfo(@This()).@"enum".fields) |field| {
			if (in == @intFromEnum(@field(@This(), field.name)))
				return @enumFromInt(in);
		}

		// if we have reached here, it's an invalid packet
		// Return the first entry. DEFAULT in this case
		return @field(@This(), @typeInfo(@This()).@"enum".fields[0].name);
	}
	// NOTE: I have tried to make this ^ function as generic as possible.
	// probably a bad idea
};

const addr = net.Address.initIp4(
	[4]u8{127,0,0,1},
	12271
);
var sock: posix.socket_t = undefined;

// This is supposed to be an rl.Vector2 for now, but it's kinda stupid linking
// raylib to the server. I mean, we're not rendering anything....
// So this will have to do. We can also add other things to this in the future
// to track player state and data and things like that
const pdata = struct {
	x: f32,
	y: f32,
};

var conns: [8]?net.Address = .{null} ** 8;
var players: [8]pdata = undefined;

pub fn main() !void {
	// create socket and bind
	sock = try posix.socket(
		posix.AF.INET,
		posix.SOCK.DGRAM,
		posix.IPPROTO.UDP,
	);
	defer posix.close(sock);
	errdefer posix.close(sock);

	try posix.bind(
		sock,
		&addr.any,
		addr.getOsSockLen()
	);

	// this buffer holds all our data
	var buf: [1024]u8 = [_]u8{0} ** 1024;
	var pkt: []u8 = undefined; // the packet

	var client: net.Address = undefined;
	var client_len: posix.socklen_t = @sizeOf(net.Address);

	hot: switch (ops.DEFAULT) {
		.DEFAULT => {
			const n = try posix.recvfrom(
				sock,
				&buf,
				0, // flags
				&client.any, // client addr destination
				&client_len, // client addr length
			);

			pkt = buf[0..n]; // fill packet

			std.debug.print("Recieved packet: {x}\n", .{pkt});

			// valid() will return the enum in pkt[0] if it's valid, otherwise
			// it'll return DEFAULT
			continue :hot ops.valid(pkt[0]);
		},
		.HELLO => {
			// TODO: assert to make sure the client exists before assigning

			// construct and send the hello packet
			const i = hello(client) catch continue :hot ops.DEFAULT;
			// TODO: do something if we fail to send the hello packet

			// set the client id
			conns[i] = client;
			continue :hot ops.DEFAULT;
		},
		.DISCONNECT => {
			assert(pkt[0] == @intFromEnum(ops.DISCONNECT));
			assert(pkt.len >= 2);

			const id = pkt[1];

			// before we close the connection, we should broadcast to everyone
			// that the client has disconnected
			const disconnect_pkt: [2]u8 = [_]u8{
				@intFromEnum(ops.DISCONNECT),
				id,
			};
			broadcast(id, &disconnect_pkt)
				catch {};
			// TODO: do something when broadcasting fails.

			conns[id] = null;

			// TODO: do some handshake to make sure any client cannot close any
			// other client, either maliciously or by mistake
			std.debug.print("Disconnected player w/ id: {}\n", .{id});
			continue :hot ops.DEFAULT;
		},
		.POS => {
			assert(pkt[0] == @intFromEnum(ops.POS));
			const id = pkt[1];

			// verify that the client has the same id
			if (conns[id] == null)
				continue :hot ops.DEFAULT
			else if (!conns[id].?.eql(client))
				continue :hot ops.DEFAULT;
			// TODO: someone might be intentionally trying to change another's
			// position. Anticheat will come later

			// Update the positions
			players[id] = std.mem.bytesToValue(
				pdata,
				pkt[2..],
			);

			std.debug.print("Updated position for id {}: x: {d:.2} y: {d:.2}\n", .{
				id, players[id].x, players[id].y
			});

			continue :hot ops.DEFAULT;
		},
	}
}

test "Hello world" {
	std.debug.print("Hello world\n", .{});
}

// send the client his hello packet
// return id
inline fn hello(client: net.Address) !u8 {

	var hello_pkt: [1024]u8 = [_]u8{0} ** 1024;
	hello_pkt[0] = @intCast(@intFromEnum(ops.HELLO)); // the op code

	var hello_pkt_index: u32 = 2; // the 1st byte is for the player's id.

	var id: u8 = 0;

	for (conns, 0..) |conn, i| {
		// player exists, add them to the pkt
		if (conn) |_| {
			hello_pkt[hello_pkt_index] = @intCast(i);
			std.mem.copyForwards(
				u8,
				hello_pkt[hello_pkt_index + 1..hello_pkt_index + @sizeOf(pdata) + 1],
				std.mem.asBytes(&players[i]),
			);
			hello_pkt_index += 1 + @sizeOf(pdata);
		}
		else id = @intCast(i);
		// get the last free id ^
	}

	hello_pkt[1] = id; // player id

	_ = try posix.sendto(
		sock,
		hello_pkt[0..hello_pkt_index],
		0,
		&client.any,
		client.getOsSockLen(),
	);

	return id;
}

test "hello packet" {
	const client = net.Address.initIp4(
		[4]u8{127,0,0,1},
		12271,
	);

	const id = try hello(client);
	std.debug.print("{}\n", .{id});
}

// broadcast packet to everyone except conns_id
inline fn broadcast(conns_id: u8, pkt: []const u8) !void {
	for (conns, 0..) |conn, i| {
		if (i == conns_id) continue;

		if (conn) |c|
			_ = try posix.sendto(
				sock,
				pkt,
				0,
				&c.any,
				c.getOsSockLen(),
			);
	}
}
