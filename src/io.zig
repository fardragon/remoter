const std = @import("std");

pub const MMIO_BASE: usize = 0x3F_000_000;

pub const GPFSEL1: MMIORegister = MMIORegister.init(MMIO_BASE, 0x00200004);
pub const GPPUD: MMIORegister = MMIORegister.init(MMIO_BASE, 0x00200094);
pub const GPPUDCLK0: MMIORegister = MMIORegister.init(MMIO_BASE, 0x00200098);

pub const MMIORegister = struct {
    pub const RegisterType = u32;
    const RegisterTypeSize = @bitSizeOf(RegisterType);

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

    pub fn read(self: MMIORegister) std.bit_set.IntegerBitSet(RegisterTypeSize) {
        return .{
            .mask = self.read_raw(),
        };
    }
};
