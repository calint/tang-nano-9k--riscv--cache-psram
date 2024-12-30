#
# if file changed run `configuration-apply.py` and rebuild
#

RAM_ADDRESS_BITWIDTH = 21
# 2 ^ 21 = 2 MB PSRAM (according to hardware)

UART_BAUD_RATE = 115200
# 115200 baud, 8 bits, 1 stop bit, no parity

CACHE_LINE_INDEX_BITWIDTH = 7
# 2 ^ 7 * 32 = 4 KB unified instruction and data cache
# from 1 to 5: cache implemented with SSRAM
#           6: leads to excessive build time
#           7: cache implemented with some BSRAM
#           8: implemented with some BSRAM but fails to place

FLASH_TRANSFER_BYTES = 0x0020_0000
# number of bytes to transfer from flash at startup (2 MB)

STARTUP_WAIT_CYCLES = 1_000_000
# cycles delay at startup for flash to be initiated
