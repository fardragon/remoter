const std = @import("std");

pub const MMIO_BASE: usize = 0x3F_000_000;

pub const MMIORegister = struct {
    pub const RegisterType = u32;

    raw_ptr: *volatile RegisterType,

    pub fn init(base: usize, offset: usize) MMIORegister {
        return MMIORegister{ .raw_ptr = @as(*volatile u32, @ptrFromInt(base + offset)) };
    }

    pub fn read_raw(self: MMIORegister) RegisterType {
        return self.raw_ptr.*;
    }

    pub fn write_raw(self: MMIORegister, value: RegisterType) void {
        self.raw_ptr.* = value;
    }

    pub fn set_raw(self: MMIORegister, value: RegisterType) void {
        self.raw_ptr.* = self.raw_ptr.* | value;
    }

    pub fn read(self: MMIORegister) std.bit_set.IntegerBitSet(@bitSizeOf(RegisterType)) {
        return .{
            .mask = self.read_raw(),
        };
    }
};

pub const GPIOFunction = enum(u3) {
    Input = 0,
    Output = 1,
    Alt0 = 4,
    Alt1 = 5,
    Alt2 = 6,
    Alt3 = 7,
    Alt4 = 3,
    Alt5 = 2,
};

pub const GPFSEL1 = struct {
    var reg: MMIORegister = MMIORegister.init(MMIO_BASE, 0x00200004);

    inline fn set(offset: u5, value: GPIOFunction) void {
        var val = reg.read_raw();
        val &= ~(@as(MMIORegister.RegisterType, 7) << offset);
        val |= @as(MMIORegister.RegisterType, @intFromEnum(value)) << offset;
        reg.write_raw(val);
    }

    pub fn setFSEL14(value: GPIOFunction) void {
        return set(12, value);
    }

    pub fn setFSEL15(value: GPIOFunction) void {
        return set(15, value);
    }
};

pub const GPPUDFunction = enum(u2) {
    Off = 0,
    PullDown = 1,
    PullUp = 2,
    Reserved = 3,
};

pub const GPPUD = struct {
    var reg: MMIORegister = MMIORegister.init(MMIO_BASE, 0x00200094);

    pub fn set(value: GPPUDFunction) void {
        reg.write_raw(@intCast(@intFromEnum(value)));
    }
};

pub const GPPUDCLK0 = struct {
    var reg: MMIORegister = MMIORegister.init(MMIO_BASE, 0x00200098);

    pub fn setPin(pin: u5) void {
        reg.write_raw(@intCast(@as(MMIORegister.RegisterType, 1) << pin));
    }

    pub fn clearAll() void {
        reg.write_raw(0);
    }
};
