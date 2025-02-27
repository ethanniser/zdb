const std = @import("std");
const Linenoise = @import("linenoise").Linenoise;
const posix = std.posix;
const linux = std.os.linux;
const PTRACE = linux.PTRACE;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const CString = @cImport(@cInclude("string.h"));

pub const ProcessState = enum { stopped, running, exited, terminated };

pub const Process = struct {
    const Self = @This();
    pid: posix.pid_t,
    terminate_on_end: bool,
    state: ProcessState,

    pub fn launch(path: [:0]const u8) !Self {
        const path_ptr: [*:0]const u8 = path.ptr;
        const argv = [_:null]?[*:0]const u8{path_ptr}; // todo: allow passing args
        const envp = [_:null]?[*:0]const u8{};
        const pid = try posix.fork();
        if (pid == 0) {
            // We're in the child process

            // * if there are any errors in this section, propogate them back to the parent via exit code

            // setup tracing
            posix.ptrace(PTRACE.TRACEME, 0, 0, 0) catch |err| {
                posix.exit(@intCast(@intFromError(err)));
                unreachable;
            };
            // Execute debugee, if this is successful, execution of this program ends here
            const err = posix.execvpeZ(path_ptr, &argv, &envp);
            posix.exit(@intCast(@intFromError(err)));
            unreachable;
        }

        std.log.debug("Launched process {d}", .{pid});
        var process = Self{ .pid = pid, .terminate_on_end = true, .state = .stopped };
        const stop_reason = process.wait_on_signal();
        // if the process has already exited something has gone wrong that is not from the program executing (we are expecting it to be stopped)
        // in this case inspect the exit code to reconstruct the error
        if (stop_reason.reason == .exited) {
            const err = @errorFromInt(@as(u16, @truncate(stop_reason.code)));
            std.log.debug("Failed to launch process: {s}", .{@errorName(err)});
            return err;
        }

        return process;
    }

    pub fn attach(pid: posix.pid_t) !Self {
        if (pid <= 0) {
            return error.InvalidPid;
        }
        try posix.ptrace(PTRACE.ATTACH, pid, 0, 0);
        // todo: for some reason does not error when process does not exist?

        var process = Self{ .pid = pid, .terminate_on_end = false, .state = .stopped };
        _ = process.wait_on_signal();
        std.log.debug("Attached to process {d}", .{pid});

        return process;
    }

    pub fn deinit(self: *Self) void {
        std.log.debug("Deiniting process {d}", .{self.pid});
        if (self.pid != 0) {
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
        reason: ProcessState,
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
        pub fn to_string(self: StopReason, alloc: Allocator) ![]u8 {
            return try switch (self.reason) {
                .running => std.fmt.allocPrint(alloc, "process {d} is running", .{self.pid}),
                .exited => std.fmt.allocPrint(alloc, "process {d} exited with status {d}", .{ self.pid, self.code }),
                .terminated => std.fmt.allocPrint(alloc, "process {d} terminated with signal {d} - \"{s}\"", .{ self.pid, self.code, CString.strsignal(@intCast(self.code)) }),
                .stopped => std.fmt.allocPrint(alloc, "process {d} stopped with signal {d} - \"{s}\"", .{ self.pid, self.code, CString.strsignal(@intCast(self.code)) }),
            };
        }

        pub fn to_string_buffer(self: StopReason, buffer: []u8) ![]u8 {
            var fba = std.heap.FixedBufferAllocator.init(buffer);
            const alloc = fba.allocator();
            return to_string(self, alloc);
        }
    };

    pub fn wait_on_signal(self: *Self) StopReason {
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
};

const t = std.testing;

fn process_exists(pid: posix.pid_t) bool {
    posix.kill(pid, 0) catch {
        return false;
    };
    return true;
}

test "Process.launch success" {
    var process = try Process.launch("echo");
    defer process.deinit();

    try t.expect(process_exists(process.pid));
}

test "Process.launch no such program" {
    try t.expectError(error.FileNotFound, Process.launch("fjdsklfdskl"));
}
