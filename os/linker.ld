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

    .data : {
        *(.data*)
    }
    
    .bss : {
        __bss_start = .;
        *(.bss*)
        *(COMMON)
        __bss_end = .;
    }
}
