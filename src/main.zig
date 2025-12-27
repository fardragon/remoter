const std = @import("std");
const mbox = @import("mailbox.zig").Mailbox;
const serial = @import("serial.zig").Serial;
const arm = @import("arm.zig");
const String = @import("string.zig").AsciiString;
const DeviceTree = @import("device_tree.zig").DeviceTree;
const UART = @import("uart.zig").UART0;
const Util = @import("util.zig");

var buffer: [512 * 1024]u8 = undefined;

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    serial.println("Panic!: {s}", .{msg});

    var writer = UART.writer();
    if (error_return_trace) |st| {
        writer.print("Stack trace index: {d} len: {d}\r\n", .{ st.index, st.instruction_addresses.len }) catch {};
    }

    while (true) {}
}

export fn remoter_main(x0: [*]u8) noreturn {
    const bss_size = arm.zeroBSS();
    serial.init();
    serial.println("Remoter v0.0.1", .{});
    serial.println("Serial number: {}", .{mbox.get_serial_number() catch unreachable});
    serial.println("BSS size: 0x{x}", .{bss_size});

    serial.println("Device tree {*}", .{x0});

    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    // var logging_allocator = std.heap.LogToWriterAllocator(UART.writer_type).init(allocator.allocator(), UART.writer());
    serial.println("Heap size: 0x{x}", .{buffer.len});

    {
        var tree = DeviceTree.init(allocator, x0) catch unreachable;
        defer tree.deinit();

        serial.println("DTB: \r\n{f}\r\n", .{tree});
    }

    while (true) {
        if (UART.read_char()) |char| {
            serial.println("{c}", .{char});
        } else {
            Util.wait_cycles(10 * 1_000_000);
        }
    }
}
