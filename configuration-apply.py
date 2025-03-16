#!/bin/python3
# generates configuration files for Verilog source, 'os', 'emulator' and clock constraints
import configuration as cfg
import os

script_dir = os.path.dirname(os.path.realpath(__file__))
os.chdir(script_dir)

memory_end_address = 2 ** (cfg.RAM_ADDRESS_BITWIDTH + cfg.RAM_ADDRESSING_MODE)

with open("os/src/os_start.S", "w") as file:
    file.write("# generated - do not edit (see `configuration.py`)\n")
    file.write(".global _start\n")
    file.write("_start:\n")
    file.write(f"    li sp, {hex(memory_end_address)}\n")
    file.write("    j run\n")

with open("os/src/os_config.hpp", "w") as file:
    file.write("// generated - do not edit (see `configuration.py`)\n")
    file.write("#pragma once\n")
    file.write("#define LED ((unsigned volatile *)0xffff'fffc)\n")
    file.write("#define UART_OUT ((int volatile *)0xffff'fff8)\n")
    file.write("#define UART_IN ((int volatile *)0xffff'fff4)\n")
    file.write("#define SDCARD_BUSY ((int volatile *)0xffff'fff0)\n")
    file.write("#define SDCARD_READ_SECTOR ((unsigned volatile *)0xffff'ffec)\n")
    file.write("#define SDCARD_NEXT_BYTE ((int volatile *)0xffff'ffe8)\n")
    file.write("#define SDCARD_STATUS ((unsigned volatile *)0xffff'ffe4)\n")
    file.write("#define SDCARD_WRITE_SECTOR ((unsigned volatile *)0xffff'ffe0)\n")
    file.write(f"#define MEMORY_END {hex(memory_end_address)}\n")

with open("emulator/src/main_config.hpp", "w") as file:
    file.write("// generated - do not edit (see `configuration.py`)\n")
    file.write("#pragma once\n")
    file.write("#include <cstdint>\n\n")
    file.write("namespace osqa {\n\n")
    file.write("// memory map\n")
    file.write("std::uint32_t constexpr led = 0xffff'fffc;\n")
    file.write("std::uint32_t constexpr uart_out = 0xffff'fff8;\n")
    file.write("std::uint32_t constexpr uart_in = 0xffff'fff4;\n")
    file.write("std::uint32_t constexpr sdcard_busy = 0xffff'fff0;\n")
    file.write("std::uint32_t constexpr sdcard_read_sector = 0xffff'ffec;\n")
    file.write("std::uint32_t constexpr sdcard_next_byte = 0xffff'ffe8;\n")
    file.write("std::uint32_t constexpr sdcard_status = 0xffff'ffe4;\n")
    file.write("std::uint32_t constexpr sdcard_write_sector = 0xffff'ffe0;\n")
    file.write("std::uint32_t constexpr io_addresses_start = 0xffff'ffe0;\n")
    file.write(f"std::uint32_t constexpr memory_end = {hex(memory_end_address)};\n")
    file.write("\n} // namespace osqa\n")

