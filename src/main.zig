const std = @import("std");
const zap = @import("zap");

const PythonConnection = struct {
    conn: std.net.Stream,
    mutex: std.Thread.Mutex,

    fn init(path: []const u8) !PythonConnection {
        return PythonConnection{
            .conn = try std.net.connectUnixSocket(path),
            .mutex = std.Thread.Mutex{},
        };
    }

    fn deinit(self: *PythonConnection) void {
        self.conn.close();
    }

    fn sendAndReceive(self: *PythonConnection, allocator: std.mem.Allocator, message: []const u8) ![]u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        try self.conn.writeAll(message);

        var buffer = try allocator.alloc(u8, 1024); // Adjust size as needed
        defer allocator.free(buffer);

        const bytes_read = try self.conn.read(buffer);
        return allocator.dupe(u8, buffer[0..bytes_read]);
    }
};

var python_conn: PythonConnection = undefined;

fn on_request(r: zap.Request) void {
    if (r.path) |the_path| {
        std.debug.print("PATH: {s}\n", .{the_path});
    }
    if (r.query) |the_query| {
        std.debug.print("QUERY: {s}\n", .{the_query});
    }

    const allocator = std.heap.page_allocator;

    const response = python_conn.sendAndReceive(allocator, "hello hello") catch |err| {
        std.debug.print("Error communicating with Python: {s}\n", .{@errorName(err)});
        r.sendBody("Internal Server Error") catch |send_err| {
            std.debug.print("Error sending error response: {s}\n", .{@errorName(send_err)});
        };
        return;
    };
    defer allocator.free(response);

    r.sendBody(response) catch |err| {
        std.debug.print("Error sending response: {s}\n", .{@errorName(err)});
    };
}

pub fn main() !void {
    python_conn = try PythonConnection.init("/tmp/sleek.sock");
    defer python_conn.deinit();

    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = on_request,
        .log = true,
    });
    try listener.listen();
    std.debug.print("Listening on 0.0.0.0:3000\n", .{});
    zap.start(.{
        .threads = 2,
        .workers = 2,
    });
}
