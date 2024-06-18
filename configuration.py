#
# if file changed run `configuration-generate.py` and rebuild
#

RAM_ADDRESS_WIDTH = 21
# 2^21 = 2 MB PSRAM

UART_BAUD_RATE = 9600
# 9600 baud, 8 bits, 1 stop bit, no parity

CACHE_LINE_IX_BITWIDTH = 5
# 2^5*32 = 1 KB unified instruction and data cache

FLASH_TRANSFER_BYTES_NUM = 0x0020_0000
# number of bytes to transfer from flash at startup (2 MB)

STARTUP_WAIT = 1_000_000
# cycles delay at startup for flash to be initiated