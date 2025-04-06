const std = @import("std");
const CSysUser = @cImport(@cInclude("sys/user.h"));

// The single source of truth for all registers
pub const registerDefinitions = [_]RegisterDefinition{
    // GPRs (64-bit)
    .gpr64("rax", 0, "rax"),
    .gpr64("rdx", 1, "rdx"),
    .gpr64("rcx", 2, "rcx"),
    .gpr64("rbx", 3, "rbx"),
    .gpr64("rsi", 4, "rsi"),
    .gpr64("rdi", 5, "rdi"),
    .gpr64("rbp", 6, "rbp"),
    .gpr64("rsp", 7, "rsp"),
    .gpr64("r8", 8, "r8"),
    .gpr64("r9", 9, "r9"),
    .gpr64("r10", 10, "r10"),
    .gpr64("r11", 11, "r11"),
    .gpr64("r12", 12, "r12"),
    .gpr64("r13", 13, "r13"),
    .gpr64("r14", 14, "r14"),
    .gpr64("r15", 15, "r15"),
    .gpr64("rip", 16, "rip"),
    .gpr64("eflags", 49, "eflags"),
    .gpr64("cs", 51, "cs"),
    .gpr64("fs", 54, "fs"),
    .gpr64("gs", 55, "gs"),
    .gpr64("ss", 52, "ss"),
    .gpr64("ds", 53, "ds"),
    .gpr64("es", 50, "es"),
    .gpr64("orig_rax", -1, "orig_rax"),

    // GPRs (32-bit)
    .gpr32("eax", "rax"),
    .gpr32("edx", "rdx"),
    .gpr32("ecx", "rcx"),
    .gpr32("ebx", "rbx"),
    .gpr32("esi", "rsi"),
    .gpr32("edi", "rdi"),
    .gpr32("ebp", "rbp"),
    .gpr32("esp", "rsp"),
    .gpr32("r8d", "r8"),
    .gpr32("r9d", "r9"),
    .gpr32("r10d", "r10"),
    .gpr32("r11d", "r11"),
    .gpr32("r12d", "r12"),
    .gpr32("r13d", "r13"),
    .gpr32("r14d", "r14"),
    .gpr32("r15d", "r15"),

    // GPRs (16-bit)
    .gpr16("ax", "rax"),
    .gpr16("dx", "rdx"),
    .gpr16("cx", "rcx"),
    .gpr16("bx", "rbx"),
    .gpr16("si", "rsi"),
    .gpr16("di", "rdi"),
    .gpr16("bp", "rbp"),
    .gpr16("sp", "rsp"),
    .gpr16("r8w", "r8"),
    .gpr16("r9w", "r9"),
    .gpr16("r10w", "r10"),
    .gpr16("r11w", "r11"),
    .gpr16("r12w", "r12"),
    .gpr16("r13w", "r13"),
    .gpr16("r14w", "r14"),
    .gpr16("r15w", "r15"),

    // GPRs (8-bit High)
    .gpr8h("ah", "rax"),
    .gpr8h("dh", "rdx"),
    .gpr8h("ch", "rcx"),
    .gpr8h("bh", "rbx"),

    // GPRs (8-bit Low)
    .gpr8l("al", "rax"),
    .gpr8l("dl", "rdx"),
    .gpr8l("cl", "rcx"),
    .gpr8l("bl", "rbx"),
    .gpr8l("sil", "rsi"),
    .gpr8l("dil", "rdi"),
    .gpr8l("bpl", "rbp"),
    .gpr8l("spl", "rsp"),
    .gpr8l("r8b", "r8"),
    .gpr8l("r9b", "r9"),
    .gpr8l("r10b", "r10"),
    .gpr8l("r11b", "r11"),
    .gpr8l("r12b", "r12"),
    .gpr8l("r13b", "r13"),
    .gpr8l("r14b", "r14"),
    .gpr8l("r15b", "r15"),

    // FPRs (Control/Status) - Sizes might need verification based on exact struct def
    .fpr("fcw", 65, @sizeOf(CSysUser.user_fpregs_struct.cwd), "cwd", .uint),
    .fpr("fsw", 66, @sizeOf(CSysUser.user_fpregs_struct.swd), "swd", .uint),
    .fpr("ftw", -1, @sizeOf(CSysUser.user_fpregs_struct.ftw), "ftw", .uint), // Often 8-bit tag word
    .fpr("fop", -1, @sizeOf(CSysUser.user_fpregs_struct.fop), "fop", .uint),
    .fpr("frip", -1, @sizeOf(CSysUser.user_fpregs_struct.rip), "rip", .uint),
    .fpr("frdp", -1, @sizeOf(CSysUser.user_fpregs_struct.rdp), "rdp", .uint),
    .fpr("mxcsr", 64, @sizeOf(CSysUser.user_fpregs_struct.mxcsr), "mxcsr", .uint),
    .fpr("mxcsrmask", -1, @sizeOf(CSysUser.user_fpregs_struct.mxcr_mask), "mxcr_mask", .uint),

    // FPRs (ST/MMX/XMM)
    .fp_st(0),
    .fp_st(1),
    .fp_st(2),
    .fp_st(3),
    .fp_st(4),
    .fp_st(5),
    .fp_st(6),
    .fp_st(7),
    .fp_mm(0),
    .fp_mm(1),
    .fp_mm(2),
    .fp_mm(3),
    .fp_mm(4),
    .fp_mm(5),
    .fp_mm(6),
    .fp_mm(7),
    .fp_xmm(0),
    .fp_xmm(1),
    .fp_xmm(2),
    .fp_xmm(3),
    .fp_xmm(4),
    .fp_xmm(5),
    .fp_xmm(6),
    .fp_xmm(7),
    .fp_xmm(8),
    .fp_xmm(9),
    .fp_xmm(10),
    .fp_xmm(11),
    .fp_xmm(12),
    .fp_xmm(13),
    .fp_xmm(14),
    .fp_xmm(15),

    // Debug Registers (DR)
    .dr(0),
    .dr(1),
    .dr(2),
    .dr(3),
    .dr(4),
    .dr(5),
    .dr(6),
    .dr(7),
};

