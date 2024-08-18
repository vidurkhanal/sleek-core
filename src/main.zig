const std = @import("std");
const http_server = @import("http_server.zig");
const heap = std.heap;
const log = std.log;

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    const allocator = gpa.allocator();
    {
        try http_server.start(allocator);
    }
    // show potential memory leaks when ZAP is shut down
    const has_leaked = gpa.detectLeaks();
    log.debug("Has leaked: {}\n", .{has_leaked});
}
