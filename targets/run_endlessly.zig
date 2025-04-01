const std = @import("std");

pub fn main() !void {
    var i: i32 = undefined;

    while (true) {
        i = 42;
        std.mem.doNotOptimizeAway(i);
    }
}
