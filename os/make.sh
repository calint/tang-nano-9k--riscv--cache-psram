#!/bin/sh
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

PATH=$PATH:~/riscv/install/rv32i/bin
BIN=os

riscv32-unknown-elf-gcc \
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
	os_start.S os.c -o $BIN

#	-Wpadded \

riscv32-unknown-elf-objcopy $BIN -O binary $BIN.bin

chmod -x $BIN.bin

riscv32-unknown-elf-objdump -Mnumeric,no-aliases --source-comment -Sr $BIN > $BIN.lst
# riscv32-unknown-elf-objdump --source-comment -Sr $BIN > $BIN.lst

# print 4 bytes at a time as hex in little endian mode
xxd -c 4 -e $BIN.bin | awk '{print $2}' > $BIN.mem
xxd -c 1 -e $BIN.bin | awk '{print $2}' > $BIN.flash

rm $BIN

ls -l $BIN.bin $BIN.lst $BIN.mem $BIN.flash
