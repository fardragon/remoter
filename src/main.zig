const std = @import("std");
const mbox = @import("mailbox.zig").Mailbox;
const serial = @import("serial.zig").Serial;
const arm = @import("arm.zig");
const String = @import("string.zig").AsciiString;
const DeviceTree = @import("device_tree.zig").DeviceTree;
const UART = @import("uart.zig").UART0;

var buffer: [512 * 1024]u8 = undefined;

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    serial.println("Panic!: {s}", .{msg});
    _ = error_return_trace;

    while (true) {}
}

export fn remoter_main(x0: [*]u8) noreturn {
    const bss_size = arm.zeroBSS();
    serial.init();
    serial.println("Remoter v0.0.1", .{});
    serial.println("Serial number: {}", .{mbox.get_serial_number() catch unreachable});
    serial.println("BSS size: 0x{x}", .{bss_size});

    serial.println("Device tree {*}", .{x0});

    var allocator = std.heap.FixedBufferAllocator.init(&buffer);

    var logging_allocator = std.heap.LogToWriterAllocator(UART.writer_type).init(allocator.allocator(), UART.writer());
    serial.println("Heap size: 0x{x}", .{buffer.len});

    {
        var tree = DeviceTree.init(logging_allocator.allocator(), x0) catch unreachable;

        serial.println("DTB: \r\n{}\r\n", .{tree});
        defer tree.deinit();
    }

    while (true) {}
}
