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

    .bss : {
        __bss_start = .;
        *(.bss*)
        __bss_end = .;
    }

    __heap_start = .;
}
