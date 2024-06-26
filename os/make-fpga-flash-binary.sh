#!/bin/sh
#
# builds binary to be flashed on FPGA
#
# tools used:
#       riscv32-unknown-elf-gcc: (g2ee5e430018) 12.2.0
#   riscv32-unknown-elf-objcopy: GNU objcopy (GNU Binutils) 2.40.0.20230214
#   riscv32-unknown-elf-objdump: GNU objdump (GNU Binutils) 2.40.0.2023021
#                           xxd: 2022-01-14 by Juergen Weigert et al.
#                           awk: GNU Awk 5.2.1, API 3.2, PMA Avon 8-g1, (GNU MPFR 4.2.1, GNU MP 6.3.0)
#
# installing toolchain:
#   RISC-V GNU Compiler Toolchain
#   https://github.com/riscv-collab/riscv-gnu-toolchain
#   ./configure --prefix=~/riscv/install --with-arch=rv32i --with-abi=ilp32
#
#   Compiling Freestanding RISC-V Programs
#   https://www.youtube.com/watch?v=ODn7vnWOptM
#
#   RISC-V Assembly Language Programming: A.1 The GNU Toolchain
#   https://github.com/johnwinans/rvalp/releases/download/v0.14/rvalp.pdf
#
set -e
cd $(dirname "$0")

PATH=$PATH:~/riscv/install/rv32i/bin
BIN=os

riscv32-unknown-elf-g++ -std=c++23 \
	-O0 \
	-g \
	-nostartfiles \
	-ffreestanding \
	-nostdlib \
	-fno-toplevel-reorder \
	-fno-pic \
	-march=rv32i \
	-mabi=ilp32 \
	-mstrict-align \
	-Wfatal-errors \
	-Wall -Wextra -pedantic \
	-Wconversion \
	-Wshadow \
	-Wl,-Ttext=0x0 \
	-Wl,--no-relax \
	os_start.S os.cpp -o $BIN

#	-Wpadded \

rm $BIN.bin $BIN.lst $BIN.dat || true

riscv32-unknown-elf-objcopy $BIN -O binary $BIN.bin

chmod -x $BIN.bin

# riscv32-unknown-elf-objdump -Mnumeric,no-aliases --source-comment -Sr $BIN > $BIN.lst
riscv32-unknown-elf-objdump --source-comment -Sr $BIN > $BIN.lst || true
riscv32-unknown-elf-objdump -s --section=.rodata --section=.data --section=.bss $BIN > $BIN.dat || true

rm $BIN

ls -l $BIN.bin $BIN.lst $BIN.dat
