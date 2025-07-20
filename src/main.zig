const std = @import("std");
const rl = @cImport({
   @cInclude("raylib.h");
   @cInclude("raymath.h");
   @cInclude("rlgl.h");
});
const level = @import("level.zig");
const network = @import("network.zig");

const window_width = 1440;
const window_height = 900;

const TILE = @import("constants.zig").TILE;
const NUM_PLAYERS = @import("constants.zig").NUM_PLAYERS;
const RADIUS = @import("constants.zig").RADIUS;
const GUN_RADIUS = @import("constants.zig").GUN_RADIUS;
const SPEED = 0.1;

var run_threads: bool = true;

// all coordinates are in world space
// center of the player rectangle
var player_pos: rl.Vector2 = rl.Vector2{.x = 0, .y = 0};
var player: rl.Rectangle = rl.Rectangle{
   .x = 0 - TILE / 2,
   .y = 0 - TILE / 2,
   .width = TILE,
   .height = TILE,
}; // the player rectangle
// the center of the gun
var gun_angle: f32 = 0;

// other player data
// consider moving these arrays to a separate file or reorganising them into a
// better data structure if we ever need to increase performance
var others: [NUM_PLAYERS]?rl.Vector2 = .{null} ** NUM_PLAYERS;
var others_rec: [NUM_PLAYERS]rl.Rectangle = [_]rl.Rectangle{
   rl.Rectangle{
      .width = TILE,
      .height = TILE,
   },
} ** NUM_PLAYERS;
// this ^ might be unnecessary
var others_angles: [NUM_PLAYERS]f32 = .{0} ** NUM_PLAYERS;

pub fn main() !void {
   // General purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        // can't try in defer as defer is executed after we return
        if (deinit_status == .leak) std.testing.expect(false)
         catch @panic("Memory leak");
    }

   // This needs to be set for making the window tiling on sway
   rl.SetConfigFlags(rl.FLAG_WINDOW_RESIZABLE);
   rl.SetTraceLogLevel(rl.LOG_ERROR);

   rl.InitWindow(window_width, window_height, "skrr");
   defer rl.CloseWindow();

   // connect to server
   try network.init();
   defer network.deinit();

   // get player position data and your id
   // only run when you newly join a server
   network.new_join(&others) catch {};
   defer network.disconnect();
   // TODO: make level loading also done with this ?
   // TODO: handle errors. It's fine to ignore them as others just becomes
   // null for now, but we shouldn't.

   // start the threads
   // NOTE: don't move this above network.new_join(), or you'll have nasty race
   // conditions to deal with
   _ = try std.Thread.spawn(.{}, physics, .{});
   defer run_threads = false;

   // These two threads write to the others array
   // both are blind writes. While logic would dictate that there can't be a
   // race condition, bugs and errors could make it possible

   // TODO: put some semaphore stuff to stop race conditions
   _ = try std.Thread.spawn(.{}, network.receiver, .{&others, &others_angles});
   _ = try std.Thread.spawn(.{}, network.tcp_receiver, .{&others});

   var camera: rl.Camera2D = rl.Camera2D{
      .target = player_pos,
      .offset = rl.Vector2{.x = window_width/2, .y = window_height/2},
      .rotation = 0,
      .zoom = 1, // TODO: maybe change this for resolution resizing stuff ? 
   };

   // yes, level loading
   const lvl = try level.load(allocator, "levels/level1");
   defer allocator.free(lvl);

   // load player start position
   player_pos = try level.start_position("levels/level1");
   player.x = player_pos.x - TILE / 2;
   player.y = player_pos.y - TILE / 2;

   while (!rl.WindowShouldClose()) {

      var collision_rect: rl.Rectangle = player;
      // movement
      if (rl.IsKeyDown(rl.KEY_A))
         collision_rect.x -= SPEED
      else if (rl.IsKeyDown(rl.KEY_D))
         collision_rect.x += SPEED
      else if (rl.IsKeyDown(rl.KEY_W))
         collision_rect.y -= SPEED
      else if (rl.IsKeyDown(rl.KEY_S))
         collision_rect.y += SPEED;

      // Check for collisions
      if (
         for (lvl) |l| {
            if (rl.CheckCollisionRecs(l, collision_rect))
               break false;
         } else true
      ) player = collision_rect;
      player_pos.x = player.x + TILE / 2;
      player_pos.y = player.y + TILE / 2;

      camera.target = player_pos;

      // gun stuff
      // writes to gun_angle
      // retuns the position of the gun circle
      const gun = update_gun();

      rl.BeginDrawing();
      defer rl.EndDrawing();
      rl.ClearBackground(rl.BLACK);
      {
         rl.BeginMode2D(camera);
         defer rl.EndMode2D();

         rl.DrawRectangleRec(player, rl.RED);
         rl.DrawCircleV(gun, GUN_RADIUS, rl.ORANGE);

         // draw level
         for (lvl) |l|
            rl.DrawRectangleRec(l, rl.RAYWHITE);

         // draw other players
         draw_others();
      }
      debug();
   }
}

