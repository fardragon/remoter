ENTRY(_entry);

SECTIONS
{
    . = 0x80000;

    .text :
    {
        KEEP(*(.text.boot)) *(.text .text.*)
    }

    .rodata :
    {
        *(.rodata .rodata.*)
    }

    PROVIDE(_data = .);
    .data :
    {
        *(.data .data.*)
    }

    .bss (NOLOAD) : {
        . = ALIGN(16);
        __bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        __bss_end = .;
    }

   /DISCARD/ : { *(.comment) *(.gnu*) *(.note*) *(.eh_frame*) }
}