// generated - do not edit (see `configuration.py`)
#pragma once
#define LED ((unsigned volatile *)0xffff'fffc)
#define UART_OUT ((int volatile *)0xffff'fff8)
#define UART_IN ((int volatile *)0xffff'fff4)
#define SDCARD_BUSY ((int volatile *)0xffff'fff0)
#define SDCARD_READ_SECTOR ((unsigned volatile *)0xffff'ffec)
#define SDCARD_NEXT_BYTE ((int volatile *)0xffff'ffe8)
#define SDCARD_STATUS ((unsigned volatile *)0xffff'ffe4)
#define SDCARD_WRITE_SECTOR ((unsigned volatile *)0xffff'ffe0)
#define MEMORY_END 0x800000
