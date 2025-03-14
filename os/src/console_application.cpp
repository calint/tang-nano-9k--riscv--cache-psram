//
// source for console build
//
// note: meant to be run in Visual Code terminal for debugging purposes where
// backspace is encoded 0x7f
//
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <termios.h>
#include <unistd.h>
#include <vector>

static auto initiate_bss() -> void {}
// note: bss section is initialized by the environment

static auto initiate_statics() -> void {}
// note: statics are initiated by the C++ runtime

static char constexpr char_carriage_return = '\x0a';
// console application uses newline

#include "os_common.hpp"
// the platform independent source

// initialize SD card 8 MB
static std::vector<uint8_t> sdcard(8 * 1024 * 1024, 0);
static size_t constexpr sdcard_sector_size_bytes = 512;

static auto load_file(char const *file_name, char const *data_name,
                      std::vector<uint8_t> &data) -> bool {

  using namespace std;

  ifstream file{file_name, ios::binary | ios::ate};
  if (!file) {
    printf("%s: error opening file '%s'\n", data_name, file_name);
    return false;
  }

  streamsize const size = file.tellg();
  if (size == -1) {
    printf("%s: error determining size of file '%s'\n", data_name, file_name);
    return false;
  }

  if (size > streamsize(data.size())) {
    printf("%s: size of file (%zu B) exceeds size of data container (%zu B)\n",
           data_name, size, data.size());
    return false;
  }

  file.seekg(0, ios::beg);
  if (file.fail()) {
    printf("%s: error seeking to beginning of file '%s'\n", data_name,
           file_name);
    return false;
  }

  if (!file.read(reinterpret_cast<char *>(data.data()), size)) {
    printf("%s: error reading file '%s'\n", data_name, file_name);
    return false;
  }

  file.close();

  return true;
}

auto main(int argc, char *argv[]) -> int {

  if (argc != 2) {
    printf("Usage: %s <sdcard.bin>\n", argv[0]);
    return 1;
  }

  if (!load_file(argv[1], "SD card", sdcard)) {
    return 2;
  }

  struct termios term{};
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

static auto action_mem_test() -> void {
  uart_send_cstr("testing memory (write)\r\n");
  uart_send_cstr("testing memory (read)\r\n");
  uart_send_cstr("testing memory succeeded\r\n");
}

static auto action_sdcard_status() -> void {
  uart_send_cstr("SDCARD_STATUS: 0x");
  uart_send_hex_uint32(6, true);
  uart_send_cstr("\r\n");
}

static auto sdcard_read_blocking(size_t const sector, int8_t *buffer512B)
    -> void {
  int64_t const ix = int64_t(sector * sdcard_sector_size_bytes);
  auto const bgn = sdcard.begin() + ix;
  auto const end = bgn + sdcard_sector_size_bytes;
  if (end > sdcard.end()) {
    return;
  }
  copy(bgn, end, buffer512B);
}

static auto sdcard_write_blocking(size_t const sector, int8_t const *buffer512B)
    -> void {
  int64_t const ix = int64_t(sector * sdcard_sector_size_bytes);
  auto const dst = sdcard.begin() + ix;
  auto const bgn = buffer512B;
  auto const end = bgn + sdcard_sector_size_bytes;
  if (dst + sdcard_sector_size_bytes > sdcard.end()) {
    return;
  }
  copy(bgn, end, dst);
}
