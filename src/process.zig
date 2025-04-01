const std = @import("std");
const Linenoise = @import("linenoise").Linenoise;
const posix = std.posix;
const linux = std.os.linux;
const PTRACE = linux.PTRACE;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const CString = @cImport(@cInclude("string.h"));
const Pipe = @import("./pipe.zig");
const utils = @import("./utils.zig");

pub const State = enum { stopped, running, exited, terminated };

const Self = @This();
pid: posix.pid_t,
terminate_on_end: bool,
state: State,
is_attached: bool,

const LaunchOptions = struct { dont_attach: bool = false };

pub fn launch(path: [:0]const u8, options: LaunchOptions) !Self {
    var channel = try Pipe.init(.{ .close_on_exec = true });
    defer channel.deinit();

    const path_ptr: [*:0]const u8 = path.ptr;
    const argv = [_:null]?[*:0]const u8{path_ptr}; // todo: allow passing args
    const envp = [_:null]?[*:0]const u8{};
    const pid = try posix.fork();
    if (pid == 0) {
        // We're in the child process
        // If there is an error, send it to the parent process

        channel.close_read();
        // setup tracing
        if (!options.dont_attach) {
            posix.ptrace(PTRACE.TRACEME, 0, 0, 0) catch |err| {
                send_error_and_exit(&channel, err);
            };
        }
        // Execute debugee, if this is successful, execution of this program ends here
        const err = posix.execvpeZ(path_ptr, &argv, &envp);
        send_error_and_exit(&channel, err);
    }

    channel.close_write();
    var buffer: [256]u8 = undefined;
    const len = try channel.read(buffer[0..]);
    channel.close_read();

    if (len > 0) {
        // something is in the channel so there was an error
        const err = utils.bytesToError(buffer[0..2].*); // Take first 2 bytes
        std.log.debug("Failed to launch process: {s}", .{@errorName(err)});
        return err;
    }

    std.log.debug("Launched process {d}", .{pid});
    var process = Self{ .pid = pid, .terminate_on_end = true, .state = .stopped, .is_attached = !options.dont_attach };
    if (process.is_attached) {
        _ = process.wait_on_signal();
    }

    return process;
}

fn send_error_and_exit(channel: *const Pipe, err: anyerror) noreturn {
    var error_bytes = utils.errorToBytes(err);
    _ = channel.write(&error_bytes) catch |err2| {
        std.log.warn("Failed to send error message: {s}\n", .{@errorName(err2)});
    };
    std.process.exit(1);
}

pub fn attach(pid: posix.pid_t) !Self {
    if (pid <= 0) {
        return error.InvalidPid;
    }
    try posix.ptrace(PTRACE.ATTACH, pid, 0, 0);
    // todo: for some reason does not error when process does not exist?

    var process = Self{ .pid = pid, .terminate_on_end = false, .state = .stopped, .is_attached = true };
    _ = process.wait_on_signal();
    std.log.debug("Attached to process {d}", .{pid});

    return process;
}

pub fn deinit(self: *const Self) void {
    std.log.debug("Deiniting process {d}", .{self.pid});
    if (self.pid != 0) {
        if (self.is_attached) {
            // make sure we are stopped before we detach
            if (self.state == .running) {
                std.log.debug("Stopping process {d}", .{self.pid});
                posix.kill(self.pid, posix.SIG.STOP) catch |err| {
                    std.log.warn("Failed to stop process: {s}\n", .{@errorName(err)});
                };
                _ = posix.waitpid(self.pid, 0);
            }

            std.log.debug("Detaching from process {d}", .{self.pid});
            posix.ptrace(PTRACE.DETACH, self.pid, 0, 0) catch |err| {
                std.log.warn("Failed to detach ptrace: {s}\n", .{@errorName(err)});
            };

            std.log.debug("Continuing process {d}", .{self.pid});
            posix.kill(self.pid, posix.SIG.CONT) catch |err| {
                std.log.warn("Failed to continue process: {s}\n", .{@errorName(err)});
            };
        }

        if (self.terminate_on_end) {
            std.log.debug("Killing process {d}", .{self.pid});
            posix.kill(self.pid, posix.SIG.KILL) catch |err| {
                std.log.warn("Failed to kill process: {s}\n", .{@errorName(err)});
            };
            _ = posix.waitpid(self.pid, 0);
        }
    }
}

