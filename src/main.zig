const std = @import("std");
const UART = @import("uart.zig").UART0;
const mbox = @import("mailbox.zig").Mailbox;

export fn remoter_main() noreturn {
    UART.init();

    std.fmt.format(UART.writer(), "Serial number: {}\r\n", .{mbox.get_serial_number() catch unreachable}) catch unreachable;

    while (true) {}
}
