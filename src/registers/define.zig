const std = @import("std");
const CSysUser = @cImport(@cInclude("sys/user.h"));

// The single source of truth for all registers
pub const registerDefinitions = [_]RegisterDefinition{
    // GPRs (64-bit)
    .gpr_64("rax", 0),
    .gpr_64("rdx", 1),
    .gpr_64("rcx", 2),
    .gpr_64("rbx", 3),
    .gpr_64("rsi", 4),
    .gpr_64("rdi", 5),
    .gpr_64("rbp", 6),
    .gpr_64("rsp", 7),
    .gpr_64("r8", 8),
    .gpr_64("r9", 9),
    .gpr_64("r10", 10),
    .gpr_64("r11", 11),
    .gpr_64("r12", 12),
    .gpr_64("r13", 13),
    .gpr_64("r14", 14),
    .gpr_64("r15", 15),
    .gpr_64("rip", 16),
    .gpr_64("eflags", 49),
    .gpr_64("cs", 51),
    .gpr_64("fs", 54),
    .gpr_64("gs", 55),
    .gpr_64("ss", 52),
    .gpr_64("ds", 53),
    .gpr_64("es", 50),
    .gpr_64("orig_rax", null),

    // // GPRs (32-bit)
    .gpr_32("eax", "rax"),
    .gpr_32("edx", "rdx"),
    .gpr_32("ecx", "rcx"),
    .gpr_32("ebx", "rbx"),
    .gpr_32("esi", "rsi"),
    .gpr_32("edi", "rdi"),
    .gpr_32("ebp", "rbp"),
    .gpr_32("esp", "rsp"),
    .gpr_32("r8d", "r8"),
    .gpr_32("r9d", "r9"),
    .gpr_32("r10d", "r10"),
    .gpr_32("r11d", "r11"),
    .gpr_32("r12d", "r12"),
    .gpr_32("r13d", "r13"),
    .gpr_32("r14d", "r14"),
    .gpr_32("r15d", "r15"),

    // GPRs (16-bit)
    .gpr_16("ax", "rax"),
    .gpr_16("dx", "rdx"),
    .gpr_16("cx", "rcx"),
    .gpr_16("bx", "rbx"),
    .gpr_16("si", "rsi"),
    .gpr_16("di", "rdi"),
    .gpr_16("bp", "rbp"),
    .gpr_16("sp", "rsp"),
    .gpr_16("r8w", "r8"),
    .gpr_16("r9w", "r9"),
    .gpr_16("r10w", "r10"),
    .gpr_16("r11w", "r11"),
    .gpr_16("r12w", "r12"),
    .gpr_16("r13w", "r13"),
    .gpr_16("r14w", "r14"),
    .gpr_16("r15w", "r15"),

    // GPRs (8-bit High)
    .gpr_8h("ah", "rax"),
    .gpr_8h("dh", "rdx"),
    .gpr_8h("ch", "rcx"),
    .gpr_8h("bh", "rbx"),

    // GPRs (8-bit Low)
    .gpr_8l("al", "rax"),
    .gpr_8l("dl", "rdx"),
    .gpr_8l("cl", "rcx"),
    .gpr_8l("bl", "rbx"),
    .gpr_8l("sil", "rsi"),
    .gpr_8l("dil", "rdi"),
    .gpr_8l("bpl", "rbp"),
    .gpr_8l("spl", "rsp"),
    .gpr_8l("r8b", "r8"),
    .gpr_8l("r9b", "r9"),
    .gpr_8l("r10b", "r10"),
    .gpr_8l("r11b", "r11"),
    .gpr_8l("r12b", "r12"),
    .gpr_8l("r13b", "r13"),
    .gpr_8l("r14b", "r14"),
    .gpr_8l("r15b", "r15"),

    // FPRs (Control/Status)
    .fpr("fcw", 65, "cwd"),
    .fpr("fsw", 66, "swd"),
    .fpr("ftw", null, "ftw"),
    .fpr("fop", null, "fop"),
    .fpr("frip", null, "rip"),
    .fpr("frdp", null, "rdp"),
    .fpr("mxcsr", 64, "mxcsr"),
    .fpr("mxcsrmask", null, "mxcr_mask"),

    // // FPRs (ST/MMX/XMM)
    // .fp_st(0),
    // .fp_st(1),
    // .fp_st(2),
    // .fp_st(3),
    // .fp_st(4),
    // .fp_st(5),
    // .fp_st(6),
    // .fp_st(7),

    // .fp_mm(0),
    // .fp_mm(1),
    // .fp_mm(2),
    // .fp_mm(3),
    // .fp_mm(4),
    // .fp_mm(5),
    // .fp_mm(6),
    // .fp_mm(7),

    // .fp_xmm(0),
    // .fp_xmm(1),
    // .fp_xmm(2),
    // .fp_xmm(3),
    // .fp_xmm(4),
    // .fp_xmm(5),
    // .fp_xmm(6),
    // .fp_xmm(7),
    // .fp_xmm(8),
    // .fp_xmm(9),
    // .fp_xmm(10),
    // .fp_xmm(11),
    // .fp_xmm(12),
    // .fp_xmm(13),
    // .fp_xmm(14),
    // .fp_xmm(15),

    // // Debug Registers (DR)
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
    dwarf_id: ?u32,
    size: SizeCalculation,
    offset_calc: OffsetCalculation,
    reg_type: RegisterType,
    reg_format: RegisterFormat,

    const SizeCalculation = union(enum) {
        raw: usize,
        fp_reg: []const u8,
    };

    // Enum to describe how to calculate the offset
    const OffsetCalculation = union(enum) {
        gpr: []const u8, // Field name within user_regs_struct
        sub_gpr: SubGprOffset,
        fpr: FprOffset,
        dr: usize, // Debug register number (0-7) - index into user._u_debugreg

        const SubGprOffset = struct {
            super_reg_field: []const u8, // Field name of the 64-bit super register
            byte_offset: usize = 0, // 0 for low part, 1 for high byte (AH, etc.)
        };
        const FprOffset = union(enum) {
            field: []const u8, // field of user_fpregs_struct
        };
    };

    // Helper functions to create definitions
    fn gpr_64(
        name: []const u8,
        dwarf: ?u32,
    ) RegisterDefinition {
        return .{
            .name = name,
            .dwarf_id = dwarf,
            .size = .{ .raw = 8 },
            .offset_calc = .{ .gpr = name },
            .reg_type = .gpr,
            .reg_format = .uint,
        };
    }
    fn gpr_32(name: []const u8, super_field: []const u8) RegisterDefinition {
        return .{
            .name = name,
            .dwarf_id = null,
            .size = .{ .raw = 4 },
            .offset_calc = .{ .sub_gpr = .{ .super_reg_field = super_field } },
            .reg_type = .sub_gpr,
            .reg_format = .uint,
        };
    }
    fn gpr_16(name: []const u8, super_field: []const u8) RegisterDefinition {
        return .{
            .name = name,
            .dwarf_id = null,
            .size = .{ .raw = 2 },
            .offset_calc = .{ .sub_gpr = .{ .super_reg_field = super_field } },
            .reg_type = .sub_gpr,
            .reg_format = .uint,
        };
    }
    fn gpr_8h(name: []const u8, super_field: []const u8) RegisterDefinition {
        return .{
            .name = name,
            .dwarf_id = null,
            .size = .{ .raw = 1 },
            .offset_calc = .{ .sub_gpr = .{ .super_reg_field = super_field, .byte_offset = 1 } },
            .reg_type = .sub_gpr,
            .reg_format = .uint,
        };
    }
    fn gpr_8l(name: []const u8, super_field: []const u8) RegisterDefinition {
        return .{
            .name = name,
            .dwarf_id = null,
            .size = .{ .raw = 1 },
            .offset_calc = .{ .sub_gpr = .{ .super_reg_field = super_field } }, // byte_offset = 0 default
            .reg_type = .sub_gpr,
            .reg_format = .uint,
        };
    }
    fn fpr(
        name: []const u8,
        dwarf: ?u32,
        field: []const u8,
    ) RegisterDefinition {
        return .{
            .name = name,
            .dwarf_id = dwarf,
            .size = .{ .fp_reg = field },
            .offset_calc = .{ .fpr = .{ .field = field } },
            .reg_type = .fpr,
            .reg_format = .uint,
        };
    }
    // fn fp_st(num: u4) RegisterDefinition {
    //     return .{
    //         .name = "st" ++ std.fmt.comptimePrint("{d}", .{num}),
    //         .dwarf_id = @intCast(33 + num),
    //         .size = 16, // sizeof long double on x86_64 linux is often 16
    //         .offset_calc = .{ .fpr = .{ .base = .st_space, .field_or_index = .{ .index = num } } },
    //         .reg_type = .fpr,
    //         .reg_format = .long_double,
    //     };
    // }
    // fn fp_mm(num: u4) RegisterDefinition {
    //     return .{
    //         .name = "mm" ++ std.fmt.comptimePrint("{d}", .{num}),
    //         .dwarf_id = @intCast(41 + num),
    //         .size = 8,
    //         .offset_calc = .{ .fpr = .{ .base = .st_space, .field_or_index = .{ .index = num } } },
    //         .reg_type = .fpr,
    //         .reg_format = .vector, // MMX registers
    //     };
    // }
    // fn fp_xmm(num: u4) RegisterDefinition {
    //     return .{
    //         .name = "xmm" ++ std.fmt.comptimePrint("{d}", .{num}),
    //         .dwarf_id = @intCast(17 + num),
    //         .size = 16, // XMM registers are 128-bit
    //         .offset_calc = .{ .fpr = .{ .base = .xmm_space, .field_or_index = .{ .index = num } } },
    //         .reg_type = .fpr,
    //         .reg_format = .vector,
    //     };
    // }
    fn dr(num: u4) RegisterDefinition {
        return .{
            .name = "dr" ++ std.fmt.comptimePrint("{d}", .{num}),
            .dwarf_id = null,
            .size = .{ .raw = 8 },
            .offset_calc = .{ .dr = num },
            .reg_type = .dr,
            .reg_format = .uint,
        };
    }
};
