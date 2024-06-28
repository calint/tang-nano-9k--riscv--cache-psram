#!/bin/sh
set -e
cd $(dirname "$0")

os/make-fpga-flash-binary.sh
openFPGALoader -b tangnano9k --verify --external-flash os/os.bin
