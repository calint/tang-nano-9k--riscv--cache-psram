#!/bin/sh
set -e
cd $(dirname "$0")

# default configuration
BOARD_NAME="tangnano9k"
BITSTREAM_FILE="impl/pnr/riscv.fs"

. ./configuration.sh

cd ..

echo
echo "programming board '$BOARD_NAME' with file '$BITSTREAM_FILE'"
echo

openFPGALoader --board $BOARD_NAME "$BITSTREAM_FILE"
