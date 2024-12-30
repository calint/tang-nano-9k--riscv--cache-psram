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

    __bss_start = .; /* declared as extern in os.cpp */
    .bss : {
        *(.bss*)
    }

    .sbss : {
        *(.sbss*)
    }
    __bss_end = .; /* declared as extern in os.cpp */

    __heap_start = .;
}
