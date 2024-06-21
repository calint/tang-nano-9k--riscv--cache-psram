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
         => reg -> logic, all outputs logic, all inputs wires
[x]    parameters in UpperCamelCase
[ ]    Main clock signal is named clk. All clock signals must start with clk_
[x]    Reset signals are active-low and asynchronous, default name is rst_n
[x]    Signal names should be descriptive and be consistent throughout the hierarchy
[ ]    Add _i to module inputs, _o to module outputs or _io for bi-directional module signals
         => the ports have verbose names implying input/output
[x]    Enumerated types should be suffixed with _e
[x]    Use full port declaration style for modules, any clock and reset declared first
[x]    Use named parameters for instantiation, all declared ports must be present, no .*
[ ]    Top-level parameters is preferred over  `define globals
[x]    Use symbolically named constants instead of raw numbers
[x]    Local constants should be declared localparam, globals in a separate .svh file.
[x]    logic is preferred over reg and wire, declare all signals explicitly
[x]    always_comb, always_ff and always_latch are preferred over always
[x]    Interfaces are discouraged
[x]    Sequential logic must use non-blocking assignments
[x]    Combinational blocks must use blocking assignments
[x]    Use of latches is discouraged, use flip-flops when possible
[x]    The use of X assignments in RTL is strongly discouraged, make use of SVAs to check invalid behavior instead.
[ ]    Prefer assign statements wherever practical.
[x]    Use unique case and always define a default case
[x]    Use available signed arithmetic constructs wherever signed arithmetic is used
[x]    When printing use 0b and 0x as a prefix for binary and hex. Use _ for clarity
[x]    Use logical constructs (i.e ||) for logical comparison, bit-wise (i.e |) for data comparison
[x]    Bit vectors and packed arrays must be little-endian, unpacked arrays must be big-endian
[ ]    FSMs: no logic except for reset should be performed in the process for the state register
[x]    A combinational process should first define default value of all outputs in the process
[ ]    Default value for next state variable should be the current state
[x]    enums for states in FSM
[-]    snake case names for modules
         => makes instance names inconvenient
[x] review test benches
[ ]    FSM in always_comb?
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