const This = @This();
const std = @import("std");

id: u32,
name: []const u8,
dwarf_id: i32,
size: usize,
offset: usize,
type_: Type,
format: Format,

const AllRegisters: []This = undefined;

pub fn get_by_id(comptime id: u32) This {
    comptime {
        for (AllRegisters) |reg| {
            if (reg.id == id) {
                return reg;
            }
        }
        @compileLog("Register with id: {d} not found", .{id});
        @compileError("Failed to find register in AllRegisters");
    }
}

pub fn get_by_name(comptime name: []const u8) This {
    comptime {
        for (AllRegisters) |reg| {
            if (std.mem.eql(u8, reg.name, name)) {
                return reg;
            }
        }
        @compileLog("Register with name: {s} not found", .{name});
        @compileError("Failed to find register in AllRegisters");
    }
}
pub fn get_by_dwarf(comptime dwarf_id: i32) This {
    comptime {
        for (AllRegisters) |reg| {
            if (reg.dwarf_id == dwarf_id) {
                return reg;
            }
        }
        @compileLog("Register with dwarf_id: {d} not found", .{dwarf_id});
        @compileError("Failed to find register in AllRegisters");
    }
}

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
