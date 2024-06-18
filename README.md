# Tang Nano 9K

step-wise development towards a RISC-V rv32i implementation supporting cache of burst PSRAM

## todo
```
[x] study why terminal drops characters
    cat > /dev/ttyUSB1 should echo without dropping input
    => receive is being overrun but how can baud 9600 outpace 20 MHz?
       => due to 'uart_send_char()'
[ ] fix truncation warnings
[x] step 11: adapt riscv core (multi-cycle ad-hoc pipeline simplest way forward)
[x] RAMIO: read UART with 'lb' or 'lbu'
[ ] 1 cycle ALU op
[ ] 1+ cycle STORE
[ ] 2+ cycle LOAD
[ ] step 12: pipe-lined core
```