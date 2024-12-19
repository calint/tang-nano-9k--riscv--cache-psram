#!/bin/sh
#
# tools used:
#   iverilog: Icarus Verilog version 12.0 (stable)
#        vvp: Icarus Verilog runtime version 12.0 (stable)
#
set -e
cd $(dirname "$0")

SRCPTH=../../src

cd $1
pwd

iverilog -g2005-sv -Winfloop -pfileline=1 -o iverilog.vvp -s testbench testbench.sv \
    $SRCPTH/bram.sv \
    $SRCPTH/cache.sv \
    $SRCPTH/ramio.sv \
    $SRCPTH/uarttx.sv \
    $SRCPTH/uartrx.sv \
    $SRCPTH/core.sv \
    $SRCPTH/registers.sv \
    $SRCPTH/emulators/burst_ram.sv \
    $SRCPTH/emulators/flash.sv

vvp iverilog.vvp
rm iverilog.vvp