const RegisterInfo = @import("./info.zig");
const RegisterType = RegisterInfo.Type;
const RegisterFormat = RegisterInfo.Format;

// Helper structure to hold the raw definition before offset calculation
pub const RegisterDefinition = struct {
    name: []const u8,
    dwarf_id: i32,
    size: usize,
    offset_calc: OffsetCalculation,
    reg_type: RegisterType,
    reg_format: RegisterFormat,

    // Enum to describe how to calculate the offset
    const OffsetCalculation = union(enum) {
        gpr: []const u8, // Field name within user_regs_struct
        sub_gpr: SubGprOffset,
        fpr: FprOffset,
        dr: u4, // Debug register number (0-7)

        const SubGprOffset = struct {
            super_reg_field: []const u8, // Field name of the 64-bit super register
            byte_offset: u1 = 0, // 0 for low part, 1 for high byte (AH, etc.)
        };
        const FprOffset = struct {
            base: enum { st_space, xmm_space, other },
            field_or_index: union(enum) {
                field_name: []const u8, // e.g., "cwd", "swd"
                index: u4, // e.g., 0-7 for st/mm, 0-15 for xmm
            },
        };
    };

    // Helper functions to create definitions
    fn gpr64(name: []const u8, dwarf: i32, field: []const u8) RegisterDefinition {
        return .{
            .name = name,
            .dwarf_id = dwarf,
            .size = 8,
            .offset_calc = .{ .gpr = field },
            .reg_type = .gpr,
            .reg_format = .uint,
        };
    }
    fn gpr32(name: []const u8, super_field: []const u8) RegisterDefinition {
        return .{
            .name = name,
            .dwarf_id = -1,
            .size = 4,
            .offset_calc = .{ .sub_gpr = .{ .super_reg_field = super_field } },
            .reg_type = .sub_gpr,
            .reg_format = .uint,
        };
    }
    fn gpr16(name: []const u8, super_field: []const u8) RegisterDefinition {
        return .{
            .name = name,
            .dwarf_id = -1,
            .size = 2,
            .offset_calc = .{ .sub_gpr = .{ .super_reg_field = super_field } },
            .reg_type = .sub_gpr,
            .reg_format = .uint,
        };
    }
    fn gpr8h(name: []const u8, super_field: []const u8) RegisterDefinition {
        return .{
            .name = name,
            .dwarf_id = -1,
            .size = 1,
            .offset_calc = .{ .sub_gpr = .{ .super_reg_field = super_field, .byte_offset = 1 } },
            .reg_type = .sub_gpr,
            .reg_format = .uint,
        };
    }
    fn gpr8l(name: []const u8, super_field: []const u8) RegisterDefinition {
        return .{
            .name = name,
            .dwarf_id = -1,
            .size = 1,
            .offset_calc = .{ .sub_gpr = .{ .super_reg_field = super_field } }, // byte_offset = 0 default
            .reg_type = .sub_gpr,
            .reg_format = .uint,
        };
    }
    fn fpr(name: []const u8, dwarf: i32, size: usize, field: []const u8, format: RegisterFormat) RegisterDefinition {
        return .{
            .name = name,
            .dwarf_id = dwarf,
            .size = size,
            .offset_calc = .{ .fpr = .{ .base = .other, .field_or_index = .{ .field_name = field } } },
            .reg_type = .fpr,
            .reg_format = format,
        };
    }
    fn fp_st(num: u4) RegisterDefinition {
        return .{
            .name = "st" ++ std.fmt.comptimePrint("{d}", .{num}),
            .dwarf_id = @intCast(33 + num),
            .size = 16, // sizeof long double on x86_64 linux is often 16
            .offset_calc = .{ .fpr = .{ .base = .st_space, .field_or_index = .{ .index = num } } },
            .reg_type = .fpr,
            .reg_format = .long_double,
        };
    }
    fn fp_mm(num: u4) RegisterDefinition {
        return .{
            .name = "mm" ++ std.fmt.comptimePrint("{d}", .{num}),
            .dwarf_id = @intCast(41 + num),
            .size = 8,
            .offset_calc = .{ .fpr = .{ .base = .st_space, .field_or_index = .{ .index = num } } },
            .reg_type = .fpr,
            .reg_format = .vector, // MMX registers
        };
    }
    fn fp_xmm(num: u4) RegisterDefinition {
        return .{
            .name = "xmm" ++ std.fmt.comptimePrint("{d}", .{num}),
            .dwarf_id = @intCast(17 + num),
            .size = 16, // XMM registers are 128-bit
            .offset_calc = .{ .fpr = .{ .base = .xmm_space, .field_or_index = .{ .index = num } } },
            .reg_type = .fpr,
            .reg_format = .vector,
        };
    }
    fn dr(num: u4) RegisterDefinition {
        return .{
            .name = "dr" ++ std.fmt.comptimePrint("{d}", .{num}),
            .dwarf_id = -1,
            .size = 8, // Debug registers are 64-bit on x86_64
            .offset_calc = .{ .dr = num },
            .reg_type = .dr,
            .reg_format = .uint,
        };
    }
};
