#define LED ((volatile int *)0xffff'fffc)
#define UART_OUT ((volatile int *)0xffff'fff8)
#define UART_IN ((volatile int *)0xffff'fff4)
#define MEMORY_TOP 0x200000

void uart_send_char(char ch);
char uart_read_char();

extern "C" void run() {
  *LED = 0; // all leds on

  while (1) {
    const char ch = uart_read_char();
    uart_send_char(ch);
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
  int ch = 0;
  // wait for UART to receive data
  while ((ch = *UART_IN) == -1)
    ;
  return char(ch);
}
