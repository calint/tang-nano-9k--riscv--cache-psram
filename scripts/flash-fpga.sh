#!/bin/sh
set -e
cd $(dirname "$0")

# default configuration
BOARD_NAME="tangnano9k"
BITSTREAM_FILE="impl/pnr/riscv.fs"

# override configuration
. ./configuration.sh

cd ..

echo
echo flashing $BOARD_NAME with file $BITSTREAM_FILE
echo

openFPGALoader --board $BOARD_NAME --write-flash "$BITSTREAM_FILE"
