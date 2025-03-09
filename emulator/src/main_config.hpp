// generated - do not edit (see `configuration.py`)
#pragma once
#include <cstdint>

namespace osqa {

// memory map
uint32_t constexpr led = 0xffff'fffc;
uint32_t constexpr uart_out = 0xffff'fff8;
uint32_t constexpr uart_in = 0xffff'fff4;
uint32_t constexpr sdcard_busy = 0xffff'fff0;
uint32_t constexpr sdcard_read_sector = 0xffff'ffec;
uint32_t constexpr sdcard_next_byte = 0xffff'ffe8;
uint32_t constexpr sdcard_status = 0xffff'ffe4;
uint32_t constexpr sdcard_write_sector = 0xffff'ffe0;
uint32_t constexpr io_addresses_start = 0xffff'ffe0;
uint32_t constexpr memory_end = 0x200000;

} // namespace osqa
