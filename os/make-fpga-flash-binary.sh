#!/bin/sh
#
# builds binary to be flashed on FPGA
#
# tools used:
#       riscv64-elf-g++: 14.1.0
#   riscv64-elf-objcopy: 2.42
#   riscv64-elf-objdump: 2.42
#
set -e
cd $(dirname "$0")

BIN=os

CC=riscv64-elf-g++
OBJCOPY=riscv64-elf-objcopy
OBJDUMP=riscv64-elf-objdump

$CC -std=c++23 \
    -O3 \
    -g \
    -march=rv32i \
    -mabi=ilp32 \
    -ffreestanding \
    -nostdlib \
    -fno-toplevel-reorder \
    -Wfatal-errors \
    -Wall -Wextra -pedantic \
    -Wconversion \
    -Wshadow \
    -Wno-unused-function \
    -Wno-unused-parameter \
    -Wno-stringop-overflow \
    -Wl,-T,linker.ld \
    -Wl,--no-warn-rwx-segment \
    -o $BIN \
    src/os_start.S src/os.cpp

# see "man g++"" for these optional options:
#    -fno-pic \
#    -mstrict-align \
# see "man ld" for:
#    -Wl,--no-relax \

rm $BIN.bin $BIN.lst $BIN.dat || true

$OBJCOPY $BIN -O binary $BIN.bin

chmod -x $BIN.bin

# $OBJDUMP -Mnumeric,no-aliases --source-comment -Sr $BIN > $BIN.lst
$OBJDUMP --source-comment -Sr $BIN > $BIN.lst
$OBJDUMP -s --section=.rodata --section=.srodata --section=.data --section=.sdata --section=.bss $BIN > $BIN.dat

#rm $BIN

ls -l $BIN.bin $BIN.lst $BIN.dat
