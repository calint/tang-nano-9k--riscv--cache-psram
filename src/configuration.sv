// generated - do not edit (see `configuration.py`)

package configuration;

  parameter int unsigned CLOCK_FREQUENCY_HZ = 27000000;
  parameter int unsigned CPU_FREQUENCY_HZ = 30000000;
  parameter int unsigned RAM_ADDRESS_BITWIDTH = 21;
  parameter int unsigned RAM_ADDRESSING_MODE = 2;
  parameter int unsigned CACHE_COLUMN_INDEX_BITWIDTH = 3;
  parameter int unsigned CACHE_LINE_INDEX_BITWIDTH = 7;
  parameter int unsigned UART_BAUD_RATE = 115200;
  parameter int unsigned FLASH_TRANSFER_FROM_ADDRESS = 32'h00000000;
  parameter int unsigned FLASH_TRANSFER_BYTE_COUNT = 32'h00200000;
  parameter int unsigned STARTUP_WAIT_CYCLES = 1000000;

endpackage
