//
// source for console build
//
#include <stdio.h>
#include <termios.h>
#include <unistd.h>

#define CHAR_CARRIAGE_RETURN 0x0a

#include "os_common.c"

int main() {
  struct termios tm;
  tcgetattr(STDIN_FILENO, &tm);
  tm.c_lflag &= ~(unsigned)(ICANON | ECHO);
  tcsetattr(STDIN_FILENO, TCSANOW, &tm);

  run();
}

void uart_send_char(const char ch) {
  if (ch == CHAR_BACKSPACE) {
    printf("\b \b");
  } else {
    putchar(ch);
  }
}

void uart_send_str(const char *str) { printf("%s", str); }

char uart_read_char() { return (char)getchar(); }

void led_set(unsigned char bits) {}

void action_mem_test() { printf("memory test not supported\n"); }
