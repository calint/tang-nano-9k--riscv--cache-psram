ENTRY(_start)

SECTIONS
{
    . = 0x0;
    .text : {
        *(.text*)
    }
    .srodata : {
        *(.srodata*)
    }
    .rodata : {
        *(.rodata*)
    }
    .sdata : {
        *(.sdata*)
    }
    .data : {
        *(.data*)
    }
    __bss_start = .;
    .sbss : {
        *(.sbss*)
    }
    .bss : {
        *(.bss*)
    }
    __bss_end = .;
    __heap_start = .;
}
