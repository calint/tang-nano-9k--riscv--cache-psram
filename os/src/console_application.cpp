//
// source for console build
//
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <termios.h>
#include <unistd.h>

static auto initiate_bss() -> void {}
// note: bss section is initialized by the environment

static auto initiate_statics() -> void {}
// note: statics are initiated by the C++ runtime

static constexpr char CHAR_CARRIAGE_RETURN = 0x0a;
// console application uses newline

#include "os_common.hpp"
// the platform independent source

int main() {
  struct termios term {};
  tcgetattr(STDIN_FILENO, &term);
  term.c_lflag &= ~unsigned(ICANON | ECHO);
  tcsetattr(STDIN_FILENO, TCSANOW, &term);

  run();
}

static void uart_send_char(char const ch) {
  if (ch == CHAR_BACKSPACE) {
    printf("\b \b");
  } else {
    putchar(ch);
  }
}

static void uart_send_str(char const *str) { printf("%s", str); }

static char uart_read_char() { return char(getchar()); }

static void led_set(uint8_t const bits) {}

static void action_mem_test() { printf("memory test not supported\n"); }
