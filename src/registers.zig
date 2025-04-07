const This = @This();
const CSysUser = @cImport(@cInclude("sys/user.h"));
const Process = @import("./process.zig");
const std = @import("std");
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

pub fn write(self: *const This, info: RegisterInfo, value: Value) !void {
    if (value.sizeOf() != info.size) {
        return error.UnexpectedSize;
    }

    var data_bytes = Bit.asBytes(&self.data);
    if (info.format == .uint) {
        const value_bytes = Bit.asBytes(value);
        std.mem.copyForwards(u8, data_bytes[info.offset..], value_bytes);
    }

    self.process.write_user_area(info.offset, Bit.fromBytes(u64, data_bytes[info.offset..]));
}

pub fn readByIdAs(self: *const This, comptime id: RegisterInfo.Id, comptime T: type) !T {
    const result = try self.read(RegisterInfo.getById(id));
    return switch (T) {
        u8 => switch (result) {
            .u8 => |v| v,
            else => error.TypeMismatch,
        },
        i8 => switch (result) {
            .i8 => |v| v,
            else => error.TypeMismatch,
        },
        u16 => switch (result) {
            .u16 => |v| v,
            else => error.TypeMismatch,
        },
        i16 => switch (result) {
            .i16 => |v| v,
            else => error.TypeMismatch,
        },
        u32 => switch (result) {
            .u32 => |v| v,
            else => error.TypeMismatch,
        },
        i32 => switch (result) {
            .i32 => |v| v,
            else => error.TypeMismatch,
        },
        u64 => switch (result) {
            .u64 => |v| v,
            else => error.TypeMismatch,
        },
        i64 => switch (result) {
            .i64 => |v| v,
            else => error.TypeMismatch,
        },
        f32 => switch (result) {
            .f32 => |v| v,
            else => error.TypeMismatch,
        },
        f64 => switch (result) {
            .f64 => |v| v,
            else => error.TypeMismatch,
        },
        f80 => switch (result) {
            .f80 => |v| v,
            else => error.TypeMismatch,
        },
        byte64 => switch (result) {
            .byte64 => |v| v,
            else => error.TypeMismatch,
        },
        byte128 => switch (result) {
            .byte128 => |v| v,
            else => error.TypeMismatch,
        },
        else => error.UnsupportedType,
    };
}

pub fn writeById(self: *const This, comptime id: RegisterInfo.Id, value: Value) !void {
    return self.write(RegisterInfo.getById(id), value);
}

pub const byte64 = [8]u8;
pub const byte128 = [16]u8;

pub const ValueType = enum {
    u8,
    i8,
    u16,
    i16,
    u32,
    i32,
    u64,
    i64,
    f32,
    f64,
    f80,
    byte64,
    byte128,
};

pub const Value = union(ValueType) {
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

    pub fn sizeOf(self: Value) u8 {
        return switch (self) {
            .u8 => @sizeOf(u8),
            .i8 => @sizeOf(i8),
            .u16 => @sizeOf(u16),
            .i16 => @sizeOf(i16),
            .u32 => @sizeOf(u32),
            .i32 => @sizeOf(i32),
            .u64 => @sizeOf(u64),
            .i64 => @sizeOf(i64),
            .f32 => @sizeOf(f32),
            .f64 => @sizeOf(f64),
            .f80 => @sizeOf(f80),
            .byte64 => @sizeOf(byte64),
            .byte128 => @sizeOf(byte128),
        };
    }
};
