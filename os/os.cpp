//
// source for the FPGA build
//
#include "os_config.hpp"

constexpr char CHAR_CARRIAGE_RETURN = 0x0d;

#include "os_common.hpp"

void led_set(unsigned char bits) { *LED = bits; }

void uart_send_str(char const *str) {
  while (*str) {
    while (*UART_OUT)
      ;
    *UART_OUT = *str++;
  }
}

void uart_send_char(char const ch) {
  while (*UART_OUT)
    ;
  *UART_OUT = ch;
}

char uart_read_char() {
  char ch;
  while ((ch = *UART_IN) == 0)
    ;
  return ch;
}

void action_mem_test() {
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
extern "C" void *memset(void *str, int ch, int n) {
  char *ptr = reinterpret_cast<char *>(str);
  while (n--) {
    *ptr++ = (char)ch;
  }
  return str;
}
