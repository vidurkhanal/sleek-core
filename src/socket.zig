const std = @import("std");
const mem = std.mem;
const net = std.net;

pub const UnixConnection = struct {
    allocator: mem.Allocator,
    conn: net.Stream,
    mutex: std.Thread.Mutex,
    path: []const u8,

    pub fn init(allocator: mem.Allocator, path: []const u8) !UnixConnection {
        return UnixConnection{
            .allocator = allocator,
            .conn = try net.connectUnixSocket(path),
            .mutex = std.Thread.Mutex{},
            .path = path,
        };
    }

    pub fn deinit(self: *UnixConnection) void {
        self.conn.close();
    }

    fn reconnect(self: *UnixConnection) !void {
        self.conn.close();
        self.conn = try net.connectUnixSocket(self.path);
    }

    pub fn sendAndReceive(self: *UnixConnection, message: []const u8) ![]u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var buffer = try self.allocator.alloc(u8, 4 * 1024);
        defer self.allocator.free(buffer);

        // Try to send and receive with reconnection logic
        while (true) {
            self.conn.writeAll(message) catch |err| {
                switch (err) {
                    error.BrokenPipe => {
                        // Attempt to reconnect if broken pipe error occurs
                        try self.reconnect();
                        continue; // Retry sending the message
                    },
                    else => {
                        return err; // Propagate other errors
                    },
                }
            };

            // Try to read from the connection
            const bytes_read = self.conn.read(buffer) catch |err| {
                switch (err) {
                    error.BrokenPipe => {
                        // Attempt to reconnect if broken pipe error occurs
                        try self.reconnect();
                        continue; // Retry sending the message
                    },
                    else => {
                        return err; // Propagate other errors
                    },
                }
            };

            // Successfully read from the connection
            return self.allocator.dupe(u8, buffer[0..bytes_read]);
        }
    }
};
