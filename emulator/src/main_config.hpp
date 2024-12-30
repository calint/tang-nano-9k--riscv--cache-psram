// generated - do not edit (see `configuration.py`)
#pragma once
#include <cstdint>

namespace osqa {

// memory map
std::uint32_t constexpr led = 0xffff'fffc;
std::uint32_t constexpr uart_out = 0xffff'fff8;
std::uint32_t constexpr uart_in = 0xffff'fff4;
std::uint32_t constexpr memory_end = 0x200000;

} // namespace osqa
