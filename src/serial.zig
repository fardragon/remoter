const UART = @import("uart.zig").UART0;
const std = @import("std");
const fmt = std.fmt;

pub const Serial = struct {
    pub fn init() void {
        UART.init();
    }

    pub fn print(comptime fmt_str: []const u8, args: anytype) void {
        var writer = UART.writer();
        return writer.print(fmt_str, args) catch unreachable;
    }
    pub fn println(comptime fmt_str: []const u8, args: anytype) void {
        var writer = UART.writer();

        writer.print(fmt_str, args) catch unreachable;
        _ = writer.write("\r\n") catch unreachable;
    }
};
