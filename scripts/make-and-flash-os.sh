#!/bin/sh
set -e
cd $(dirname "$0")

cd ..

os/make-fpga-flash-binary.sh
openFPGALoader --verify --external-flash os/os.bin
