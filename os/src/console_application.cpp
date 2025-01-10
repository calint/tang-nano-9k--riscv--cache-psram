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

static auto led_set(int32_t const bits) -> void {}

static auto action_mem_test() -> void { printf("memory test not supported\n"); }

static auto action_sdcard_test_read(char const *words[],
                                    size_t const nwords) -> void {
  printf("sdcard test read not supported\n");
}

static auto action_sdcard_test_write(char const *words[],
                                     size_t const nwords) -> void {
  printf("sdcard test write not supported\n");
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
