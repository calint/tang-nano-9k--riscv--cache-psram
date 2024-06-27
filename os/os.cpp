//
// source for the FPGA build
//
#include "os_config.hpp"

constexpr char CHAR_CARRIAGE_RETURN = 0x0d;

extern char __bss_start;
extern char __bss_end;

static auto startup_init_bss() -> void {
  for (char *bss = &__bss_start; bss < &__bss_end; ++bss) {
    *bss = 0;
  }
}

#include "os_common.hpp"

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

static auto action_mem_test() -> void {
  uart_send_str("testing memory (write)\r\n");
  char *ptr = (char *)0x10000;
  char const *end = (char *)MEMORY_TOP - 1024; // -1024 to avoid the stack
  char ch = 0;
  while (ptr < end) {
    *ptr++ = ch++;
  }
  uart_send_str("testing memory (read)\r\n");
  ptr = (char *)0x10000;
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
