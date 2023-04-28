.section ".text.boot"

.global _entry

_entry:
    // set stack before our code
    ldr     x1, =_entry
    mov     sp, x1

    // jump to zig code, should not return
    bl      remoter_main
    // for failsafe, halt this core too
hang:
    wfe
    b       hang