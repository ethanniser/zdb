const CUser = @cImport(@cInclude("sys/user.h"));
const Process = @import("./process.zig");

user: CUser.user,
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

// comptime const AllRegisters: Info[] = undefined;

const Info = struct {
    const Type = enum {
        gpr,
        sub_gpr,
        fpr,
        dr,
    };

    const Format = enum {
        uint,
        double_float,
        long_double,
        vector,
    };

    id: u32,
    name: []const u8,
    dwarf_id: i32,
    size: usize,
    offset: usize,
    type_: Type,
    format: Format,
};
