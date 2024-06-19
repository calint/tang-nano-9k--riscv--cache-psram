#!/bin/sh
# tools:
#   iverilog: Icarus Verilog version 12.0 (stable)
#        vvp: Icarus Verilog runtime version 12.0 (stable)
set -e
cd $(dirname "$0")

SRCPTH=../../src

cd $1
pwd

iverilog -g2005-sv -Winfloop -pfileline=1 -o iverilog.vvp -s TestBench TestBench.sv \
    $SRCPTH/BESDPB.sv \
    $SRCPTH/Cache.sv \
    $SRCPTH/RAMIO.sv \
    $SRCPTH/UartTx.sv \
    $SRCPTH/UartRx.sv \
    $SRCPTH/Core.sv \
    $SRCPTH/Registers.sv \
    $SRCPTH/emulators/BurstRAM.sv \
    $SRCPTH/emulators/Flash.sv

vvp iverilog.vvp
rm iverilog.vvp
