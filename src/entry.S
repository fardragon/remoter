.section ".text.boot"

.global _start

_start:
    // save arguments in registers (we will need them later for the new kernel)
    // I chose x10-x13 because instructions generated from C by gcc does not
    // touch them. You can check that with "aarch64-elf-objdump -d kernel8.elf"
    // TODO: verify
    mov     x10, x0
    mov     x11, x1
    mov     x12, x2
    mov     x13, x3

    ldr     x1, =0x80000
    ldr     x2, =_start
    ldr     w3, =__loader_size
1:  ldr     x4, [x1], #8
    str     x4, [x2], #8
    sub     w3, w3, #1
    cbnz    w3, 1b


    // set stack before our code
    ldr     x1, =_start
    mov     sp, x1

    // jump to zig code, should not return
    bl      __remoter_main_offset
    // for failsafe, halt this core too
hang:
    wfe
    b       hang