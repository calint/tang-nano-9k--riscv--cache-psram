# "operating system" - osqa

## prerequisites
`riscv64-elf-gcc` toolchain

## build
`./make-fpga-flash-binary.sh` compiles `src/os.cpp` and generates:
* `os.bin` - binary to be flashed to FPGA
* `os.lst` - assembler with source annotations
* `os.dat` - data sections of binary
* `os` - elf file

`./make-console-application.sh` compiles `src/console_application.cpp` and generates:
* `console_application` - executable binary of console application

## configuration
`../configuration.py` is applied by `../configuration-apply.py` and generates files:
* `src/os_config.hpp` - addresses to LEDs, UART, SD card and top of memory
* `src/os_start.S` - setup stack before `os_common.hpp` `run()`

## src/
* `os_common.hpp` - common source for console and freestanding build
* `os_config.hpp` - see __configuration__
* `os_start.S` - see __configuration__
* `os.cpp` - source for freestanding build
* `console_application.cpp` - source for console build
* `lib/` - library

## qa-console/
* `test.sh` - qa `console_application`
  
## qa-emulator/
* `test.sh` - qa using emulator with firmware `os.bin` and SD card image `/notes/samples/sample.txt`
