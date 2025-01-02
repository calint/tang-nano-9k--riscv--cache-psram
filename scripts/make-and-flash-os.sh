#!/bin/sh
set -e
cd $(dirname "$0")

# default configuration
FIRMWARE_FILE="os/os.bin"
FIRMWARE_FLASH_OFFSET=0x00000000

# override configuration
. ./configuration.sh

cd ..

echo
echo "building firmware"

os/make-fpga-flash-binary.sh

echo
echo flashing $FIRMWARE_FILE to $BOARD_NAME at offset $FIRMWARE_FLASH_OFFSET
echo

openFPGALoader --offset $FIRMWARE_FLASH_OFFSET --verify --external-flash "$FIRMWARE_FILE"
