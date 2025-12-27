const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const MemoryReader = @import("memory_reader.zig").MemoryReader;
const String = @import("string.zig").AsciiString;

const DeviceTreeHeader = struct {
    magic: u32,
    totalsize: u32,
    off_dt_struct: u32,
    off_dt_strings: u32,
    off_mem_rsvmap: u32,
    version: u32,
    last_comp_version: u32,
    boot_cpuid_phys: u32,
    size_dt_strings: u32,
    size_dt_struct: u32,
};

const DeviceTreeStringBlock = struct {
    const Self = @This();
    memory: []u8,

    pub fn init(ptr: [*]u8, size: usize) Self {
        return .{ .memory = ptr[0..size] };
    }

    pub fn read_string_at(self: Self, offset: u32) []const u8 {
        var ix = offset;
        while (true) {
            const c = self.memory[ix];
            if (c == 0) {
                break;
            } else {
                ix += 1;
            }
        }
        return self.memory[offset..ix];
    }
};

pub const MemoryReservation = struct {
    address: u64,
    size: u64,
};

pub const PropertyValue = union(enum) {
    const Self = @This();
    bytes: []u8,
    string: String,
    U32: u32,
    U64: u64,

    fn deinit(self: *Self, allocator: Allocator) void {
        switch (self.*) {
            PropertyValue.bytes => |*bytes| allocator.free(bytes.*),
            PropertyValue.string => |*string| string.deinit(),
            else => {},
        }
    }
};

pub const Property = struct {
    const Self = @This();
    name_offset: u32,
    value: PropertyValue,

    fn deinit(self: *Self, allocator: Allocator) void {
        self.value.deinit(allocator);
    }
};

pub const Node = struct {
    const Self = @This();

    name: String,
    properties: std.ArrayList(Property),
    children: std.ArrayList(Node),

    fn deinit(self: *Self, allocator: Allocator) void {
        self.name.deinit();
        for (self.properties.items) |*prop| {
            prop.*.deinit(allocator);
        }
        self.properties.deinit(allocator);

        for (self.children.items) |*child| {
            child.*.deinit(allocator);
        }
        self.children.deinit(allocator);
    }

    fn print_to_writer(self: Self, writer: *std.Io.Writer, strings: DeviceTreeStringBlock, depth: usize) std.Io.Writer.Error!void {
        for (0..depth) |_| {
            try writer.print("\t", .{});
        }
        try writer.print("{f} {s}\r\n", .{ self.name, "{" });

        for (self.properties.items) |property| {
            for (0..depth) |_| {
                try writer.print("\t", .{});
            }
            try writer.print("{s} = {}\r\n", .{ strings.read_string_at(property.name_offset), property.value });
        }

        try writer.print("\r\n", .{});
        for (self.children.items) |child| {
            try child.print_to_writer(writer, strings, depth + 1);
        }

        for (0..depth) |_| {
            try writer.print("\t", .{});
        }
        try writer.print("{s}\r\n", .{"};"});
    }
};

const DeviceTreeToken = enum(u32) {
    BeginNode = 0x00000001,
    EndNode = 0x00000002,
    Prop = 0x00000003,
    Nop = 0x00000004,
    End = 0x00000009,
};

