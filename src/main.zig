const std = @import("std");
const mbox = @import("mailbox.zig").Mailbox;
const serial = @import("serial.zig").Serial;

export fn remoter_main() noreturn {
    serial.init();
    serial.println("Hello world!", .{});
    serial.println("Serial number: {}\r\n", .{mbox.get_serial_number() catch unreachable});

    while (true) {}
}
