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

iverilog -g2012 -Winfloop -pfileline=1 -o iverilog.vvp -s testbench testbench.sv \
    $SRCPTH/bram.sv \
    $SRCPTH/cache.sv \
    $SRCPTH/uarttx.sv \
    $SRCPTH/uartrx.sv \
    $SRCPTH/ip/sd_reader.v \
    $SRCPTH/ip/sdcmd_ctrl.v \
    $SRCPTH/sdcard.sv \
    $SRCPTH/ramio.sv \
    $SRCPTH/registers.sv \
    $SRCPTH/core.sv \
    $SRCPTH/emulators/burst_ram.sv \
    $SRCPTH/emulators/flash.sv \
    $SRCPTH/emulators/sd_fake.v

vvp iverilog.vvp
rm iverilog.vvp
