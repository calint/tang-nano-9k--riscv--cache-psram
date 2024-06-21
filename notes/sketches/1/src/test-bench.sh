#!/bin/sh
# tools:
#   iverilog: Icarus Verilog version 12.0 (stable)
#        vvp: Icarus Verilog runtime version 12.0 (stable)
set -e
cd $(dirname "$0")

SRCPTH=.

iverilog -g2005-sv -Winfloop -pfileline=1 -o iverilog.vvp -s TestBench TestBench.sv \
    $SRCPTH/Device.sv

vvp iverilog.vvp
rm iverilog.vvp
