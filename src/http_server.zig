const std = @import("std");
const socket = @import("socket.zig");
const zap = @import("zap");

var conn: socket.UnixConnection = undefined;
var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};

fn on_request(r: zap.Request) void {
    var allocator = gpa.allocator();
    const response = conn.sendAndReceive(allocator, "hello hello") catch |err| {
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

pub fn start() !void {
    {
        conn = try socket.UnixConnection.init("/tmp/sleek.sock");
        defer conn.deinit();

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
    std.debug.print("LEAKS: {}\n", .{gpa.detectLeaks()});
}
