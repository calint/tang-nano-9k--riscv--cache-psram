#!/bin/sh
set -e
cd $(dirname "$0")

qa-console/test.sh

echo " * build fpga flash binary"
./make-fpga-flash-binary.sh

qa-emulator/test.sh
