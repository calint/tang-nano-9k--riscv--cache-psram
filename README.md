# [Tang Nano 9K](https://www.aliexpress.com/item/1005003803994525.html)

## Intention
* RISC-V implementation of rv32i for application intended use
  - no `ecall`, `ebreak`, `fence` or counters
* multi-cycle with ad-hoc pipeline
* cache to 2 MB of on-board burst PSRAM
* explore the FPGA board

## Gowin EDA 1.9.10.03 Education Build (77527) Project Configuration
![1](https://github.com/calint/tang-nano-9k--riscv--cache-psram/blob/main/notes/gowin-project-configuration/1.png)

![2](https://github.com/calint/tang-nano-9k--riscv--cache-psram/blob/main/notes/gowin-project-configuration/2.png)

![3](https://github.com/calint/tang-nano-9k--riscv--cache-psram/blob/main/notes/gowin-project-configuration/3.png)

![4](https://github.com/calint/tang-nano-9k--riscv--cache-psram/blob/main/notes/gowin-project-configuration/4.png)

![5](https://github.com/calint/tang-nano-9k--riscv--cache-psram/blob/main/notes/gowin-project-configuration/5.png)

## Howto
* build bitstream file in Gowin EDA
* run `./flash-fpga.sh` to flash bitstream file 
* then `./make-and-flash-os.sh` to flash program
* connect with serial terminal to the tty (e.g. `/dev/ttyUSB1`) at 115200 baud, 8 bit data, 1 stop bit, no parity, no flow control

![1](https://github.com/calint/tang-nano-9k--riscv--cache-psram/blob/main/notes/serial-terminal-settings/1.png)

* press button S1 to reset and view the greeting

## Greeting
```
                                  oOo.o.
         frameless osca          oOo.oOo
      __________________________  .oOo.
     O\        -_   .. \    ___ \   ||
    O  \                \   \ \\ \ //\\
   o   /\    risc-v      \   \|\\ \
  .   //\\    fpga        \   ||   \
   .  \\/\\    overview    \  \_\   \
    .  \\//\________________\________\
     .  \/_/, \\\--\\..\\ - /\_____  /
      .  \ \ . \\\__\\__\\./ / \__/ /
       .  \ \ , \    \\ ///./ ,/./ /
        .  \ \___\ sticky notes / /
         .  \/\________________/ /
    ./\.  . / /                 /
    /--\   .\/_________________/
         ___.                 .
        |o o|. . . . . . . . .
        /| |\ . .
    ____       . .
   |O  O|       . .
   |_ -_|        . .
    /||\
      ___
     /- -\
    /\_-_/\
      | |

welcome to adventure #4
    type 'help'
```

## Sample Program
* an "operating system" in `/os` inspired by text adventure games
* other examples in `/notes/samples/`

## Configuration
* see [`configuration.py`](https://github.com/calint/tang-nano-9k--riscv--cache-psram/blob/main/configuration.py)

## Source
* SystemVerilog adhering to most of style guide https://github.com/lowRISC/style-guides/blob/master/VerilogCodingStyle.md

## Todo
```
-------------------------------------------------------------------------------------------------------------
[ ] os: backspace to ctrl+h (0x08) and update putty terminal configuration screenshot
    => move the 0x08 definition to console_application.cpp and 0x7f to os.cpp
[ ] cat > /dev/ttyUSB1 should echo without dropping input
[ ] study why BAUD rate less than 2400 does not work
[ ] UART read 'short' and return 0xffff for no data available or 0xXX for byte read including 0
[ ] read LEDs
[ ] investigate and try to recreate the "// ??" issue in 'ramio'
    => the simulation works as expected
[ ] counter[highest_bit] == 1 in decreasing counters into negative instead of counter == 0
[ ] fix red hold and recovery paths (not involved in running CPU, ignored)
[ ]   psram: CALIB
[ ]   psram: RESET 

next step
[ ] reduce execution cycle by one step by doing CpuExecute in CpuFetch when ramio_data_out_ready
    => registers module would be a 2 port read, 1 port write per cycle

step 12
[ ] always_comb based CPU
[ ]   1 cycle ALU op
[ ]   1+ cycle store op
[ ]   1+ cycle load op
[ ] FSM in always_comb?
[ ] dual channel 4 MB PSRAM
    => reasonable cache size does not fit in fpga resources
    => study cache synthesized as block ram

step 13
[ ] fully pipe-lined core
[ ] consider FIFO in UART
-------------------------------------------------------------------------------------------------------------
[x] study why terminal drops characters
    => receive is being overrun but how can baud 9600 outpace 20 MHz?
       => due to 'uart_send_char()'?
    => UART overrun even when doing 'uart_read_char()' in a loop
    => moreover characters are dropped without UART being overrun
    => fixed end-to-end test without grasping why it did not previously worked
       search for '// ??' in 'ramio'
[x] UART rx: if rx changes to low while in stop-bit assume drifting and switch to wait for go
    => stop bit is read for half a baud cycle giving half to acknowledge and wait for start bit
[x] fix truncation warnings
[x] enums for states in FSM
[x] review test benches
[x] testbenches: assert (condition) else $fatal("...");
      => else $error()
[x] make end-to-end test succeed without dropped input
[x] step 11: adapt riscv core (multi-cycle ad-hoc pipeline simplest way forward)
[x] RAMIO: read UART with 'lb' or 'lbu'
-------------------------------------------------------------------------------------------------------------
[o] apply style guide https://github.com/lowRISC/style-guides/blob/master/VerilogCodingStyle.md
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
[x]    Top-level parameters is preferred over  `define globals
[x]    Use symbolically named constants instead of raw numbers
[x]    Local constants should be declared localparam, globals in a separate .svh file.
[x]    logic is preferred over reg and wire, declare all signals explicitly
[x]    always_comb, always_ff and always_latch are preferred over always
[x]    Interfaces are discouraged
[x]    Sequential logic must use non-blocking assignments
[x]    Combinational blocks must use blocking assignments
[x]    Use of latches is discouraged, use flip-flops when possible
[x]    The use of X assignments in RTL is strongly discouraged, make use of SVAs to check invalid behavior instead.
[x]    Prefer assign statements wherever practical.
[x]    Use unique case and always define a default case
[x]    Use available signed arithmetic constructs wherever signed arithmetic is used
[x]    When printing use 0b and 0x as a prefix for binary and hex. Use _ for clarity
[x]    Use logical constructs (i.e ||) for logical comparison, bit-wise (i.e |) for data comparison
[x]    Bit vectors and packed arrays must be little-endian, unpacked arrays must be big-endian
[ ]    FSMs: no logic except for reset should be performed in the process for the state register
[x]    A combinational process should first define default value of all outputs in the process
[ ]    Default value for next state variable should be the current state

[x]    Use only ASCII characters with UNIX-style line endings("\n").
[x]    Use the .sv extension for SystemVerilog files (or .svh for files that are included via the preprocessor).
[x]    All lines on non-empty files must end with a newline ("\n").
[x]    Wrap the code at 100 characters per line.
         => formatting done automatically by extension
[x]    Do not use tabs anywhere.
[x]    Delete trailing whitespace at the end of lines.
[x]    Use begin and end unless the whole statement fits on a single line.
[x]    Indentation is two spaces per level.
[x]    Keep branching preprocessor directives left-aligned and un-indented.
[x]    For multiple items on a line, one space must separate the comma and the next character.
[x]    Include whitespace on both sides of all binary operators.
[x]    Add a space around packed dimensions.
[x]    Add one space before type parameters, except when the type is part of a qualified name.
[x]    When labeling code blocks, add one space before and after the colon.
[x]    There must be no whitespace before a case item's colon; there must be at least one space after the case item's colon.
[x]    Function and task calls must not have any spaces between the function name or task name and the open parenthesis.
[x]    Include whitespace before and after SystemVerilog keywords.
[x]    Use parentheses to make operations unambiguous.
[x]    Ternary expressions nested in the true condition of another ternary expression must be enclosed in parentheses.
[x]    C++ style comments (// foo) are preferred. C style comments (/* bar */) can also be used.
[x]    Signals must be declared before they are used. This means that implicit net declarations must not be used.
[x]    Declarations (module, class, package, interface)	lower_snake_case
[x]    Instance names	lower_snake_case
[x]    Signals (nets and ports)	lower_snake_case
[x]    Variables, functions, tasks	lower_snake_case
[x]    Named code blocks	lower_snake_case
[x]    `define macros	ALL_CAPS
         => not used
[x]    Tunable parameters for parameterized modules, classes, and interfaces UpperCamelCase
[x]    Constants ALL_CAPS or UpperCamelCase
[x]    Enumeration types lower_snake_case_e
[x]    Other typedef types lower_snake_case_t
         => not used
[x]    Enumerated value names	UpperCamelCase
[x]    Declare global constants using parameters in the project package file.
[x]    `define ALL_CAPS Truly constant
[x]    module parameter UpperCamelCase truly modifiable by instantiation, not constant
[x]    derived localparam UpperCamelCase while not modified directly, still tracks module parameter
[x]    tuneable localparam UpperCamelCase while not expected to change upon final RTL version, 
       is used by designer to explore the design space conveniently
[x]    true localparam constant ALL_CAPS
[x]    enum member true constant ALL_CAPS
[x]    enum set member	ALL_CAPS or UpperCamelCase
[x]    Use parameter to parameterize, and localparam to declare module-scoped constants. Within a package, use parameter.
[x]    Explicitly declare the type for parameters.
[ ]    Suffixes are used in several places to give guidance to intent.
[x]    Name enumeration types snake_case_e. Name enumeration values ALL_CAPS or UpperCamelCase.
[x]    Use lower_snake_case when naming signals.
[x]    Names should describe what a signal's purpose is.
[x]    Use common prefixes to identify groups of signals that operate together.
[ ]    The same signal should have the same name at any level of the hierarchy.
[ ]    All clock signals must begin with clk
[x]    Resets are active-low and asynchronous. The default name is rst_n
[x]    Use these SystemVerilog constructs instead of their Verilog-2001 equivalents
[x]    Packages must not have cyclic dependencies.
[x]    Use the Verilog-2001 full port declaration style, and use the format below.
[x]    Use named ports to fully specify all instantiations.
[x]    Use named parameters for all instantiations.
[x]    Do not instantiate recursively.
[x]    It is recommended to use symbolicly named constants instead of raw numbers.
[x]    Always be explicit about the widths of number literals.
[x]    Do not use multi-bit signals in a boolean context.
[x]    Only use the bit slicing operator when the intent is to refer to a portion of a bit vector.
[x]    Beware of shift operations, which can produce a result wider than the operand.
[x]    Sequential logic must use non-blocking assignments. Combinational blocks must use blocking assignments.
[x]    Do not use #delay in synthesizable design modules.
[x]    The use of latches is discouraged - use flip-flops when possible.
[x]    Use the standard format for declaring sequential blocks.
[ ]    Do not allow multiple non-blocking assignments to the same bit.
       ... the Verilog standard says that the second assignment will take effect, but this is a style violation.
[x]    The use of X literals in RTL code is strongly discouraged.
[x]    Avoid sensitivity lists, and use a consistent assignment type.
[x]    Avoid case-modifying pragmas. unique case is the best practice. Always define a default case.
[ ]    Use case inside if wildcard operator behavior is needed.
         => not supported by iverilog. using "unique casez(...)"
[x]    Always name your generated blocks.
[x]    Use the available signed arithmetic constructs wherever signed arithmetic is used.
[x]    Prefix printed binary numbers with 0b. Prefix printed hexadecimal numbers with 0x. Do not use prefixes for decimal numbers.
[x]    In synthesizable RTL the use of functions is allowed, provided they are declared automatic. Tasks should not be used.
         => non used
[x]    The use of hierarchical references in synthesizable RTL code is prohibited.
[x]    Do not rely on inferred nets.
[x]    Use logic for synthesis. wire is allowed when necessary.
[x]    Prefer logical constructs for logical comparisons, bit-wise for data.
[x]    Bit vectors and packed arrays must be little-endian.
[x]    Unpacked arrays must be big-endian.
[ ]    State machines use an enum to define states, and be implemented with two process blocks: a combinational block and a clocked block.
[x]    The _n suffix indicates an active-low signal.
[x]    Use the _p and _n suffixes to indicate a differential pair.
         => non used
[x]    Signals delayed by a single clock cycle should end in a _q suffix.
         => non used
[x]    The wildcard import syntax, e.g. import ip_pkg::*; is only allowed where the package is part of the same IP as the module that uses that package. 
-------------------------------------------------------------------------------------------------------------
```