#!/bin/sh
#
# compiles specified source to risc-v rv32i binary
# extracts '.mem' file from binary to be included by the simulation
#
# tools used:
#       riscv64-elf-g++: 14.1.0
#   riscv64-elf-objcopy: 2.42
#   riscv64-elf-objdump: 2.42
#                   xxd: tinyxxd 1.3.7
#                   awk: 5.3.1
#
set -e

CC=riscv64-elf-g++
OBJCOPY=riscv64-elf-objcopy
OBJDUMP=riscv64-elf-objdump

SRC=$1
BIN=${SRC%.*}

# -mstrict-align \
$CC -std=c++23 \
    -march=rv32i \
    -mabi=ilp32 \
    -O0 \
    -ffreestanding \
    -nostartfiles \
    -nostdlib \
    -fno-pic \
    -Wfatal-errors \
    -Wall -Wextra -pedantic \
    -Wl,-Ttext=0x0 \
    -Wl,--no-relax \
    -fno-toplevel-reorder \
    -o $BIN $SRC

$OBJCOPY $BIN -O binary $BIN.bin
$OBJDUMP -Mnumeric,no-aliases -dr $BIN > $BIN.lst
xxd -p -c 1 -e $BIN.bin | awk '{print $2}' > $BIN.mem
ls -la $BIN.bin $BIN.mem $BIN.lst
rm $BIN
rm $BIN.bin
