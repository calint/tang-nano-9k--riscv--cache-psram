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

static constexpr char CHAR_CARRIAGE_RETURN = 0x0d;
// freestanding serial terminal uses carriage return for newline

#include "os_common.hpp"
// the platform independent source

// FPGA I/O

static auto led_set(int32_t const bits) -> void { *LED = bits; }

static auto uart_send_str(char const *str) -> void {
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
  uart_send_str("testing memory (write)\r\n");
  char *ptr = &__heap_start;
  char const *const end = reinterpret_cast<char *>(MEMORY_END - 1024);
  // -1024 to avoid the stack
  // ?? don't forget about this when the application grows
  char ch = 0;
  while (ptr < end) {
    *ptr++ = ch++;
  }
  uart_send_str("testing memory (read)\r\n");
  ptr = &__heap_start;
  ch = 0;
  while (ptr < end) {
    if (*ptr++ != ch++) {
      uart_send_str("!!! test memory failed\r\n");
      return;
    }
  }
  uart_send_str("testing memory succeeded\r\n");
}

static auto action_sdcard_test() -> void {
  static size_t page = 0;
  int8_t buf[512];
  sdcard_read_blocking(page, buf);
  ++page;
  for (size_t i = 0; i < sizeof(buf); ++i) {
    uart_send_char(buf[i]);
  }
  uart_send_str("\r\n");
}

static auto action_sdcard_status() -> void {
  int32_t const status = *SDCARD_STATUS;
  uart_send_str("SD card status: ");
  uart_send_hex_byte(char(status >> 8));
  uart_send_char(' ');
  uart_send_hex_byte(char(status));
  uart_send_str("\r\n");
}

static auto sdcard_read_blocking(size_t const sector,
                                 int8_t *buffer512B) -> void {
  while (*SDCARD_BUSY)
    ;
  *SDCARD_READ_SECTOR = sector;
  while (*SDCARD_BUSY)
    ;
  for (size_t i = 0; i < 512; ++i) {
    *buffer512B++ = char(*SDCARD_NEXT_BYTE);
  }
}

// built-in function called by compiler
extern "C" auto memset(void *str, int ch, int n) -> void * {
  char *ptr = reinterpret_cast<char *>(str);
  while (n--) {
    *ptr++ = char(ch);
  }
  return str;
}

// zero bss section
static auto initiate_bss() -> void {
  memset(&__bss_start, 0, &__bss_end - &__bss_start);
}

static auto initiate_statics() -> void {}

static auto exit(int code) -> void {}