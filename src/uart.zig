const io = @import("io.zig");
const util = @import("util.zig");
const std = @import("std");
const Mailbox = @import("mailbox.zig").Mailbox;

const UART0_DR: io.MMIORegister = io.MMIORegister.init(io.MMIO_BASE, 0x00201000);
const UART0_FR: io.MMIORegister = io.MMIORegister.init(io.MMIO_BASE, 0x00201018);
const UART0_IBRD: io.MMIORegister = io.MMIORegister.init(io.MMIO_BASE, 0x00201024);
const UART0_FBRD: io.MMIORegister = io.MMIORegister.init(io.MMIO_BASE, 0x00201028);
const UART0_LCRH: io.MMIORegister = io.MMIORegister.init(io.MMIO_BASE, 0x0020102C);
const UART0_CR: io.MMIORegister = io.MMIORegister.init(io.MMIO_BASE, 0x00201030);
const UART0_ICR: io.MMIORegister = io.MMIORegister.init(io.MMIO_BASE, 0x00201044);

pub const UART0 = struct {
    pub fn init() void {
        UART0_CR.write_raw(0); // disable UART0 for configuration

        Mailbox.set_uart_clock(4000000) catch unreachable;

        // map uart to GPIO pins 14 & 15
        var reg = io.GPFSEL1.read_raw();
        reg &= ~((@as(u32, 7) << 12) | (@as(u32, 7) << 15));
        reg |= (@as(u32, 4) << 12) | (@as(u32, 4) << 15);
        io.GPFSEL1.write_raw(reg);

        // enable GPIO pins
        io.GPPUD.write_raw(0);
        util.wait_cycles(150);
        io.GPPUDCLK0.write_raw((1 << 14) | (1 << 15));
        util.wait_cycles(150);
        io.GPPUDCLK0.write_raw(0);

        UART0_ICR.write_raw(0x7FF); // clear interrupts

        UART0_IBRD.write_raw(2); // 115200 baud
        UART0_FBRD.write_raw(0xB);

        UART0_LCRH.write_raw(0x7 << 4); // 8N1 + FIFO

        UART0_CR.write_raw(0x301); // UART0 Tx + Rx
    }

    pub fn send_char(char: u8) void {
        while (UART0_FR.read_raw() & (1 << 5) != 0) {
            util.wait_cycles(1);
        }
        UART0_DR.write_raw(@as(u32, char));
    }

    const writer_context = struct {};
    const writer_error = error{};

    pub fn writer_function(_: writer_context, bytes: []const u8) writer_error!usize {
        var index: usize = 0;
        while (index != bytes.len) {
            UART0.send_char(bytes[index]);
            index += 1;
        }
        return bytes.len;
    }

    const writer_type = std.io.Writer(
        writer_context,
        writer_error,
        UART0.writer_function,
    );

    pub fn writer() UART0.writer_type {
        const w: UART0.writer_type = .{
            .context = UART0.writer_context{},
        };
        return w;
    }
};

pub const UARTWriter = struct {
    const Self = @This();
};
