//
// source for console build
//
#include <stdio.h>
#include <termios.h>
#include <unistd.h>

constexpr char CHAR_CARRIAGE_RETURN = 0x0a;

#include "os_common.hpp"

int main() {
  struct termios term {};
  tcgetattr(STDIN_FILENO, &term);
  term.c_lflag &= ~(unsigned)(ICANON | ECHO);
  tcsetattr(STDIN_FILENO, TCSANOW, &term);

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

void led_set(uint8_t bits) {}

auto uart_send_move_back(uint32_t const n) -> void {
  for (uint32_t i = 0; i < n; ++i) {
    putchar('\b');
  }
}

void action_mem_test() { printf("memory test not supported\n"); }