with open("src/configuration.sv", "w") as file:
    file.write("// generated - do not edit (see `configuration.py`)\n")
    file.write("\n")
    file.write("package configuration;\n")
    file.write("\n")
    file.write(
        f"  parameter int unsigned CLOCK_FREQUENCY_HZ = {cfg.CLOCK_FREQUENCY_HZ};\n"
    )
    file.write(f"  parameter int unsigned CPU_FREQUENCY_HZ = {cfg.CPU_FREQUENCY_HZ};\n")
    file.write(
        f"  parameter int unsigned RAM_ADDRESS_BITWIDTH = {cfg.RAM_ADDRESS_BITWIDTH};\n"
    )
    file.write(
        f"  parameter int unsigned RAM_ADDRESSING_MODE = {cfg.RAM_ADDRESSING_MODE};\n"
    )
    file.write(
        f"  parameter int unsigned CACHE_COLUMN_INDEX_BITWIDTH = {cfg.CACHE_COLUMN_INDEX_BITWIDTH};\n"
    )
    file.write(
        f"  parameter int unsigned CACHE_LINE_INDEX_BITWIDTH = {cfg.CACHE_LINE_INDEX_BITWIDTH};\n"
    )
    file.write(f"  parameter int unsigned UART_BAUD_RATE = {cfg.UART_BAUD_RATE};\n")
    file.write(
        f"  parameter int unsigned FLASH_TRANSFER_FROM_ADDRESS = 32'h{cfg.FLASH_TRANSFER_FROM_ADDRESS:08x};\n"
    )
    file.write(
        f"  parameter int unsigned FLASH_TRANSFER_BYTE_COUNT = 32'h{cfg.FLASH_TRANSFER_BYTE_COUNT:08x};\n"
    )
    file.write(
        f"  parameter int unsigned STARTUP_WAIT_CYCLES = {cfg.STARTUP_WAIT_CYCLES};\n"
    )
    file.write("\n")
    file.write("endpackage\n")

with open(cfg.BOARD_NAME + ".sdc", "w") as file:
    file.write("// generated - do not edit (see `configuration.py`)\n")
    file.write("\n")
    clock_mHz = cfg.CLOCK_FREQUENCY_HZ / 1000000
    clock_period = 1 / clock_mHz * 1000
    clock_wave_form = clock_period / 2
    file.write(f"// {clock_mHz} MHz\n")
    file.write(
        f"create_clock -name clk -period {clock_period:.4f} -waveform {{0 {clock_wave_form:.4f}}} [get_ports {{clk}}]\n"
    )

with open("scripts/configuration.sh", "w") as file:
    file.write("# generated - do not edit (see `configuration.py`)\n")
    file.write("\n")
    file.write("#\n")
    file.write("# scripts related configurations\n")
    file.write("#\n")
    file.write("\n")
    file.write(f'BOARD_NAME="{cfg.BOARD_NAME}"\n')
    file.write(
        "# used when flashing the bitstream to the FPGA and generating SDC file\n"
    )
    file.write("\n")
    file.write(f'BITSTREAM_FILE="{cfg.BITSTREAM_FILE}"\n')
    file.write("# location of the bitstream file relative to project root\n")
    file.write("\n")
    file.write(f"BITSTREAM_FLASH_TO_EXTERNAL={int(cfg.BITSTREAM_FLASH_TO_EXTERNAL)}\n")
    file.write(
        "# 0 to flash the bitstream to the internal flash, 1 for the external flash\n"
    )
    file.write("\n")
    file.write(f"BITSTREAM_FILE_MAX_SIZE_BYTES={cfg.BITSTREAM_FILE_MAX_SIZE_BYTES}\n")
    file.write(
        "# used to check if the bitstream file size is within the limit of flash storage\n"
    )
    file.write("\n")
    file.write(f'FIRMWARE_FILE="{cfg.FIRMWARE_FILE}"\n')
    file.write("# location of the firmware file relative to project root\n")
    file.write("\n")
    file.write(f"FIRMWARE_FILE_MAX_SIZE_BYTES={cfg.FIRMWARE_FILE_MAX_SIZE_BYTES}\n")
    file.write(
        "# used to check if the firmware file size is within the limit of flash storage\n"
    )
    file.write("\n")
    file.write(f"FIRMWARE_FLASH_OFFSET=0x{cfg.FIRMWARE_FLASH_OFFSET:08x}\n")
    file.write(
        "# used to specify the offset in the flash storage where the firmware will be written\n"
    )

print(
    f"generated:\n * /{cfg.BOARD_NAME}.sdc\n * /src/configuration.sv\n * /os/src/os_start.S\n * /os/src/os_config.hpp\n * /emulator/src/main_config.hpp\n * /scripts/configuration.sh"
)