pub const DeviceTree = struct {
    const Self = @This();
    memory_reservations: std.ArrayList(MemoryReservation),
    strings: DeviceTreeStringBlock,
    nodes: std.ArrayList(Node),
    allocator: Allocator,

    pub fn init(allocator: Allocator, address: [*]u8) !Self {
        var header_reader = MemoryReader.init(address, @sizeOf(DeviceTreeHeader));
        const header = try header_reader.read(DeviceTreeHeader);
        const strings_block = DeviceTreeStringBlock.init(address + header.off_dt_strings, header.size_dt_strings);

        return .{
            .memory_reservations = try Self.parse_memory_reservations(allocator, address, header),
            .strings = strings_block,
            .nodes = try Self.parse_nodes(allocator, address, header, strings_block),
            .allocator = allocator,
        };
    }

    fn parse_memory_reservations(allocator: Allocator, address: [*]u8, header: DeviceTreeHeader) !std.ArrayList(MemoryReservation) {
        var mem_reader = MemoryReader.init(address + header.off_mem_rsvmap, header.totalsize - header.off_mem_rsvmap);
        var reservations: std.ArrayList(MemoryReservation) = .empty;
        while (true) {
            const reservation = try mem_reader.read(MemoryReservation);
            if (reservation.address == 0 and reservation.size == 0) {
                break;
            }
            try reservations.append(allocator, reservation);
        }
        return reservations;
    }

    fn parse_nodes(allocator: Allocator, address: [*]u8, header: DeviceTreeHeader, strings_block: DeviceTreeStringBlock) !std.ArrayList(Node) {
        var nodes_reader = MemoryReader.init(address + header.off_dt_struct, header.size_dt_struct);

        var nodes: std.ArrayList(Node) = .empty;

        while (true) {
            const token = try nodes_reader.read(DeviceTreeToken);
            switch (token) {
                DeviceTreeToken.BeginNode => {
                    try nodes.append(allocator, try parse_node(allocator, &nodes_reader, strings_block));
                },
                DeviceTreeToken.Nop => {},
                DeviceTreeToken.End => break,
                else => {
                    return error.MalformedDeviceTree;
                },
            }
        }

        return nodes;
    }

    fn parse_node(allocator: Allocator, reader: *MemoryReader, strings: DeviceTreeStringBlock) !Node {
        var name = try parse_node_name(allocator, reader);

        var properties: std.ArrayList(Property) = .empty;
        var children: std.ArrayList(Node) = .empty;

        errdefer {
            name.deinit();
            for (children.items) |*node| {
                node.*.deinit(allocator);
            }
            children.deinit(allocator);

            for (properties.items) |*prop| {
                prop.*.deinit(allocator);
            }
            properties.deinit(allocator);
        }

        while (true) {
            const token = try reader.read(DeviceTreeToken);
            switch (token) {
                .BeginNode => {
                    try children.append(allocator, try parse_node(allocator, reader, strings));
                },
                .Prop => {
                    try properties.append(allocator, try parse_property(allocator, reader, strings));
                },
                .EndNode => break,
                .Nop => {},
                else => {
                    return error.MalformedDeviceTree;
                },
            }
        }

        return Node{
            .name = name,
            .properties = properties,
            .children = children,
        };
    }

    fn parse_property(allocator: Allocator, reader: *MemoryReader, strings: DeviceTreeStringBlock) !Property {
        _ = strings; // autofix
        const value_length = try reader.read(u32);
        const name_offset = try reader.read(u32);

        var bytes = try allocator.alloc(u8, value_length);
        errdefer allocator.free(bytes);
        for (0..value_length) |i| {
            bytes[i] = try reader.read(u8);
        }

        const padding_bytes = if (value_length % 4 == 0) 0 else 4 - (value_length % 4);
        for (0..padding_bytes) |_| {
            _ = try reader.read(u8);
        }

        return Property{
            .name_offset = name_offset,
            .value = PropertyValue{ .bytes = bytes },
        };
    }

    fn parse_node_name(allocator: Allocator, reader: *MemoryReader) !String {
        var result = try String.init(allocator, "");

        while (true) {
            const c = try reader.read(u8);
            if (c == 0) {
                break;
            } else {
                try result.append(c);
            }
        }

        const padding_bytes = if ((result.len() + 1) % 4 == 0) 0 else 4 - ((result.len() + 1) % 4);

        for (0..padding_bytes) |_| {
            _ = try reader.read(u8);
        }

        return result;
    }

    pub fn deinit(self: *Self) void {
        self.memory_reservations.deinit(self.allocator);
        for (self.nodes.items) |*node| {
            node.*.deinit(self.allocator);
        }
        self.nodes.deinit(self.allocator);
    }

    pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("Memory reservations: \r\n", .{});
        for (self.memory_reservations.items) |reservation| {
            try writer.print("\t0x{x}: {}\r\n", .{ reservation.address, reservation.size });
        }

        try writer.print("Nodes: \r\n", .{});
        for (self.nodes.items) |node| {
            try node.print_to_writer(writer, self.strings, 1);
        }
    }
};
