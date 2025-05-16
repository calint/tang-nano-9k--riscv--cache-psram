#!/bin/sh
# tools used:
#                   g++: 14.2.1
#       riscv64-elf-g++: 14.1.0
#   riscv64-elf-objcopy: 2.42
#   riscv64-elf-objdump: 2.42
#
set -e
cd $(dirname "$0")

echo " * build rv32i for tests"

CMD="g++ -std=c++23 -O3 -fno-rtti -fno-exceptions -Wfatal-errors -Werror -Wall -Wextra -Wpedantic \
    -Wconversion -Wsign-conversion -Wswitch-default -Wimplicit-fallthrough \
    -Wshadow -Wlogical-op -Wnon-virtual-dtor -Wcast-align -Woverloaded-virtual \
    -Wduplicated-cond -Wduplicated-branches -Wnull-dereference -Wuseless-cast \
    -Wdouble-promotion -Wmisleading-indentation -Wformat=2 \
    -o osqa-test main.cpp"
#echo
#echo $CMD
#echo
$CMD

ls -l --color osqa-test

#
# compile test cases
#
CC=riscv64-elf-g++
OBJCOPY=riscv64-elf-objcopy
OBJDUMP=riscv64-elf-objdump

SRC=ram.S
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

rm $BIN

./osqa-test

echo "test: PASSED"