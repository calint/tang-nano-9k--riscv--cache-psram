//
// source for the FPGA build
//
#include "os_config.hpp"

constexpr char CHAR_CARRIAGE_RETURN = 0x0d;

// symbols to mark start and end of bss section
extern char __bss_start;
extern char __bss_end;

// zero bss section
static auto startup_init_bss() -> void {
  for (char *bss = &__bss_start; bss < &__bss_end; ++bss) {
    *bss = 0;
  }
}

// freestanding does not automatically initiate statics
static auto startup_init_statics() -> void {}

// FPGA has no exit
static auto exit(int code) -> void {}

// standard types
using int8_t = char;
using uint8_t = unsigned char;
using int16_t = short;
using uint16_t = unsigned short;
using int32_t = int;
using uint32_t = unsigned int;
using int64_t = long long;
using uint64_t = unsigned long long;
using size_t = uint32_t;

// common source
#include "os_common.hpp"

// FPGA I/O

static auto led_set(uint8_t bits) -> void { *LED = bits; }

static auto uart_send_str(char const *str) -> void {
  while (*str) {
    while (*UART_OUT)
      ;
    *UART_OUT = *str++;
  }
}

static auto uart_send_char(char const ch) -> void {
  while (*UART_OUT)
    ;
  *UART_OUT = ch;
}

static auto uart_read_char() -> char {
  char ch;
  while ((ch = *UART_IN) == 0)
    ;
  return ch;
}

// simple test of FPGA memory
static auto action_mem_test() -> void {
  uart_send_str("testing memory (write)\r\n");
  char *ptr = reinterpret_cast<char *>(0x10000);
  char const *end = reinterpret_cast<char *>(MEMORY_TOP - 1024);
  // -1024 to avoid the stack
  // ?? don't forget about this when the application grows
  char ch = 0;
  while (ptr < end) {
    *ptr++ = ch++;
  }
  uart_send_str("testing memory (read)\r\n");
  ptr = reinterpret_cast<char *>(0x10000);
  ch = 0;
  while (ptr < end) {
    if (*ptr++ != ch++) {
      uart_send_str("!!! test memory failed\r\n");
      return;
    }
  }
  uart_send_str("testing memory succeeded\r\n");
}

// built-in function called by compiler
extern "C" auto memset(void *str, int ch, int n) -> void * {
  char *ptr = reinterpret_cast<char *>(str);
  while (n--) {
    *ptr++ = (char)ch;
  }
  return str;
}
