const This = @This();
const std = @import("std");
const CSysUser = @cImport(@cInclude("sys/user.h"));
const definitons = @import("./define.zig").registerDefinitions;

id: Id,
name: []const u8,
dwarf_id: ?u32,
size: usize,
type: Type,
format: Format,

pub fn getById(comptime id: Id) *const This {
    comptime {
        for (AllRegisters) |reg| {
            if (reg.id == id) {
                return reg;
            }
        }
        @compileError(std.fmt.comptimePrint("Register with id: {d} not found", .{id}));
    }
}

pub fn getByName(comptime name: []const u8) *const This {
    comptime {
        for (AllRegisters) |reg| {
            if (std.mem.eql(u8, reg.name, name)) {
                return reg;
            }
        }
        @compileError(std.fmt.comptimePrint("Register with name: {s} not found", .{name}));
    }
}
pub fn getByDwarf(comptime dwarf_id: i32) *const This {
    comptime {
        for (AllRegisters) |reg| {
            if (reg.dwarf_id == dwarf_id) {
                return reg;
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
    const len = definitons.len;
    var fields: [len]std.builtin.Type.EnumField = undefined;

    for (0..len) |i| {
        fields[i] = .{
            .name = definitons[i].name,
            .value = i,
        };
    }

    break :blk @Type(.{ .@"enum" = .{ .decls = &.{}, .tag_type = u16, .fields = &fields, .is_exhaustive = true, .layout = .Auto } });
};

const AllRegisters: []This = blk: {
    const len = definitons.len;
    var infos: [len]This = undefined;

    const base_gpr_offset = @offsetOf(CSysUser.user, "regs");
    const base_fpr_offset = @offsetOf(CSysUser.user, "i387");
    const base_dr_offset = @offsetOf(CSysUser.user, "u_debugreg");

    for (definitons, 0..) |def, i| {
        const final_offset = switch (def.offset_calc) {
            .gpr => |field_name| base_gpr_offset + @offsetOf(CSysUser.user_regs_struct, field_name),
            .sub_gpr => |sub_info| base_gpr_offset + @offsetOf(CSysUser.user_regs_struct, sub_info.super_reg_field) + sub_info.byte_offset,
            .fpr => |fpr_info| switch (fpr_info.base) {
                .st_space => base_fpr_offset + @offsetOf(CSysUser.user_fpregs_struct, "st_space") + fpr_info.field_or_index.index * 16,
                .xmm_space => base_fpr_offset + @offsetOf(CSysUser.user_fpregs_struct, "xmm_space") + fpr_info.field_or_index.index * 16,
                .other => base_fpr_offset + @offsetOf(CSysUser.user_fpregs_struct, fpr_info.field_or_index.field_name),
            },
            .dr => |dr_num| base_dr_offset + dr_num * 8,
        };

        // We use @intToEnum for id, assuming the enum values are 0..N-1
        infos[i] = .{
            .id = @enumFromInt(i), // this should be ok because they both loop in the same order?
            .name = def.name,
            .dwarf_id = def.dwarf_id,
            .size = def.size,
            .offset = final_offset,
            .type = def.reg_type,
            .format = def.reg_format,
        };
    }

    // Return the generated array
    break :blk infos;
};

test "lookup registers" {
    const rax_info = getById(.rax);
    try std.testing.expectEqualStrings("rax", rax_info.name);
    try std.testing.expectEqual(@as(usize, 8), rax_info.size);
    try std.testing.expectEqual(@as(i32, 0), rax_info.dwarf_id);
    try std.testing.expectEqual(Type.gpr, rax_info.type);

    const al_info = getByName("al") orelse unreachable;
    try std.testing.expectEqual(Id.al, al_info.id);
    try std.testing.expectEqual(@as(usize, 1), al_info.size);
    try std.testing.expectEqual(@as(i32, -1), al_info.dwarf_id);
    try std.testing.expectEqual(Type.sub_gpr, al_info.type);
    // Check offset relative to rax
    try std.testing.expectEqual(rax_info.offset, al_info.offset);

    const ah_info = getByName("ah") orelse unreachable;
    try std.testing.expectEqual(Id.ah, ah_info.id);
    try std.testing.expectEqual(@as(usize, 1), ah_info.size);
    // Check offset relative to rax
    try std.testing.expectEqual(rax_info.offset + 1, ah_info.offset);

    const st0_info = getByDwarf(33) orelse unreachable; // ST0 has dwarf_id 33
    try std.testing.expectEqualStrings("st0", st0_info.name);
    try std.testing.expectEqual(Id.st0, st0_info.id);
    try std.testing.expectEqual(@as(usize, 16), st0_info.size);
    try std.testing.expectEqual(Format.long_double, st0_info.format);

    const xmm3_info = getById(.xmm3);
    try std.testing.expectEqualStrings("xmm3", xmm3_info.name);
    try std.testing.expectEqual(@as(i32, 17 + 3), xmm3_info.dwarf_id);

    // Test non-existent lookup
    try std.testing.expect(getByName("nonexistent") == null);
    try std.testing.expect(getByDwarf(9999) == null);
    try std.testing.expect(getByDwarf(-5) == null);
}
