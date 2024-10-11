const std = @import("std");
const Linenoise = @import("linenoise").Linenoise;
const posix = std.posix;
const linux = std.os.linux;
const PTRACE = linux.PTRACE;

fn attach(args: [][:0]u8) !posix.pid_t {
    var pid: posix.pid_t = 0;
    // passing PID
    if (args.len == 3 and std.mem.eql(u8, args[1], "-p")) {
        pid = try std.fmt.parseInt(i32, args[2], 10);
        if (pid <= 0) {
            return error.InvalidPid;
        }
        try posix.ptrace(PTRACE.ATTACH, pid, 0, 0);
    }
    // passing program name
    else if (args.len == 2) {
        const program_path: [*:0]const u8 = args[1].ptr;
        const argv = [_:null]?[*:0]const u8{program_path};
        const envp = [_:null]?[*:0]const u8{};
        pid = try posix.fork();
        if (pid == 0) {
            // We're in the child process
            // Execute debugee
            try posix.ptrace(PTRACE.TRACEME, pid, 0, 0);
            const err = posix.execvpeZ(program_path, &argv, &envp);
            return err;
            // Execution of this program ends here if successful
        }
    } else {
        return error.InvalidArguments;
    }
    return pid;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            std.debug.print("Memory leak detected", .{});
        }
    }

    // const args = try std.process.argsAlloc(allocator);
    // defer std.process.argsFree(allocator, args);

    // const pid = try attach(args);
    // const options = 0;
    // const result = posix.waitpid(pid, options);
    // _ = result;

    var ln = Linenoise.init(allocator);
    defer ln.deinit();

    while (try ln.linenoise("hello> ")) |input| {
        defer allocator.free(input);
        std.debug.print("input: {s}\n", .{input});
        try ln.history.add(input);
    }
}

// test "simple test" {
//     var list = std.ArrayList(i32).init(std.testing.allocator);
//     defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
//     try list.append(42);
//     try std.testing.expectEqual(@as(i32, 42), list.pop());
// }
