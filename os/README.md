# "operating system"

## build
`./make-fpga-flash-binary.sh` compiles `src/os.cpp` and generates:
* `os.bin` - binary to be flashed to FPGA
* `os.lst` - assembler with source annotations
* `os.dat` - data sections of binary

`./make-console-application.sh` compiles `src/console-application.cpp` and generates:
* `os-console` - executable binary of console application

## configuration
`../configuration.py` is applied by `../configuration-apply.py` and generates files:
* `src/os_config.hpp` - addresses to LEDs, UART and top of memory
* `src/os_start.S` - setup stack before `os_common.hpp` `run()`

## /src/
* `os_config.hpp` - see __configuration__
* `os_start.S` - see __configuration__
* `os_common.hpp` - common source for console and freestanding build
* `os.cpp` - source for freestanding build
* `console-application.cpp` - source for console build

## /qa/
* `test.sh` for end-to-end test

## disclaimers
* source in `hpp` files
  - unified build viewing the program as one file
  - gives compiler opportunity to optimize in a broader context
  - increases compile time and is not scalable; however, this application is smallish
* use of `static` storage and function declarations
  - gives compiler opportunity to optimize
* include order relevant
  - subsystems are included in dependency order making the program readable top-down
* `inline` functions
  - all functions are requested to be inlined assuming compilers won't adhere to the hint when it does not make sense, such as big functions called from multiple locations
  - functions called from only one location should be inlined
* `const` is preferred and used where applicable
* `auto` is used when the type name is too verbose, such as iterators; otherwise, types are spelled out for readability
* right to left notation `Type const &inst` instead of `const Type &inst`
  - for consistency, `const` is written after the type such as `char const *ptr` instead of `const char *ptr` and `float const x` instead of `const float x`
  - idea is that type name is an annotation that can be replaced by `auto`
* `unsigned` is used where negative values don't make sense
* `++i` instead of `i++`
  - for consistency with incrementing iterators, all increments and decrements are done in prefix
* casting such as `char(getchar())` are ok for readability
  - `reinterpret_cast` used when syntax does not allow otherwise
* all members and variables are initialized for clarity although redundant
  - some exceptions regarding buffers applied
* naming convention:
  - descriptive and verbose
  - snake case
  - lower case
  - private members have suffix `_`
* use of public members in classes
  - public members are moved to private scope when not used outside the class
  - when a change to a public member triggers other actions, accessors are written, and member is moved to private scope
* "Plain Old C++ Object" preferred
* "Rule of None" preferred
