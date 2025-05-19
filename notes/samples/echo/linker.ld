ENTRY(_start)

SECTIONS
{
    . = 0x0;

    .text : {
        *(.text*)
    }

    .rodata : {
        *(.rodata*)
    }

    .srodata : {
        *(.srodata*)
    }

    .data : {
        *(.data*)
    }

    .sdata : {
        *(.sdata*)
    }

    __bss_start = .;
    .bss : {
        *(.bss*)
    }

    .sbss : {
        *(.sbss*)
    }
    __bss_end = .;

    __heap_start = .;
}
