//
// source file for the FPGA build
//
#include "os_config.h"

#define CHAR_CARRIAGE_RETURN 0x0d

#include "os_common.c"

void led_set(unsigned char bits) { *LED = bits; }

void uart_send_str(const char *str) {
  while (*str) {
    while (*UART_OUT)
      ;
    *UART_OUT = *str++;
  }
}

void uart_send_char(const char ch) {
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
  const char *end = (char *)MEMORY_TOP - 1024; // -1024 to avoid the stack
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
