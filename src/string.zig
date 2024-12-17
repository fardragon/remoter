const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const Allocator = mem.Allocator;

pub const AsciiString = struct {
    const Self = @This();
    buffer: []u8,
    allocator: Allocator,

    pub fn init(allocator: Allocator, string: []const u8) !Self {
        const result: Self = .{
            .buffer = try allocator.alloc(u8, string.len),
            .allocator = allocator,
        };
        mem.copyForwards(u8, result.buffer, string);
        return result;
    }

    pub fn append(self: *Self, c: u8) !void {
        self.buffer = try self.allocator.realloc(self.buffer, self.buffer.len + 1);
        self.buffer[self.buffer.len - 1] = c;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.buffer);
    }

    pub fn format(value: Self, comptime fmt_str: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt_str;
        _ = options;
        try fmt.format(writer, "{s}", .{value.buffer});
    }

    pub fn len(self: Self) usize {
        return self.buffer.len;
    }
};
