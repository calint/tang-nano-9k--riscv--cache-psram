//
// source for console build
//
// note: meant to be run in Visual Code terminal for debugging purposes where
// backspace is encoded 0x7f
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

static char constexpr char_carriage_return = '\x0a';
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
  if (ch == char_backspace) {
    printf("\b \b");
  } else {
    putchar(ch);
  }
}

static auto uart_send_cstr(char const *str) -> void { printf("%s", str); }

static auto uart_read_char() -> char { return char(getchar()); }

static auto led_set(uint32_t const bits) -> void {}

static auto action_mem_test() -> void { printf("memory test not supported\n"); }

static auto action_sdcard_read(string const args) -> void {
  printf("action sdcard read not supported\n");
}

static auto action_sdcard_write(string const args) -> void {
  printf("action sdcard write not supported\n");
}

static auto action_sdcard_status() -> void {
  printf("sdcard status not supported\n");
}

static auto sdcard_read_blocking(size_t const sector,
                                 int8_t *buffer512B) -> void {
  printf("sdcard read not supported");
}

static auto sdcard_write_blocking(size_t const sector,
                                  int8_t const *buffer512B) -> void {
  printf("sdcard write not supported");
}
