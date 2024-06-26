#!/bin/python3
# generates configuration files for Verilog source and 'os'

import configuration as cfg

with open('os/os_start.S', 'w') as file:
    file.write('# generated - do not edit (see `configuration.py`)\n')
    file.write('.global _start\n')
    file.write('_start:\n')
    file.write('    li sp, {}\n'.format(hex(2**cfg.RAM_ADDRESS_BITWIDTH)))
    file.write('    jal ra, run\n')

with open('os/os_config.hpp', 'w') as file:
    file.write('// generated - do not edit (see `configuration.py`)\n')
    file.write('#define LED ((char volatile *)0xffffffff)\n')
    file.write('#define UART_OUT ((char volatile *)0xfffffffe)\n')
    file.write('#define UART_IN ((char volatile *)0xfffffffd)\n')
    file.write('#define MEMORY_TOP {}\n'.format(
        hex(2**cfg.RAM_ADDRESS_BITWIDTH)))

with open('src/configuration.sv', 'w') as file:
    file.write('// generated - do not edit (see `configuration.py`)\n')
    # file.write(
    #     '//  note: "localparam" not "parameter" to avoid warnings in Gowin EDA\n')
    file.write('\n')
    file.write('package configuration;\n')
    file.write('\n')
    file.write('  parameter int unsigned RAM_ADDRESS_BITWIDTH = {};\n'.format(
        cfg.RAM_ADDRESS_BITWIDTH))
    file.write('  parameter int unsigned CACHE_LINE_INDEX_BITWIDTH = {};\n'.format(
        cfg.CACHE_LINE_INDEX_BITWIDTH))
    file.write('  parameter int unsigned UART_BAUD_RATE = {};\n'.format(
        cfg.UART_BAUD_RATE))
    file.write('  parameter int unsigned FLASH_TRANSFER_BYTES = 32\'h{};\n'.format(
        f'{cfg.FLASH_TRANSFER_BYTES:08x}'))
    file.write('  parameter int unsigned STARTUP_WAIT_CYCLES = {};\n'.format(
        cfg.STARTUP_WAIT_CYCLES))
    file.write('\n')
    file.write('endpackage\n')

print("generated: src/configuration.sv, os/os_start.S, os/os_config.hpp")
