const This = @This();
const CSysUser = @cImport(@cInclude("sys/user.h"));
const Process = @import("./process.zig");
const RegisterInfo = @import("./registers/info.zig");
const Bit = @import("./bit.zig");

data: CSysUser.user,
process: *Process,

pub fn init(process: *Process) This {
    return .{
        .data = undefined,
        .process = process,
    };
}

pub fn read(self: *const This, info: RegisterInfo) !Value {
    const bytes = Bit.asBytes(&self.data);
    if (info.format == .uint) {
        switch (info.size) {
            1 => return .{ .u8 = bytes[info.offset] },
            2 => return .{ .u16 = Bit.fromBytes(u16, bytes[info.offset..]) },
            4 => return .{ .u32 = Bit.fromBytes(u32, bytes[info.offset..]) },
            8 => return .{ .u64 = Bit.fromBytes(u64, bytes[info.offset..]) },
            16 => return .{ .u128 = Bit.fromBytes(u128, bytes[info.offset..]) },
            else => error.UnexpectedSize,
        }
    } else if (info.format == .double_float) {
        return .{ .f64 = Bit.fromBytes(f64, bytes[info.offset..]) };
    } else if (info.format == .long_double) {
        return .{ .f80 = Bit.fromBytes(f80, bytes[info.offset..]) };
    } else if (info.format == .vector and info.size == 8) {
        return .{ .byte64 = Bit.fromBytes(byte64, bytes[info.offset..]) };
    } else {
        return .{ .byte128 = Bit.fromBytes(byte128, bytes[info.offset..]) };
    }
}

pub fn write(self: *const This, reg: RegisterInfo, value: Value) void {
    @compileError("not implemented");
}

pub fn readByIdAs(self: *const This, id: RegisterInfo.Id, comptime T: type) T {
    @compileError("not implemented");
}

pub fn writeById(self: *const This, id: RegisterInfo.Id, value: Value) void {
    @compileError("not implemented");
}

pub const byte64 = [8]u8;
pub const byte128 = [16]u8;

pub const Value = union(enum) {
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
    byte64: byte64,
    byte128: byte128,
};