test "hello world" {
   std.debug.print("Hello world\n", .{});
}

test "raylib test" {
   std.debug.print("x: {d:.0} y: {d:.0}  width: {d:.0} height: {d:.0}\n", player);
}

// While the function is called physics, it refers to anything that needs a
// fixed timing

// Network packets being sent also counts
fn physics() void {
   while (run_threads) : (
      std.time.sleep(std.time.ns_per_s)
   ){
      network.send_pos(player_pos, gun_angle);
   }
}

// should be called inside raylib BeginMode2D
// TODO: assert we are inside raylib BeginMode2D
inline fn draw_others() void {
   for (others,0..) |o,i| {
      if (o) |_| {

         // update the rectangle position. we can do this just before
         // drawing, it's fine. I'm not sure I'll keep others_rec around
         // anyways. The source of truth is always others: []?rl.Vector2
         others_rec[i].x = o.?.x - TILE / 2;
         others_rec[i].y = o.?.y - TILE / 2;

         rl.DrawRectangleRec(others_rec[i], rl.SKYBLUE);

         // draw their gun
         // NOTE: we need the vector version of this because rl.DrawCircle
         // takes integers instead of floats
         rl.DrawCircleV(
            rl.Vector2{
               .x = std.math.cos(others_angles[i]) * RADIUS + o.?.x,
               .y = std.math.sin(others_angles[i]) * RADIUS + o.?.y,
            },
            GUN_RADIUS,
            rl.SKYBLUE,
         );
      }
   }
}

// gun_angle is writen to
// returns the circle of the Gun's position.
inline fn update_gun() rl.Vector2 {
   const pos = rl.GetMousePosition();
   // we have to shift the origin to the center of the screen
   const shifted = rl.Vector2{
      .x = pos.x - window_width / 2,
      .y = pos.y - window_height / 2,
   };

   // get the angle in radians
   gun_angle = std.math.atan2(shifted.y, shifted.x);
   // We need to make this available to the the sender thread

   // Return the position of the center of the gun in world space
   return rl.Vector2{
      .x = std.math.cos(gun_angle) * RADIUS + player_pos.x,
      .y = std.math.sin(gun_angle) * RADIUS + player_pos.y,
   };
}

inline fn debug() void {
   const pos = rl.GetMousePosition();
   // we have to shift the origin to the center of the screen
   const shifted = rl.Vector2{
      .x = pos.x - window_width / 2,
      .y = pos.y - window_height / 2,
   };

   // get the angle in radians
   const angle = std.math.atan2(shifted.y, shifted.x);
   rl.DrawText(
      rl.TextFormat("Angle: %f", angle * 180 / std.math.pi),
      window_width / 2,
      window_height - 40,
      20,
      rl.GREEN
   );

   rl.DrawLineV(
      rl.Vector2{
         .x = window_width / 2,
         .y = window_height / 2,
      },
      pos,
      rl.GREEN
   );

   rl.DrawText(
      rl.TextFormat("FPS: %d", rl.GetFPS()),
      window_width / 2,
      40,
      20,
      rl.GREEN,
   );
}
