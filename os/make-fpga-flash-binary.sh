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

# arch linux
CC=riscv64-elf-g++
OBJCOPY=riscv64-elf-objcopy
OBJDUMP=riscv64-elf-objdump

# ubuntu 24.04
CC=riscv64-unknown-elf-g++
OBJCOPY=riscv64-unknown-elf-objcopy
OBJDUMP=riscv64-unknown-elf-objdump

BIN=os

$CC -std=c++23 \
    -march=rv32i \
    -mabi=ilp32 \
    -Os \
    -g \
    -ffreestanding \
    -nostdlib \
    -fno-rtti \
    -fno-exceptions \
    -fimplicit-constexpr \
    -fno-toplevel-reorder \
    -Wfatal-errors \
    -Werror \
    -Wall -Wextra -Wpedantic \
    -Wshadow \
    -Wnon-virtual-dtor \
    -Wcast-align \
    -Woverloaded-virtual \
    -Wconversion \
    -Wsign-conversion \
    -Wmisleading-indentation \
    -Wduplicated-cond \
    -Wduplicated-branches \
    -Wlogical-op \
    -Wnull-dereference \
    -Wuseless-cast \
    -Wdouble-promotion \
    -Wformat=2 \
    -Wimplicit-fallthrough \
    -Wno-stringop-overflow \
    -Wno-unused-function \
    -Wno-unused-parameter \
    -Wl,-T,linker.ld \
    -Wl,--no-warn-rwx-segment \
    -o $BIN \
    src/os_start.S src/os.cpp

# see "man g++"" for these optional options:
#    -fno-pic \
#    -fPIC \
#    -mstrict-align \
# see "man ld" for:
#    -Wl,--no-relax \

rm -f $BIN.bin $BIN.lst $BIN.dat

$OBJCOPY $BIN -O binary $BIN.bin

chmod -x $BIN.bin

#$OBJDUMP -Mnumeric,no-aliases --source-comment -Sr $BIN > $BIN.lst
$OBJDUMP --source-comment -Sr $BIN > $BIN.lst
$OBJDUMP -s --section=.rodata --section=.srodata --section=.data --section=.sdata --section=.bss --section=.sbss $BIN > $BIN.dat || true

#rm $BIN

ls --color -l $BIN.bin $BIN.lst $BIN.dat
