#!/bin/sh
set -e
cd $(dirname "$0")

. ./configuration.sh

cd ..

echo
echo "programming board '$BOARD_NAME' with bitstream file '$BITSTREAM_FILE'"
echo

openFPGALoader --board $BOARD_NAME "$BITSTREAM_FILE"
