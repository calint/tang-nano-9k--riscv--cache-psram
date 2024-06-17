#!/bin/python3
# generates configuration files for Verilog source and 'os'

import configuration as cfg

with open('os/os_start.S', 'w') as file:
    file.write('# generated - do not edit (see `configuration.py`)\n')
    file.write('.global _start\n')
    file.write('_start:\n')
    file.write('    li sp, {}\n'.format(hex(2**cfg.RAM_ADDRESS_WIDTH)))
    file.write('    jal ra, run\n')

with open('os/os_config.h', 'w') as file:
    file.write('// generated - do not edit (see `configuration.py`)\n')
    file.write('#define LED ((char volatile *)0xffffffff)\n')
    file.write('#define UART_OUT ((char volatile *)0xfffffffe)\n')
    file.write('#define UART_IN ((char volatile *)0xfffffffd)\n')
    file.write('#define MEMORY_TOP {}\n'.format(hex(2**cfg.RAM_ADDRESS_WIDTH)))

with open('src/Configuration.sv', 'w') as file:
    file.write('// generated - do not edit (see `configuration.py`)\n')
    file.write('`define RAM_ADDRESS_BITWIDTH {}\n'.format(cfg.RAM_ADDRESS_WIDTH))
    file.write('`define CACHE_LINE_IX_BITWIDTH {}\n'.format(cfg.CACHE_LINE_IX_BITWIDTH))
    file.write('`define UART_BAUD_RATE {}\n'.format(cfg.UART_BAUD_RATE))

print("generated: src/Configuration.v, os/os_start.S, os/os_config.h")
