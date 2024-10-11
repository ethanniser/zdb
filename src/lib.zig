const std = @import("std");
const Linenoise = @import("linenoise").Linenoise;
const posix = std.posix;
const linux = std.os.linux;
const PTRACE = linux.PTRACE;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const ProcessState = enum { stopped, running, exited, terminated };

const Process = struct {
    const Self = @This();
    pid: posix.pid_t,
    terminate_on_end: bool,
    state: ProcessState,

    pub fn launch(path: []const u8) !Self {
        const path_ptr: [*:0]const u8 = path.ptr;
        const argv = [_:null]?[*:0]const u8{path_ptr};
        const envp = [_:null]?[*:0]const u8{};
        const pid = try posix.fork();
        if (pid == 0) {
            // We're in the child process
            // Execute debugee
            try posix.ptrace(PTRACE.TRACEME, pid, 0, 0);
            const err = posix.execvpeZ(path_ptr, &argv, &envp);
            // Execution of this program ends here if successful
            return err;
        }

        const process = Self{ .pid = pid, .terminate_on_end = true, .state = .stopped };
        process.wait_on_signal();

        return process;
    }

    pub fn attach(pid: posix.pid_t) !Self {
        if (pid <= 0) {
            return error.InvalidPid;
        }
        try posix.ptrace(PTRACE.ATTACH, pid, 0, 0);

        const process = Self{ .pid = pid, .terminate_on_end = false, .state = .stopped };
        process.wait_on_signal();

        return process;
    }

    // todo: dont handle errors?
    pub fn deinit(self: *Self) !void {
        if (self.pid != 0) {
            if (self.state == .running) {
                try posix.kill(self.pid, posix.SIG.STOP);
                _ = posix.waitpid(self.pid, 0);
            }

            try posix.ptrace(PTRACE.DETACH, self.pid, 0, 0);
            try posix.kill(self.pid, posix.SIG.CONT);

            if (self.terminate_on_end) {
                try posix.kill(self.pid, posix.SIG.KILL);
                _ = posix.waitpid(self.pid, 0);
            }
        }
    }

    pub fn resume_execution(self: *Self) !void {
        try posix.ptrace(PTRACE.CONT, self.pid, 0, 0);
        self.state = .running;
    }

    const StopReason = struct { reason: ProcessState, code: u32 };

    pub fn wait_on_signal(self: *Self) StopReason {
        const result = posix.waitpid(self.pid, 0);

        const W = std.os.linux.W;
        if (W.IFEXITED(result.status)) {
            self.state = .exited;
            return .{ .reason = .exited, .status = W.EXITSTATUS(result.status) };
        } else if (W.IFSIGNALED(result.status)) {
            self.state = .terminated;
            return .{ .reason = .terminated, .status = W.TERMSIG(result.status) };
        } else if (W.IFSTOPPED(result.status)) {
            self.state = .stopped;
            return .{ .reason = .stopped, .status = W.STOPSIG(result.status) };
        }
    }
};
