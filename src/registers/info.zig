const This = @This();
const std = @import("std");
const CSysUser = @cImport(@cInclude("sys/user.h"));
const definitions = @import("./define.zig").registerDefinitions;

id: Id,
name: []const u8,
dwarf_id: ?u32,
size: usize,
offset: usize,
type: Type,
format: Format,

pub fn getById(comptime id: Id) This {
    comptime {
        for (AllRegisters) |reg| {
            if (reg.id == id) {
                return reg;
            }
        }
        @compileError(std.fmt.comptimePrint("Register with id: {d} not found", .{id}));
    }
}

pub fn getByName(comptime name: []const u8) This {
    comptime {
        for (AllRegisters) |reg| {
            if (std.mem.eql(u8, reg.name, name)) {
                return reg;
            }
        }
        @compileError(std.fmt.comptimePrint("Register with name: {s} not found", .{name}));
    }
}
pub fn getByDwarf(comptime dwarf_id: u32) This {
    comptime {
        for (AllRegisters) |reg| {
            if (reg.dwarf_id == dwarf_id) {
                return &reg;
            }
        }
        @compileError(std.fmt.comptimePrint("Register with dwarf_id: {d} not found", .{dwarf_id}));
    }
}

pub const Type = enum {
    gpr,
    sub_gpr,
    fpr,
    dr,
};

pub const Format = enum {
    uint,
    double_float,
    long_double,
    vector,
};

pub const Id = blk: {
    const len = definitions.len;
    var fields: [len]std.builtin.Type.EnumField = undefined;

    for (0..len) |i| {
        fields[i] = .{
            .name = definitions[i].name ++ [_:0]u8{0},
            .value = i,
        };
    }

    break :blk @Type(.{ .@"enum" = .{
        .decls = &.{},
        .tag_type = u16,
        .fields = &fields,
        .is_exhaustive = true,
    } });
};

const AllRegisters: [definitions.len]This = blk: {
    const len = definitions.len;
    var infos: [len]This = undefined;

    const base_gpr_offset = @offsetOf(CSysUser.user, "regs");
    const base_fpr_offset = @offsetOf(CSysUser.user, "i387");
    const base_dr_offset = @offsetOf(CSysUser.user, "u_debugreg");

    for (definitions, 0..) |def, i| {
        const final_offset = switch (def.offset_calc) {
            .gpr => |field_name| base_gpr_offset + @offsetOf(CSysUser.user_regs_struct, field_name),
            .sub_gpr => |sub_info| base_gpr_offset + @offsetOf(CSysUser.user_regs_struct, sub_info.super_reg_field) + sub_info.byte_offset,
            .fpr => |fpr_info| switch (fpr_info) {
                // .st_space => base_fpr_offset + @offsetOf(CSysUser.user_fpregs_struct, "st_space") + fpr_info.field_or_index.index * 16,
                // .xmm_space => base_fpr_offset + @offsetOf(CSysUser.user_fpregs_struct, "xmm_space") + fpr_info.field_or_index.index * 16,
                .field => |field_name| base_fpr_offset + @offsetOf(CSysUser.user_fpregs_struct, field_name),
            },
            .dr => |dr_num| base_dr_offset + dr_num * @sizeOf(c_longlong),
        };

        const final_size = switch (def.size) {
            .raw => |val| val,
            .fp_reg => |name| blk2: {
                const fpregs_typeinfo = @typeInfo(CSysUser.user_fpregs_struct);
                for (fpregs_typeinfo.@"struct".fields) |field| {
                    if (std.mem.eql(u8, field.name, name)) {
                        break :blk2 @sizeOf(field.type);
                    }
                }
                @compileError(std.fmt.comptimePrint("Field {s} not found in user_fpregs_struct", .{name}));
            },
        };

        infos[i] = .{
            .id = @enumFromInt(i), // this should be ok both `Id` and this loop in the same order?
            .name = def.name,
            .dwarf_id = def.dwarf_id,
            .size = final_size,
            .offset = final_offset,
            .type = def.reg_type,
            .format = def.reg_format,
        };
    }

    break :blk infos;
};

test "gpr 64 lookup" {
    const rax_info = comptime getById(.rax);
    try std.testing.expectEqual(.rax, rax_info.id);
    try std.testing.expectEqualStrings("rax", rax_info.name);
    try std.testing.expectEqual(@as(?u32, 0), rax_info.dwarf_id);
    try std.testing.expectEqual(@as(usize, 8), rax_info.size);
    try std.testing.expectEqual(rax_info.offset, @offsetOf(CSysUser.user, "regs") + @offsetOf(CSysUser.user_regs_struct, "rax"));
    try std.testing.expectEqual(Type.gpr, rax_info.type);
    try std.testing.expectEqual(Format.uint, rax_info.format);
}

