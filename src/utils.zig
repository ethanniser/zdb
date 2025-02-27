const std = @import("std");

pub fn errorToBytes(err: anyerror) [2]u8 {
    // Convert error to integer code
    const code: u16 = @intFromError(err);

    // Create fixed-size array from integer
    var result: [2]u8 = undefined;
    @memcpy(&result, std.mem.asBytes(&code));
    return result;
}

pub fn bytesToError(bytes: [2]u8) anyerror {
    // Convert bytes back to integer
    var code: u16 = undefined;
    @memcpy(std.mem.asBytes(&code), &bytes);

    // Convert integer back to error
    return @errorFromInt(code);
}

const t = std.testing;

test {
    const err = error.TestError;
    const bytes = errorToBytes(err);
    const err2 = bytesToError(bytes);
    try t.expect(err == err2);
}
