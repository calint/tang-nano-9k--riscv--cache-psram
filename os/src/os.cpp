//
// source for the FPGA build
//
#include "os_config.hpp"

// standard types
using int8_t = char;
using uint8_t = unsigned char;
using int16_t = short;
using uint16_t = unsigned short;
using int32_t = int;
using uint32_t = unsigned int;
using int64_t = long long;
using uint64_t = unsigned long long;
using size_t = uint32_t;

// symbols that mark start and end of bss section
extern char __bss_start;
extern char __bss_end;

// symbol that marks the start of heap memory
extern char __heap_start;

static auto initiate_bss() -> void;
// freestanding does not automatically initialize bss section

static auto initiate_statics() -> void;
// freestanding does not automatically initiate statics

static auto exit(int code) -> void;
// FPGA has no exit

static char constexpr char_carriage_return = '\x0d';
// freestanding serial terminal uses carriage return for newline

#include "os_common.hpp"
// the platform independent source

// FPGA I/O

static auto led_set(uint32_t const bits) -> void { *LED = bits; }

static auto uart_send_cstr(char const *str) -> void {
  while (*str) {
    while (*UART_OUT != -1)
      ;
    *UART_OUT = *str++;
  }
}

static auto uart_send_char(char const ch) -> void {
  while (*UART_OUT != -1)
    ;
  *UART_OUT = ch;
}

static auto uart_read_char() -> char {
  int ch;
  while ((ch = *UART_IN) == -1)
    ;
  return char(ch);
}

// simple test of FPGA memory
static auto action_mem_test() -> void {
  uart_send_cstr("testing memory (write)\r\n");
  char *ptr = &__heap_start;
  char const *const end = reinterpret_cast<char *>(MEMORY_END - 0x1'0000);
  // ??? 0x1'0000 bytes reserved for stack, something more solid would be better
  // ??? don't forget about this when the application grows
  char ch = 0;
  while (ptr < end) {
    *ptr = ch;
    ++ptr;
    ++ch;
  }
  uart_send_cstr("testing memory (read)\r\n");
  ptr = &__heap_start;
  // ptr = reinterpret_cast<char *>(0x1'0000);
  ch = 0;
  bool failed = false;
  while (ptr < end) {
    if (*ptr != ch) [[unlikely]] {
      uart_send_cstr("at ");
      uart_send_hex_uint32(uint32_t(ptr), true);
      uart_send_cstr(" expected ");
      uart_send_hex_byte(ch);
      uart_send_cstr(" got ");
      uart_send_hex_byte(*ptr);
      uart_send_cstr("\r\n");
      failed = true;
    }
    ++ptr;
    ++ch;
  }

  if (failed) {
    uart_send_cstr("testing memory FAILED\r\n");
  } else {
    uart_send_cstr("testing memory succeeded\r\n");
  }
}

static auto action_sdcard_read(string const args) -> void {
  let w1 = string_next_word(args);
  if (w1.word.is_empty()) {
    uart_send_cstr("<sector>\r\n");
    return;
  }
  let sector = string_to_uint32(w1.word);
  char buf[512];
  sdcard_read_blocking(sector, buf);
  for (mut i = 0u; i < sizeof(buf); ++i) {
    uart_send_char(buf[i]);
  }
  uart_send_cstr("\r\n");
}

static auto action_sdcard_write(string const args) -> void {
  let w1 = string_next_word(args);
  if (w1.word.is_empty()) {
    uart_send_cstr("<sector> <text>\r\n");
    return;
  }
  char buf[512]{};
  mut *buf_ptr = buf;
  w1.rem.for_each([&buf_ptr](char const ch) {
    *buf_ptr = ch;
    ++buf_ptr;
  });
  size_t const sector = string_to_uint32(w1.word);
  sdcard_write_blocking(sector, buf);
}

static auto action_sdcard_status() -> void {
  uint32_t const status = *SDCARD_STATUS;
  uart_send_cstr("SDCARD_STATUS: 0x");
  uart_send_hex_uint32(status, true);
  uart_send_cstr("\r\n");
}

static auto sdcard_read_blocking(size_t const sector, int8_t *buffer512B)
    -> void {
  while (*SDCARD_BUSY)
    ;
  *SDCARD_READ_SECTOR = sector;
  while (*SDCARD_BUSY)
    ;
  for (size_t i = 0; i < 512; ++i) {
    *buffer512B = char(*SDCARD_NEXT_BYTE);
    ++buffer512B;
  }
}

static auto sdcard_write_blocking(size_t const sector, int8_t const *buffer512B)
    -> void {
  while (*SDCARD_BUSY)
    ;
  for (size_t i = 0; i < 512; ++i) {
    *SDCARD_NEXT_BYTE = *buffer512B;
    ++buffer512B;
  }
  *SDCARD_WRITE_SECTOR = sector;
  while (*SDCARD_BUSY)
    ;
}

// built-in function called by compiler
extern "C" auto memset(void *str, int ch, int n) -> void * {
  char *ptr = reinterpret_cast<char *>(str);
  while (n--) {
    *ptr = char(ch);
    ++ptr;
  }
  return str;
}

// built-in function called by compiler
extern "C" auto memcpy(void *dst, void const *src, size_t n) -> void * {
  char *p1 = reinterpret_cast<char *>(dst);
  char const *p2 = reinterpret_cast<char const *>(src);
  while (n--) {
    *p1 = *p2;
    ++p1;
    ++p2;
  }
  return dst;
}

// zero bss section
static auto initiate_bss() -> void {
  memset(&__bss_start, 0, &__bss_end - &__bss_start);
}

static auto initiate_statics() -> void {}

static auto exit(int code) -> void {}