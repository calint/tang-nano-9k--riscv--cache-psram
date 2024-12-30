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

auto main() -> int {
  struct termios term {};
  tcgetattr(STDIN_FILENO, &term);
  term.c_lflag &= ~unsigned(ICANON | ECHO);
  tcsetattr(STDIN_FILENO, TCSANOW, &term);

  run();
}

static auto uart_send_char(char const ch) -> void {
  if (ch == CHAR_BACKSPACE) {
    printf("\b \b");
  } else {
    putchar(ch);
  }
}

static auto uart_send_str(char const *str) -> void { printf("%s", str); }

static auto uart_read_char() -> char { return char(getchar()); }

static auto led_set(uint16_t const bits) -> void {}

static auto action_mem_test() -> void { printf("memory test not supported\n"); }
