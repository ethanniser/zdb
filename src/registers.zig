const This = @This();
const CSysUser = @cImport(@cInclude("sys/user.h"));
const Process = @import("./process.zig");
const RegisterInfo = @import("./register_info.zig");

user: CSysUser.user,
process: Process,

const Value = union(enum) {
    u8: u8,
    i8: i8,
    u16: u16,
    i16: i16,
    u32: u32,
    i32: i32,
    u64: u64,
    i64: i64,
    f32: f32, // float
    f64: f64, // double
    f80: f80, // long double
    byte64: [8]u8,
    byte128: [16]u8,
};