test "gpr 32 lookup" {
    const eax_info = comptime getById(.eax);
    try std.testing.expectEqual(.eax, eax_info.id);
    try std.testing.expectEqualStrings("eax", eax_info.name);
    try std.testing.expectEqual(@as(?u32, null), eax_info.dwarf_id);
    try std.testing.expectEqual(@as(usize, 4), eax_info.size);
    try std.testing.expectEqual(eax_info.offset, @offsetOf(CSysUser.user, "regs") + @offsetOf(CSysUser.user_regs_struct, "rax"));
    try std.testing.expectEqual(Type.sub_gpr, eax_info.type);
    try std.testing.expectEqual(Format.uint, eax_info.format);
}

test "gpr 16 lookup" {
    const ax_info = comptime getById(.ax);
    try std.testing.expectEqual(.ax, ax_info.id);
    try std.testing.expectEqualStrings("ax", ax_info.name);
    try std.testing.expectEqual(@as(?u32, null), ax_info.dwarf_id);
    try std.testing.expectEqual(@as(usize, 2), ax_info.size);
    try std.testing.expectEqual(ax_info.offset, @offsetOf(CSysUser.user, "regs") + @offsetOf(CSysUser.user_regs_struct, "rax"));
    try std.testing.expectEqual(Type.sub_gpr, ax_info.type);
    try std.testing.expectEqual(Format.uint, ax_info.format);
}

test "gpr 8 high lookup" {
    const ah_info = comptime getById(.ah);
    try std.testing.expectEqual(.ah, ah_info.id);
    try std.testing.expectEqualStrings("ah", ah_info.name);
    try std.testing.expectEqual(@as(?u32, null), ah_info.dwarf_id);
    try std.testing.expectEqual(@as(usize, 1), ah_info.size);
    try std.testing.expectEqual(ah_info.offset, @offsetOf(CSysUser.user, "regs") + @offsetOf(CSysUser.user_regs_struct, "rax") + 1);
    try std.testing.expectEqual(Type.sub_gpr, ah_info.type);
    try std.testing.expectEqual(Format.uint, ah_info.format);
}

test "gpr 8 low lookup" {
    const al_info = comptime getById(.al);
    try std.testing.expectEqual(.al, al_info.id);
    try std.testing.expectEqualStrings("al", al_info.name);
    try std.testing.expectEqual(@as(?u32, null), al_info.dwarf_id);
    try std.testing.expectEqual(@as(usize, 1), al_info.size);
    try std.testing.expectEqual(al_info.offset, @offsetOf(CSysUser.user, "regs") + @offsetOf(CSysUser.user_regs_struct, "rax"));
    try std.testing.expectEqual(Type.sub_gpr, al_info.type);
    try std.testing.expectEqual(Format.uint, al_info.format);
}

test "fpr lookup" {
    const fcw_info = comptime getById(.fcw);
    try std.testing.expectEqual(.fcw, fcw_info.id);
    try std.testing.expectEqualStrings("fcw", fcw_info.name);
    try std.testing.expectEqual(@as(?u32, 65), fcw_info.dwarf_id);
    try std.testing.expectEqual(@as(usize, 2), fcw_info.size);
    try std.testing.expectEqual(fcw_info.offset, @offsetOf(CSysUser.user, "i387") + @offsetOf(CSysUser.user_fpregs_struct, "cwd"));
    try std.testing.expectEqual(Type.fpr, fcw_info.type);
    try std.testing.expectEqual(Format.uint, fcw_info.format);
}

test "debug lookup" {
    const dr1_info = comptime getById(.dr1);
    try std.testing.expectEqual(.dr1, dr1_info.id);
    try std.testing.expectEqualStrings("dr1", dr1_info.name);
    try std.testing.expectEqual(@as(?u32, null), dr1_info.dwarf_id);
    try std.testing.expectEqual(@as(usize, 8), dr1_info.size);
    try std.testing.expectEqual(dr1_info.offset, @offsetOf(CSysUser.user, "u_debugreg") + @sizeOf(c_longlong) * 1);
    try std.testing.expectEqual(Type.dr, dr1_info.type);
    try std.testing.expectEqual(Format.uint, dr1_info.format);
}
