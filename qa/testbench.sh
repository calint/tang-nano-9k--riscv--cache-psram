#!/bin/sh
#
# tools used:
#   iverilog: Icarus Verilog version 13.0 (stable) (v13_0-dirty)
#        vvp: Icarus Verilog runtime version 13.0 (stable) (v13_0-dirty)
#
set -e
cd $(dirname "$0")

SRCPTH=../../src

cd $1
pwd

iverilog -g2012 -Winfloop -pfileline=1 -o iverilog.vvp -s testbench testbench.sv \
    $SRCPTH/bram.sv \
    $SRCPTH/cache.sv \
    $SRCPTH/uarttx.sv \
    $SRCPTH/uartrx.sv \
    $SRCPTH/ip/regymm/sd_controller.v \
    $SRCPTH/sdcard.sv \
    $SRCPTH/ramio.sv \
    $SRCPTH/registers.sv \
    $SRCPTH/core.sv \
    $SRCPTH/emulators/burst_ram.sv \
    $SRCPTH/emulators/flash.sv

vvp iverilog.vvp
rm iverilog.vvp
