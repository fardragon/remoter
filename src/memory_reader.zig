const std = @import("std");

pub const MemoryReader = struct {
    const Self = @This();
    memory: []u8,
    offset: usize,

    pub fn init(ptr: [*]u8, size: usize) Self {
        return .{ .memory = ptr[0..size], .offset = 0 };
    }

    pub fn read(self: *Self, comptime T: type) !T {
        return switch (@typeInfo(T)) {
            .Int => self.parseInt(T),
            .Struct => self.parseStruct(T),
            else => |info| @compileError(std.fmt.comptimePrint("Unsupported type {}", .{info})),
        };
    }

    fn parseInt(self: *Self, comptime T: type) !T {
        const size = @sizeOf(T);
        if (self.offset + size > self.memory.len) {
            return error.OutOfBounds;
        }

        const result = std.mem.readVarInt(T, self.memory[self.offset .. self.offset + size], std.builtin.Endian.Big);
        self.offset += size;
        return result;
    }

    fn parseStruct(self: *Self, comptime T: type) !T {
        const fields = std.meta.fields(T);

        var result: T = undefined;
        inline for (fields) |field| {
            @field(result, field.name) = try self.read(field.type);
        }

        return result;
    }
};
