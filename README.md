# Tang Nano 9K

* RISC-V rv32i implementation for intended use
  - no `ecall`, `ebreak`, `fence` or counters
* cache to on-board burst 2 MB PSRAM
* __todo__ dual channel 4 MB PSRAM
* multi-cycle design with ad-hoc pipeline
* __todo__ fully pipe-lined design

## Gowin EDA configuration
![1](https://github.com/calint/tang-nano-9k--riscv--cache-psram/blob/main/notes/gowin-project-configuration/1.png)

![2](https://github.com/calint/tang-nano-9k--riscv--cache-psram/blob/main/notes/gowin-project-configuration/2.png)

![3](https://github.com/calint/tang-nano-9k--riscv--cache-psram/blob/main/notes/gowin-project-configuration/3.png)

![4](https://github.com/calint/tang-nano-9k--riscv--cache-psram/blob/main/notes/gowin-project-configuration/4.png)

![5](https://github.com/calint/tang-nano-9k--riscv--cache-psram/blob/main/notes/gowin-project-configuration/5.png)

## howto
* build bitstream file in Gowin EDA
* run `./flash-fpga.sh` to flash bitstream
* then `./make-and-flash-os.sh` to flash program
* connect with serial terminal to the tty (e.g. /dev/ttyUSB1) at 9600 baud, 8 bit data, 1 stop bit, no parity

![1](https://github.com/calint/tang-nano-9k--riscv--cache-psram/blob/main/notes/serial-terminal-settings/1.png)

## todo
```
[ ] study why terminal drops characters
    cat > /dev/ttyUSB1 should echo without dropping input
    => receive is being overrun but how can baud 9600 outpace 20 MHz?
       => due to 'uart_send_char()'?
    => UART overrun even when doing 'uart_read_char()' in a loop
[ ] study why BAUD rate of less than 2400 does not work
[ ] fix truncation warnings
[x] step 11: adapt riscv core (multi-cycle ad-hoc pipeline simplest way forward)
[x] RAMIO: read UART with 'lb' or 'lbu'
[ ] UART read 'short' and return 0x100 for no data available or 0xXX for byte read including 0
[ ] always_comb based CPU
[ ] 1 cycle ALU op
[ ] 1+ cycle STORE
[ ] 2+ cycle LOAD
[ ] step 12: pipe-lined core
```