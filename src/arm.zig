const std = @import("std");

extern const __bss_start: u8;
extern const __bss_end: u8;

pub fn zeroBSS() usize {
    const bss_size = @intFromPtr(&__bss_end) - @intFromPtr(&__bss_start);
    const bss_start: [*]volatile u8 = @constCast(@ptrCast(&__bss_start));
    const bss = bss_start[0..bss_size];

    @memset(
        bss,
        0,
    );
    return bss_size;
}
