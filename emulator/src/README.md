## disclaimers
* source in `hpp` files
  - unified build viewing the program as one file
  - gives compiler opportunity to optimize in a broader context
  - increases compile time and is not scalable; however, compilation time for this application is negligible
* use of `static` storage and function declarations
  - gives compiler opportunity to optimize
* include order relevant
  - subsystems are included in dependency order making the program readable top-down
* `inline` functions
  - functions are requested to be inlined assuming compilers won't adhere to the hint when it does not make sense, such as big functions called from multiple locations
  - functions called from only one location should be inlined
* `const` is preferred and used where applicable
* `auto` is used when the type name is too verbose, such as iterators and templates; otherwise, types are spelled out for readability
* sized integer types are used from `stdint.h` instead of `std::` for brevity
* right to left notation `Type const &inst` instead of `const Type &inst`
  - for consistency, `const` is written after the type such as `char const *ptr` instead of `const char *ptr` and `float const x` instead of `const float x`
  - idea is that type name is an annotation that can be replaced by `auto`
  `unsigned types are used where negative values don't make sense
* `++i` instead of `i++`
  - for consistency with incrementing iterators, increments and decrements are done in prefix
* casting such as `char(getchar())` is ok for readability
  - `reinterpret_cast` used when syntax does not allow otherwise
* members and variables are initialized for clarity although redundant
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