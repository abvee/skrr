const std = @import("std");

pub fn build(b: *std.Build) void {

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

	// build
    const exe = b.addExecutable(.{
        .name = "skrr",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

	exe.addIncludePath(b.path("raylib/include"));
	exe.addObjectFile(b.path("raylib/lib/libraylib.a"));
	exe.linkLibC(); // needed for raylib
    b.installArtifact(exe);

	// build run
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
