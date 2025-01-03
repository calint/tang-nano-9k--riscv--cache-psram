# generated - do not edit (see `configuration.py`)

#
# scripts related configurations
#

BOARD_NAME="tangnano9k"
# used when flashing the bitstream to the FPGA and generating SDC file

BITSTREAM_FILE="impl/pnr/riscv.fs"
# location of the bitstream file relative to project root

BITSTREAM_FLASH_TO_EXTERNAL=0
# 0 to flash the bitstream to the internal flash, 1 for the external flash

BITSTREAM_FILE_MAX_SIZE_BYTES=4194304
# used to check if the bitstream file size is within the limit of flash storage

FIRMWARE_FILE="os/os.bin"
# location of the firmware file relative to project root

FIRMWARE_FILE_MAX_SIZE_BYTES=4194304
# used to check if the firmware file size is within the limit of flash storage

FIRMWARE_FLASH_OFFSET=0x00000000
# used to specify the offset in the flash storage where the firmware will be written
