#!/bin/sh
set -e
cd $(dirname "$0")

SRCPTH=../../src
IDEPTH=~/.wine/drive_c/Gowin/Gowin_V1.9.9.03_x64/IDE/

verilator --language 1800-2017 --lint-only --Wall \
    $SRCPTH/bram.sv \
    $SRCPTH/cache.sv \
    $SRCPTH/ramio.sv \
    $SRCPTH/uarttx.sv \
    $SRCPTH/uartrx.sv \
    $SRCPTH/core.sv \
    $SRCPTH/registers.sv \
    $SRCPTH/configuration.sv \
    $SRCPTH/top.sv \
    $SRCPTH/gowin_rpll/gowin_rpll.v \
    $SRCPTH/psram_memory_interface_hs_v2/psram_memory_interface_hs_v2.vo \
    $IDEPTH/simlib/gw1n/prim_tsim.v
