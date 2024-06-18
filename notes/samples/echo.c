#include "os_config.h"

static char *hello = "Hello World\r\n";

void uart_send_str(const char *str);
void uart_send_char(char ch);
char uart_read_char();

void run() {
  *LED = 0; // all leds on

  uart_send_str(hello);

  while (1) {
    const char ch = uart_read_char();
    uart_send_char(ch);
    *LED = ch;
  }
}

void uart_send_str(const char *str) {
  while (*str) {
    while (*UART_OUT)
      ;
    *UART_OUT = *str;
    str++;
  }
}

void uart_send_char(const char ch) {
  while (*UART_OUT)
    ;
  *UART_OUT = ch;
}

char uart_read_char() {
  char ch = 0;
  while ((ch = *UART_IN) == 0)
    ;
  return ch;
}
