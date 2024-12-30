#define LED ((short volatile *)0xfffffffe)
#define UART_OUT ((short volatile *)0xfffffffc)
#define UART_IN ((short volatile *)0xfffffffa)
#define MEMORY_TOP 0x200000

void uart_send_char(char ch);
char uart_read_char();

extern "C" void run() {
  *LED = 0; // all leds on

  while (1) {
    const char ch = uart_read_char();
    uart_send_char(ch);
    if (ch == '\r') {
      uart_send_char('\n');
    }
    *LED = ch;
  }
}

void uart_send_char(const char ch) {
  // wait for UART to be idle
  while (*UART_OUT != -1)
    ;
  *UART_OUT = ch;
}

char uart_read_char() {
  short ch = 0;
  // wait for UART to read receive data
  while ((ch = *UART_IN) == -1)
    ;
  return char(ch);
}
