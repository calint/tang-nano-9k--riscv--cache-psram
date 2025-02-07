## install riscv toolchain
sudo apt install gcc-riscv64-unknown-elf

## changes
uncomment the Ubuntu specific commands in `/os/make-fpga-flash-binary.sh`

## launch Gowin EDA
LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libfreetype.so ~/apps/gowin/IDE/bin/gw_ide $*

## launch command line Gowin build
LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libfreetype.so ~/apps/gowin/IDE/bin/gw_sh $*

