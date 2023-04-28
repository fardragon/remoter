const std = @import("std");
const mbox = @import("mailbox.zig").Mailbox;
const serial = @import("serial.zig").Serial;
const arm = @import("arm.zig");

export fn remoter_main() noreturn {
    arm.zeroBSS();
    serial.init();
    serial.println("Hello world!", .{});
    serial.println("Serial number: {}\r\n", .{mbox.get_serial_number() catch unreachable});

    while (true) {}
}
