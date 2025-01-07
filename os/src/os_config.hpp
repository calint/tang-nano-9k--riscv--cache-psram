// generated - do not edit (see `configuration.py`)
#pragma once
#define LED ((int volatile *)0xffff'fffc)
#define UART_OUT ((int volatile *)0xffff'fff8)
#define UART_IN ((int volatile *)0xffff'fff4)
#define SD_CARD_BUSY ((int volatile *)0xffff'fff0)
#define SD_CARD_READ_SECTOR ((int volatile *)0xffff'ffec)
#define SD_CARD_NEXT_BYTE ((int volatile *)0xffff'ffe8)
#define MEMORY_END 0x200000
