// generated - do not edit (see `configuration.py`)
#pragma once
#include <cstdint>

namespace osqa {

// memory map
std::uint32_t constexpr led = 0xffff'fffc;
std::uint32_t constexpr uart_out = 0xffff'fff8;
std::uint32_t constexpr uart_in = 0xffff'fff4;
std::uint32_t constexpr sdcard_busy = 0xffff'fff0;
std::uint32_t constexpr sdcard_read_sector = 0xffff'ffec;
std::uint32_t constexpr sdcard_next_byte = 0xffff'ffe8;
std::uint32_t constexpr sdcard_status = 0xffff'ffe4;
std::uint32_t constexpr sdcard_write_sector = 0xffff'ffe0;
std::uint32_t constexpr io_addresses_start = 0xffff'ffe0;
std::uint32_t constexpr memory_end = 0x800000;

} // namespace osqa
