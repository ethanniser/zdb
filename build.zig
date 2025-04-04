const std = @import("std");

fn add_extra_target(
    name: [:0]const u8,
    b: *std.Build,
    step: *std.Build.Step,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !void {
    var buf: [100]u8 = undefined;
    const path = try std.fmt.bufPrint(
        &buf,
        "targets/{s}.zig",
        .{name},
    );

    const run_endlessly_exe = b.addExecutable(.{
        .name = name,
        .root_source_file = b.path(path),
        .target = target,
        .optimize = optimize,
    });
    step.dependOn(&run_endlessly_exe.step);
    b.installArtifact(run_endlessly_exe);
}

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {

    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const linenoise = b.dependency("linenoize", .{
        .target = target,
        .optimize = optimize,
    }).module("linenoise");

    const exe = b.addExecutable(.{
        .name = "zdb",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("linenoise", linenoise);
    exe.linkLibC();

    // Create a indetical executable but we **dont** install it
    const exe_check = b.addExecutable(.{
        .name = "zdb",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_check.root_module.addImport("linenoise", linenoise);
    exe_check.linkLibC();

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.

    const exe_unit_tests = b.addTest(.{
        .test_runner = .{ .path = b.path("test_runner.zig"), .mode = .simple },
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe_unit_tests);
    exe_unit_tests.root_module.addImport("linenoise", linenoise);
    exe_unit_tests.linkLibC();

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // isolated "targets" executables for testing
    const targets_step = b.step("targets", "Build executables in the targets/ directory");

    // Add additonal targets here:

    // ? should optimize be different?
    try add_extra_target("end_immediately", b, targets_step, target, optimize);
    try add_extra_target("run_endlessly", b, targets_step, target, optimize);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");

    // Since installArtifact adds the installation to the default install step,
    // and the test step doesn't explicitly depend on the install step,
    // we need to ensure the artifact is installed *before* the tests run.
    // A simple way is to make the test step depend on the install step.
    test_step.dependOn(targets_step);
    test_step.dependOn(b.getInstallStep());
    test_step.dependOn(&run_exe_unit_tests.step);

    const check = b.step("check", "Check compilation");
    check.dependOn(&exe_check.step);
    check.dependOn(&exe_unit_tests.step);
}
