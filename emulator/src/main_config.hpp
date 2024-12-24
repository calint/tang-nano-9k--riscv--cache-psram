#pragma once
#include <unistd.h>

// memory map
uint32_t constexpr LED = 0xffff'ffff;
uint32_t constexpr UART_OUT = 0xffff'fffe;
uint32_t constexpr UART_IN = 0xffff'fffd;
uint32_t constexpr MEMORY_TOP = 0x20'0000;
