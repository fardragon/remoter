__link_offset = 0x1000000;

SECTIONS
{
    . = 0x80000 + __link_offset;
    PROVIDE(_code = .);

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
    _end = .;
   /DISCARD/ : { *(.comment) *(.gnu*) *(.note*) *(.eh_frame*) }
}

__loader_size = (_end - _code)>>3;
__remoter_main_offset = remoter_main + __link_offset;