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
    name: String,
    value: PropertyValue,

    fn deinit(self: *Self, allocator: Allocator) void {
        self.name.deinit();
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
        self.properties.deinit();

        for (self.children.items) |*child| {
            child.*.deinit(allocator);
        }
        self.children.deinit();
    }

    fn print_to_writer(self: Self, writer: anytype, depth: usize) @TypeOf(writer).Error!void {
        for (0..depth) |_| {
            try writer.print("\t", .{});
        }
        try writer.print("{} {s}\r\n", .{ self.name, "{" });

        for (self.properties.items) |property| {
            for (0..depth) |_| {
                try writer.print("\t", .{});
            }
            try writer.print("{} = {}", .{ property.name, property.value });
        }

        try writer.print("\r\n", .{});
        for (self.children.items) |child| {
            try child.print_to_writer(writer, depth + 1);
        }

        for (0..depth) |_| {
            try writer.print("\t", .{});
        }
        try writer.print("{s}", .{"};"});
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
    nodes: std.ArrayList(Node),
    allocator: Allocator,

    pub fn init(allocator: Allocator, address: [*]u8) !Self {
        var header_reader = MemoryReader.init(address, 10 * @sizeOf(u32));
        const header = try header_reader.read(DeviceTreeHeader);

        return .{
            .memory_reservations = try Self.parse_memory_reservations(allocator, address, header),
            .nodes = try Self.parse_nodes(allocator, address, header),
            .allocator = allocator,
        };
    }

    fn parse_memory_reservations(allocator: Allocator, address: [*]u8, header: DeviceTreeHeader) !std.ArrayList(MemoryReservation) {
        var mem_reader = MemoryReader.init(address + header.off_mem_rsvmap, header.totalsize - header.off_mem_rsvmap);
        var reservations = std.ArrayList(MemoryReservation).init(allocator);
        while (true) {
            const reservation = try mem_reader.read(MemoryReservation);
            if (reservation.address == 0 and reservation.size == 0) {
                break;
            }
            try reservations.append(reservation);
        }
        return reservations;
    }

    fn parse_nodes(allocator: Allocator, address: [*]u8, header: DeviceTreeHeader) !std.ArrayList(Node) {
        var nodes_reader = MemoryReader.init(address + header.off_dt_struct, header.size_dt_struct);
        _ = nodes_reader;
        var nodes = std.ArrayList(Node).init(allocator);
        var test_node = Node{
            .name = try String.init(allocator, "Test node"),
            .properties = std.ArrayList(Property).init(allocator),
            .children = std.ArrayList(Node).init(allocator),
        };
        try nodes.append(test_node);
        return nodes;
    }

    pub fn deinit(self: *Self) void {
        self.memory_reservations.deinit();
        for (self.nodes.items) |*node| {
            node.*.deinit(self.allocator);
        }
        self.nodes.deinit();
    }

    pub fn format(self: Self, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) @TypeOf(writer).Error!void {
        try writer.print("Memory reservations: \r\n", .{});
        for (self.memory_reservations.items) |reservation| {
            try writer.print("\t0x{x}: {}\r\n", .{ reservation.address, reservation.size });
        }

        try writer.print("Nodes: \r\n", .{});
        for (self.nodes.items) |node| {
            try node.print_to_writer(writer, 1);
        }

        return;
    }
};
