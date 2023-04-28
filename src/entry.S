.section ".text.boot"

.global _entry

_entry:
    // read cpu id, stop slave cores
    mrs     x1, mpidr_el1
    and     x1, x1, #3
    cbz     x1, 2f
    // cpu id > 0, stop
1:  wfe
    b       1b
2:  // cpu id == 0

/* Zero-out the BSS */
    ldr x26, =__bss_start
    ldr x27, =__bss_end
bss_loop:
    str	xzr, [x26], #8
    cmp	x26, x27
    b.lo	bss_loop

    // set stack before our code
    ldr     x1, =_entry
    mov     sp, x1

    // jump to Rust code, should not return
    bl      remoter_main
    // for failsafe, halt this core too
    b       1b