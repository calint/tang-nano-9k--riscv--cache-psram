#!/bin/sh
# tools:
#   iverilog: Icarus Verilog version 12.0 (stable)
#        vvp: Icarus Verilog runtime version 12.0 (stable)
set -e
cd $(dirname "$0")

IDEPTH=~/.wine/drive_c/Gowin/Gowin_V1.9.9.03_x64/IDE/
SRCPTH=../src
IMPLPTH=../impl/pnr/

iverilog -g2005-sv -Winfloop -pfileline=1 -o iverilog.vvp -s Top \
    $IDEPTH/simlib/gw1n/prim_sim.v \
    $SRCPTH/psram_memory_interface_hs_v2/psram_memory_interface_hs_v2.vo \
    $SRCPTH/gowin_rpll/gowin_rpll.v \
    $SRCPTH/BESDPB.sv \
    $SRCPTH/Cache.sv \
    $SRCPTH/BurstRAM.sv \
    $SRCPTH/RAMIO.sv \
    $SRCPTH/UartRx.sv \
    $SRCPTH/UartTx.sv \
    $SRCPTH/Top.sv

vvp iverilog.vvp
rm iverilog.vvp
