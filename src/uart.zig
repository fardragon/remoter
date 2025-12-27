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

const UART0_FRFlags = enum(u4) {
    CTS = 0,
    DSR = 1,
    DCD = 2,
    BUSY = 3,
    RXFE = 4,
    TXFF = 5,
    RXFF = 6,
    TXFE = 7,
    RI = 8,
};

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
        const reg = UART0_FR.read();
        while (reg.isSet(@intFromEnum(UART0_FRFlags.TXFF))) {
            util.wait_cycles(1);
        }
        UART0_DR.write_raw(@as(io.MMIORegister.RegisterType, char));
    }

    pub fn read_char() ?u8 {
        const reg = UART0_FR.read();

        if (reg.isSet(@intFromEnum(UART0_FRFlags.RXFE))) {
            return null;
        } else {
            return @as(u8, @truncate(UART0_DR.read_raw()));
        }
    }

    pub fn writer_function(w: *std.io.Writer, data: []const []const u8, splat: usize) std.io.Writer.Error!usize {
        _ = w; // autofix
        std.debug.assert(splat == 1);
        std.debug.assert(data.len == 1);

        for (data) |line| {
            for (line) |byte| {
                UART0.send_char(byte);
            }
        }
        return data[0].len;
    }

    pub fn writer() std.io.Writer {
        return .{
            .vtable = &.{ .drain = writer_function },
            .buffer = &.{},
        };
    }
};
