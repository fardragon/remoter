const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const Allocator = mem.Allocator;

pub const AsciiString = struct {
    const Self = @This();
    buffer: []u8,
    allocator: Allocator,

    pub fn init(allocator: Allocator, string: []const u8) !Self {
        var result: Self = .{
            .buffer = try allocator.alloc(u8, string.len),
            .allocator = allocator,
        };
        mem.copy(u8, result.buffer, string);
        return result;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.buffer);
    }

    pub fn format(value: Self, comptime fmt_str: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt_str;
        _ = options;
        try fmt.format(writer, "{s}", .{value.buffer});
    }
};
