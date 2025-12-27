const io = @import("io.zig");
const util = @import("util.zig");
const std = @import("std");
const Mailbox = @import("mailbox.zig").Mailbox;

const UART0_ICR = struct {
    var reg: io.MMIORegister = io.MMIORegister.init(io.MMIO_BASE, 0x00201044);

    fn clear_interrupts() void {
        reg.write_raw(std.math.maxInt(io.MMIORegister.RegisterType));
    }
};

const UART0_IBRD = struct {
    var reg: io.MMIORegister = io.MMIORegister.init(io.MMIO_BASE, 0x00201024);

    fn set(value: u16) void {
        reg.write_raw(@intCast(value));
    }
};

const UART0_FBRD = struct {
    var reg: io.MMIORegister = io.MMIORegister.init(io.MMIO_BASE, 0x00201028);

    fn set(value: u16) void {
        reg.write_raw(@intCast(value));
    }
};

const UART0_CRFlags = enum(u4) {
    UARTEN = 0,
    SIREN = 1,
    SIRLP = 2,
    LBE = 7,
    TXE = 8,
    RXE = 9,
    DTR = 10,
    RTS = 11,
    Out1 = 12,
    Out2 = 13,
    RTSEN = 14,
    CTSEN = 15,
};

const UART0_CR = struct {
    var reg: io.MMIORegister = io.MMIORegister.init(io.MMIO_BASE, 0x00201030);

    fn set(flag: UART0_CRFlags) void {
        reg.set_raw(@intFromEnum(flag));
    }

    fn clearAll() void {
        reg.write_raw(0);
    }
};

const UARTWordLength = enum(u2) {
    FiveBits = 0b00,
    SixBits = 0b01,
    SevenBits = 0b10,
    EightBits = 0b11,
};

const UART0_LCRH = struct {
    var reg: io.MMIORegister = io.MMIORegister.init(io.MMIO_BASE, 0x0020102C);

    fn setWordLength(word_length: UARTWordLength) void {
        var val = reg.read_raw();
        val &= ~(@as(io.MMIORegister.RegisterType, 3) << 5);
        val |= @as(io.MMIORegister.RegisterType, @intFromEnum(word_length)) << 5;
        reg.write_raw(val);
    }

    fn setFifoEnabled(enabled: bool) void {
        var val = reg.read_raw();
        val &= ~(@as(io.MMIORegister.RegisterType, 1) << 4);
        val |= @as(io.MMIORegister.RegisterType, @intFromBool(enabled)) << 4;
        reg.write_raw(val);
    }

    fn setParityEnabled(enabled: bool) void {
        var val = reg.read_raw();
        val &= ~(@as(io.MMIORegister.RegisterType, 1) << 7);
        val |= @as(io.MMIORegister.RegisterType, @intFromBool(enabled)) << 7;
        reg.write_raw(val);
    }
};

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

const UART0_FR = struct {
    var reg: io.MMIORegister = io.MMIORegister.init(io.MMIO_BASE, 0x00201018);

    inline fn isSet(flag: UART0_FRFlags) bool {
        return reg.read().isSet(@intFromEnum(flag));
    }
};

const UART0_DR = struct {
    var reg: io.MMIORegister = io.MMIORegister.init(io.MMIO_BASE, 0x00201000);

    inline fn read_data() u8 {
        return @as(u8, @truncate(reg.read_raw()));
    }

    inline fn write_data(data: u8) void {
        reg.write_raw(@as(io.MMIORegister.RegisterType, data));
    }
};

pub const UART0 = struct {
    pub fn init() void {
        UART0_CR.clearAll(); // disable UART0 for configuration

        Mailbox.set_uart_clock(4000000) catch unreachable;

        // map uart to GPIO pins 14 & 15
        io.GPFSEL1.setFSEL14(io.GPIOFunction.Alt0);
        io.GPFSEL1.setFSEL15(io.GPIOFunction.Alt0);

        // disable pull up/down for pins 14 & 15
        io.GPPUD.set(io.GPPUDFunction.Off);
        util.wait_cycles(150);

        io.GPPUDCLK0.setPin(14);
        io.GPPUDCLK0.setPin(15);
        util.wait_cycles(150);
        io.GPPUDCLK0.clearAll();

        // clear interrupts
        UART0_ICR.clear_interrupts();

        // 115200 baud
        UART0_IBRD.set(2);
        UART0_FBRD.set(0xB);

        UART0_LCRH.setWordLength(UARTWordLength.EightBits);
        UART0_LCRH.setFifoEnabled(true);
        UART0_LCRH.setParityEnabled(true);

        UART0_CR.set(UART0_CRFlags.TXE);
        UART0_CR.set(UART0_CRFlags.RXE);
        UART0_CR.set(UART0_CRFlags.UARTEN);
    }

    pub fn send_char(char: u8) void {
        while (UART0_FR.isSet(UART0_FRFlags.TXFF)) {
            util.wait_cycles(1);
        }
        UART0_DR.write_data(char);
    }

    pub fn read_char() ?u8 {
        if (UART0_FR.isSet(UART0_FRFlags.RXFE)) {
            return null;
        } else {
            return UART0_DR.read_data();
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
