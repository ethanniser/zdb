const Self = @This();
const std = @import("std");
const posix = std.posix;
const fd_t = posix.fd_t;

read_fd: fd_t,
write_fd: fd_t,

const Options = struct {
    close_on_exec: bool,
};

pub fn init(options: Options) !Self {
    const result = try posix.pipe2(.{
        .CLOEXEC = options.close_on_exec,
    });
    return Self{
        .read_fd = result[0],
        .write_fd = result[1],
    };
}
pub fn deinit(self: *Self) void {
    self.close_read();
    self.close_write();
}

pub fn release_read(self: *Self) fd_t {
    const fd = self.read_fd;
    self.read_fd = -1;
    return fd;
}
pub fn release_write(self: *Self) fd_t {
    const fd = self.write_fd;
    self.write_fd = -1;
    return fd;
}

pub fn close_read(self: *Self) void {
    if (self.read_fd != -1) {
        posix.close(self.read_fd);
        self.read_fd = -1;
    }
}
pub fn close_write(self: *Self) void {
    if (self.write_fd != -1) {
        posix.close(self.write_fd);
        self.write_fd = -1;
    }
}

pub fn read(self: *Self, buffer: []u8) !usize {
    return posix.read(self.read_fd, buffer);
}
pub fn write(self: *Self, bytes: []u8) !usize {
    return posix.write(self.write_fd, bytes);
}
