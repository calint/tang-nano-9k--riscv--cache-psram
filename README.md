# Tang Nano 9K

* RISC-V implementation of rv32i for intended use
  - no `ecall`, `ebreak`, `fence` or counters
* cache to on-board 2 MB burst PSRAM
* __todo__ dual channel 4 MB PSRAM
* multi-cycle design with ad-hoc pipeline
* __todo__ fully pipe-lined design

## Gowin EDA 1.9.9.03 Project Configuration
![1](https://github.com/calint/tang-nano-9k--riscv--cache-psram/blob/main/notes/gowin-project-configuration/1.png)

![2](https://github.com/calint/tang-nano-9k--riscv--cache-psram/blob/main/notes/gowin-project-configuration/2.png)

![3](https://github.com/calint/tang-nano-9k--riscv--cache-psram/blob/main/notes/gowin-project-configuration/3.png)

![4](https://github.com/calint/tang-nano-9k--riscv--cache-psram/blob/main/notes/gowin-project-configuration/4.png)

![5](https://github.com/calint/tang-nano-9k--riscv--cache-psram/blob/main/notes/gowin-project-configuration/5.png)

## Howto
* build bitstream file in Gowin EDA
* run `./flash-fpga.sh` to flash bitstream
* then `./make-and-flash-os.sh` to flash program
* connect with serial terminal to the tty (e.g. /dev/ttyUSB1) at 9600 baud, 8 bit data, 1 stop bit, no parity

![1](https://github.com/calint/tang-nano-9k--riscv--cache-psram/blob/main/notes/serial-terminal-settings/1.png)

## Todo
```
[o] study why terminal drops characters
    cat > /dev/ttyUSB1 should echo without dropping input
    => receive is being overrun but how can baud 9600 outpace 20 MHz?
       => due to 'uart_send_char()'?
    => UART overrun even when doing 'uart_read_char()' in a loop
    => moreover characters are dropped without UART being overrun
    => fixed end-to-end test without grasping why. search for '// ??' in RAMIO
[o] apply (selectively) style guide https://github.com/lowRISC/style-guides/blob/master/VerilogCodingStyle.md#lowrisc-verilog-coding-style-guide
[x]    use 'logic' instead of registers or wires where applicable?
       => reg -> logic, all outputs logic
[-]    suffixes to port inputs/outputs
       => the ports have verbose names implying input/output
[-] snake case names for modules
    => makes instance names inconvenient
[ ]    FSM in always_comb?
[ ]    suffixes to port inputs/outputs
[ ] study why BAUD rate of less than 2400 does not work
[ ] consider FIFO in UART
[ ] UART read 'short' and return 0xffff for no data available or 0xXX for byte read including 0
[ ] UART rx: if rx changes while not expecting assume drifting and set next bit
[ ] fix truncation warnings
[ ] always_comb based CPU
[ ] 1 cycle ALU op
[ ] 1+ cycle STORE
[ ] 2+ cycle LOAD
[ ] step 12: pipe-lined core
------------------------------------------------------------------------------------------
[x] make end-to-end test succeed without dropped input
[x] step 11: adapt riscv core (multi-cycle ad-hoc pipeline simplest way forward)
[x] RAMIO: read UART with 'lb' or 'lbu'
```