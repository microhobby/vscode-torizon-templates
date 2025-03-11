const std = @import("std");
const log = std.log.scoped(.toradex);
const builtin = @import("builtin");

// override the std implementation
pub const std_options: std.Options = .{
    .log_level = switch (builtin.mode) {
        .Debug => .debug,
        else => .info,
    },
};

// need pub to export the function
pub fn printHello() void {
    log.info("Hello {s}!", .{"Torizon"});
}
