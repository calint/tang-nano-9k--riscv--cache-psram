#!/bin/sh
# tools:
#   iverilog: Icarus Verilog version 12.0 (stable)
#        vvp: Icarus Verilog runtime version 12.0 (stable)
set -e
cd $(dirname "$0")

IDEPTH=~/.wine/drive_c/Gowin/Gowin_V1.9.9.03_x64/IDE/
SRCPTH=../../src
IMPLPTH=../../impl/pnr/

cd $1
pwd

# switch for system verilog
# -g2005-sv

iverilog -g2012 -Winfloop -pfileline=1 -o iverilog.vvp -s TestBench TestBench.v \
    $IDEPTH/simlib/gw1n/prim_tsim.v \
    $SRCPTH/psram_memory_interface_hs_v2/psram_memory_interface_hs_v2.vo \
    $SRCPTH/gowin_rpll/gowin_rpll.v \
    $IMPLPTH/tang-nano-9k--step-11.vo

vvp iverilog.vvp
rm iverilog.vvp
