# Tang Nano 9K

step-wise development towards a RISC-V rv32i implementation supporting cache of PSRAM

## todo
```
[ ] study why terminal drops characters
[ ]   cat > /dev/ttyUSB1 should echo without dropping input
[ ] fix truncation warnings
[x] step 11: adapt riscv core (multi-cycle simplest way forward with ad-hoc pipe-lining)
[x] RAMIO: read UART with 'lb' or 'lbu'
[ ] 1 cycle ALU op
[ ] 1+ cycle STORE
[ ] 2+ cycle LOAD
[ ] step 12: pipe-lined core

```