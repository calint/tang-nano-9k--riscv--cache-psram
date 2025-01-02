BOARD_NAME="tangnano9k"
# used when flashing the bitstream to the FPGA

BITSTREAM_FLASH_TO_EXTERNAL=0
# 0 to flash the bitstream to the internal flash, 1 for the external flash

BITSTREAM_FILE_MAX_SIZE_BYTES=4194304
# used to check if the bitstream size is within the limit of flash storage

FIRMWARE_FILE_MAX_SIZE_BYTES=4194304
# used to check if the bitstream size is within the limit of flash storage

FIRMWARE_FLASH_OFFSET=0x00000000
# used to specify the offset in the flash storage where the firmware will be written