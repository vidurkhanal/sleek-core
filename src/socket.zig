const std = @import("std");

pub const UnixConnection = struct {
    conn: std.net.Stream,
    mutex: std.Thread.Mutex,

    pub fn init(path: []const u8) !UnixConnection {
        return UnixConnection{
            .conn = try std.net.connectUnixSocket(path),
            .mutex = std.Thread.Mutex{},
        };
    }

    pub fn deinit(self: *UnixConnection) void {
        self.conn.close();
    }

    pub fn sendAndReceive(self: *UnixConnection, allocator: std.mem.Allocator, message: []const u8) ![]u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        try self.conn.writeAll(message);

        var buffer = try allocator.alloc(u8, 1024); // Adjust size as needed
        defer allocator.free(buffer);

        const bytes_read = try self.conn.read(buffer);
        return allocator.dupe(u8, buffer[0..bytes_read]);
    }
};
