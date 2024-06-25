#!/bin/bash
set -e
cd $(dirname "$0")

cd os/ && 
./make-fpga-flash-binary.sh && 
cd .. && 
openFPGALoader -b tangnano9k --external-flash os/os.bin
