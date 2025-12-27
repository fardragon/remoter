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
            .int => self.parseInt(T),
            .@"struct" => self.parseStruct(T),
            .@"enum" => self.parseEnum(T),
            else => |info| @compileError(std.fmt.comptimePrint("Unsupported type {}", .{info})),
        };
    }

    fn parseEnum(self: *Self, comptime T: type) !T {
        const tagType = @typeInfo(T).@"enum".tag_type;
        const result = try self.parseInt(tagType);
        return @as(T, @enumFromInt(result));
    }

    fn parseInt(self: *Self, comptime T: type) !T {
        const size = @sizeOf(T);
        if (self.offset + size > self.memory.len) {
            return error.OutOfBounds;
        }

        const result = std.mem.readInt(T, self.memory[self.offset..][0..size], std.builtin.Endian.big);

        // const result = std.mem.readVarInt(T, self.memory[self.offset .. self.offset + size], std.builtin.Endian.Big);
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
