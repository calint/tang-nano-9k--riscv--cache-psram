#include "os_config.h"

static const char *hello = "Hello World\r\n";

void uart_send_str(const char *str);
void uart_send_char(char ch);
char uart_read_char();

extern "C" void run() {
  *LED = 0; // all leds on

  uart_send_str(hello);

  while (1) {
    const char ch = uart_read_char();
    uart_send_char(ch);
    if (ch == '\r') {
      uart_send_char('\n');
    }
    *LED = ch;
  }
}

void uart_send_str(const char *str) {
  while (*str) {
    while (*UART_OUT != -1)
      ;
    *UART_OUT = *str;
    str++;
  }
}

void uart_send_char(const char ch) {
  while (*UART_OUT != -1)
    ;
  *UART_OUT = ch;
}

char uart_read_char() {
  short ch = 0;
  while ((ch = *UART_IN) == -1)
    ;
  return char(ch);
}
