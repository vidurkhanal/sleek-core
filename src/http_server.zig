const std = @import("std");
const socket = @import("socket.zig");
const zap = @import("zap");
const log = std.log;
const mem = std.mem;

var uc: socket.UnixConnection = undefined;

const SleekStatus = enum {
    Ok,
    Error,
};

const SleekResponse = struct {
    status: SleekStatus,
    response: ?[]const u8,

    fn Error(response: ?[]const u8) SleekResponse {
        return SleekResponse{ .status = SleekStatus.Error, .response = response };
    }

    fn Ok(response: ?[]const u8) SleekResponse {
        return SleekResponse{ .status = SleekStatus.Ok, .response = response };
    }
};

fn on_request(r: zap.Request) void {
    r.setContentType(.JSON) catch |err| {
        log.err("Failed to set content type: {}\n", .{err});
        return;
    };

    var buf: [512]u8 = undefined;

    const response = uc.sendAndReceive(r.body orelse "") catch |err| {
        const res = SleekResponse.Error("couldn't communicate with sleek socket");
        log.err("couldn't communicate with sleek socket: {}\n", .{err});
        if (zap.stringifyBuf(&buf, res, .{ .emit_null_optional_fields = true })) |json| {
            r.sendBody(json) catch return;
        } else {
            r.sendBody("null") catch return;
        }
        return;
    };

    const res = SleekResponse.Ok(response);
    if (zap.stringifyBuf(&buf, res, .{ .emit_null_optional_fields = true })) |json| {
        r.sendBody(json) catch return;
    } else {
        r.sendBody("null") catch return;
    }

    return;
}

pub fn start(allocator: mem.Allocator) !void {
    uc = try socket.UnixConnection.init(allocator, "/tmp/sleek.sock");
    defer uc.deinit();

    var listener = zap.Endpoint.Listener.init(allocator, .{
        .port = 3000,
        .on_request = on_request,
        .log = true,
        .max_clients = 100000,
    });

    try listener.listen();
    log.info("Listening on 0.0.0.0:3000\n", .{});
    zap.start(.{
        .threads = 8,
        .workers = 10,
    });
}
