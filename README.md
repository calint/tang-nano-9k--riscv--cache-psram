# Tang Nano 9K

step-wise development towards a RISC-V rv32i implementation supporting cache of burst PSRAM

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