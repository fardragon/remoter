pub fn wait_cycles(cycles: usize) void {
    var i: usize = 0;
    while (i < cycles) {
        asm volatile ("nop");
        i += 1;
    }
}
