const std = @import("std");
const Registers = @import("./registers.zig");
const byte64 = Registers.byte64;
const byte128 = Registers.byte128;

pub fn asBytes(from: anytype) []u8 {
    return std.mem.asBytes(from);
}

pub fn fromBytes(comptime T: type, bytes: []const u8) T {
    return std.mem.bytesToValue(T, bytes);
}

pub fn toByte64(from: anytype) byte64 {
    var bytes = std.mem.zeroes(byte64);
    std.mem.copyForwards(u8, &bytes, from);
    return bytes;
}

pub fn toByte128(from: anytype) byte128 {
    var bytes = std.mem.zeroes(byte128);
    std.mem.copyForwards(u8, &bytes, from);
    return bytes;
}
