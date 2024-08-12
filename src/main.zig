const http_server = @import("http_server.zig");

pub fn main() !void {
    try http_server.start();
}
