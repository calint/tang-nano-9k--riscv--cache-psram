#!/bin/sh
#
# * compiles specified source to risc-v binary
# * extracts 'mem' file from binary to be included by vivado
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
SRC=$1
BIN=${SRC%.*}

# -mstrict-align \
riscv32-unknown-elf-gcc \
	-O2 \
	-nostartfiles \
	-ffreestanding \
	-nostdlib \
	-fno-pic \
	-march=rv32i \
	-mabi=ilp32 \
	-Wfatal-errors \
	-Wall -Wextra -pedantic \
	-Wl,-Ttext=0x0 \
	-Wl,--no-relax \
	-fno-toplevel-reorder \
	$SRC -o $BIN

riscv32-unknown-elf-objcopy $BIN -O binary $BIN.bin
riscv32-unknown-elf-objdump -Mnumeric,no-aliases -dr $BIN > $BIN.lst
xxd -p -c 1 -e $BIN.bin | awk '{print $2}' > $BIN.mem
ls -la $BIN.bin $BIN.mem $BIN.lst
rm $BIN
rm $BIN.bin

