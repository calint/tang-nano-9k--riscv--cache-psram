# quality assurance

* `./qa.sh` to run numbered tests
* `./testbench.sh <num>` to run a specific test
* `compile.sh` script to compile test case source; e.g. `cd 7 && ../compile.sh ram.S`
  - assumes `riscv64-elf-gcc` toolchain is installed
* `end-to-end/test.sh` sends, receives and compares expected output with actual output
  - assumes `/dev/ttyUSB1`, 115200 baud, 8 bit data, 1 stop bit, no parity, no flow control