// `resume` is a keyword in zig, so we use `resume_execution` instead
pub fn resume_execution(self: *Self) !void {
    try posix.ptrace(PTRACE.CONT, self.pid, 0, 0);
    self.state = .running;
}

pub const StopReason = struct {
    reason: State,
    pid: posix.pid_t,
    code: u32,

    pub fn from_waitpid_result(result: posix.WaitPidResult) StopReason {
        const status = result.status;
        const pid = result.pid;
        const W = std.os.linux.W;
        if (W.IFEXITED(status)) {
            return .{ .reason = .exited, .code = W.EXITSTATUS(status), .pid = pid };
        } else if (W.IFSIGNALED(status)) {
            return .{ .reason = .terminated, .code = W.TERMSIG(status), .pid = pid };
        } else if (W.IFSTOPPED(status)) {
            return .{ .reason = .stopped, .code = W.STOPSIG(status), .pid = pid };
        } else {
            unreachable; // is this actually unreachable?
        }
    }
    pub fn to_string(self: *const StopReason, alloc: Allocator) ![]u8 {
        return try switch (self.reason) {
            .running => std.fmt.allocPrint(alloc, "process {d} is running", .{self.pid}),
            .exited => std.fmt.allocPrint(alloc, "process {d} exited with status {d}", .{ self.pid, self.code }),
            .terminated => std.fmt.allocPrint(alloc, "process {d} terminated with signal {d} - \"{s}\"", .{ self.pid, self.code, CString.strsignal(@intCast(self.code)) }),
            .stopped => std.fmt.allocPrint(alloc, "process {d} stopped with signal {d} - \"{s}\"", .{ self.pid, self.code, CString.strsignal(@intCast(self.code)) }),
        };
    }

    pub fn to_string_buffer(self: *const StopReason, buffer: []u8) ![]u8 {
        var fba = std.heap.FixedBufferAllocator.init(buffer);
        const alloc = fba.allocator();
        return self.to_string(alloc);
    }
};

pub fn wait_on_signal(self: *const Self) StopReason {
    const result = posix.waitpid(self.pid, 0);
    const stop_reason = StopReason.from_waitpid_result(result);

    // start debug stuff
    var buffer: [256]u8 = undefined;
    const s = stop_reason.to_string_buffer(buffer[0..]) catch |err| {
        std.log.warn("Failed to convert stop reason to fixed string: {s}\n", .{@errorName(err)});
        return stop_reason;
    };
    std.log.debug("wait_on_signal: {s}", .{s});
    // end debug stuff

    return stop_reason;
}

const t = std.testing;

fn process_exists(pid: posix.pid_t) bool {
    posix.kill(pid, 0) catch {
        return false;
    };
    return true;
}

fn get_process_status(alloc: Allocator, pid: posix.pid_t) !u8 {
    const path = try std.fmt.allocPrint(alloc, "/prod/{d}/stat", .{pid});
    defer alloc.free(path);

    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var reader = buf_reader.reader();

    const maybe_line = try reader.readUntilDelimiterOrEofAlloc(alloc, '\n', 2048);

    // line should look like: 1 (init) S 0 0 0 ...
    // we want to split on the last ")" and get the character right after it

    if (maybe_line) |line| {
        defer alloc.free(line);
        var iter = std.mem.splitBackwardsScalar(u8, line, ')');
        if (iter.next()) |part| {
            return part[1];
        } else {
            return error.ParsingStatError;
        }
    } else {
        return error.ParsingStatError;
    }
}

test "Process.launch success" {
    var process = try launch("echo", .{});
    defer process.deinit();

    try t.expect(process_exists(process.pid));
}

test "Process.launch no such program" {
    try t.expectError(error.FileNotFound, launch("fjdsklfdskl", .{}));
}

test "Process.attach success" {
    const alloc = t.allocator;
    const target = try launch("zig-out/bin/run-endlessly", .{ .dont_attach = true });
    _ = try attach(target.pid);
    try t.expect(try get_process_status(alloc, target.pid) == 't');
}

test "Process.attach invalid PID" {
    try t.expectError(error.InvalidPid, attach(0));
}
