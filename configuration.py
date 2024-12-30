#
# if file changed run `configuration-apply.py` and rebuild
#

BOARD_NAME = "tang_nano_9k"
# used when generating files

CLOCK_FREQUENCY_HZ = 27_000_000
# frequency of in clock (signal 'clk', specification)

CPU_FREQUENCY_HZ = 30_000_000
# frequency that CPU runs on

RAM_ADDRESS_BITWIDTH = 21
# 2 ^ 21 x 32 b = 8 MB SDRAM (specification)

RAM_ADDRESSING_MODE = 0
# amount of data stored per address (specification)
#    mode:
#       0: 1 B (byte addressed)
#       1: 2 B
#       2: 4 B
#       3: 8 B

UART_BAUD_RATE = 115200
# 115200 baud, 8 bits, 1 stop bit, no parity

CACHE_COLUMN_INDEX_BITWIDTH = 3
# 2 ^ 3 = 8 entries (32 B) per cache line

CACHE_LINE_INDEX_BITWIDTH = 5
# 2 ^ 5 * 32 = 1 KB unified instruction and data cache
# from 1 to 5: cache implemented with SSRAM
#           6: leads to excessive build time
#           7: cache implemented with some BSRAM
#           8: implemented with some BSRAM but fails to place

FLASH_TRANSFER_FROM_ADDRESS = 0
# flash read start address

FLASH_TRANSFER_BYTE_COUNT = 0x0020_0000
# number of bytes to transfer from flash at startup (2 MB)

STARTUP_WAIT_CYCLES = 1_000_000
# cycles delay at startup for flash to be initiated
