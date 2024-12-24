# osqa emulator

Emulates the FPGA program.

## usage
`./make.sh` to build the emulator

`./osqa ../os/os.bin` to run the firmware.

## todo
```
[ ] building the immediate values can be done with 1 AND, 1 SHIFT per section
    using a hardcoded mask instead of current 3 SHIFT, 1 AND, 2 ADD, 1 SUB
[ ] in debug mode print the values of used registers, immediate values and result
```