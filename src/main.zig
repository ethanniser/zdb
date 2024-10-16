const std = @import("std");
const Linenoise = @import("linenoise").Linenoise;
const posix = std.posix;
const linux = std.os.linux;
const PTRACE = linux.PTRACE;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const lib = @import("lib.zig");
const Process = lib.Process;

const stdout = std.io.getStdOut().writer();

fn attach(args: [][:0]u8) !Process {
    // passing PID
    if (args.len == 3 and std.mem.eql(u8, args[1], "-p")) {
        const pid = try std.fmt.parseInt(i32, args[2], 10);
        return Process.attach(pid);
    }
    // passing program name
    else if (args.len == 2) {
        return Process.launch(args[1]);
    } else {
        return error.InvalidArguments;
    }
}

fn handle_command(process: *Process, input: []const u8) !void {
    assert(input.len != 0);
    var parts = std.mem.splitBackwardsSequence(u8, input, " ");
    const command = parts.first();

    if (std.mem.startsWith(u8, "continue", command)) {
        try process.resume_execution();
        const reason = try process.wait_on_signal();
        try print_stop_reason(process, reason);
    } else {
        return error.UnknownCommand;
    }
}

fn print_stop_reason(process: *Process, reason: Process.StopReason) !void {
    try stdout.print("Process {d} ", .{process.pid});
    switch (reason.reason) {
        .exited => {
            try stdout.print("exited with status {d}\n", .{reason.code});
        },
        .terminated => {
            try stdout.print("terminated with signal {d}\n", .{reason.code}); // todo: find zig sigabbrev_np or sys_siglist
        },
        .stopped => {
            try stdout.print("stopped with signal {d}\n", .{reason.code}); // todo: find zig sigabbrev_np or sys_siglist
        },
        else => {},
    }
    try stdout.print("\n", .{});
}

pub fn main_loop(allocator: Allocator, process: *Process, ln: *Linenoise) !void {
    while (try ln.linenoise("zdb> ")) |input| {
        defer allocator.free(input);

        var line: []const u8 = "";
        if (input.len == 0) {
            if (ln.history.hist.items.len > 0) {
                line = ln.history.hist.items[ln.history.hist.items.len - 1];
            }
        } else {
            line = input;
            try ln.history.add(input);
        }

        if (line.len != 0) {
            handle_command(process, line) catch |err| {
                std.debug.print("An error occured: {s}\n", .{@errorName(err)});
            };
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            std.debug.print("Memory leak detected\n", .{});
        }
    }

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    var ln = Linenoise.init(allocator);
    defer ln.deinit();

    var process = attach(args) catch |err| {
        std.debug.print("An error occured: {s}\n", .{@errorName(err)});
        return err;
    };

    main_loop(allocator, &process, &ln) catch |err| {
        std.debug.print("An error occured: {s}\n", .{@errorName(err)});
        return err;
    };
}
