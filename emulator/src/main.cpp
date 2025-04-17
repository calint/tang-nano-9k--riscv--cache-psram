#include <array>
#include <cstdint>
#include <cstdio>
#include <fcntl.h>
#include <fstream>
#include <termios.h>
#include <unistd.h>
#include <vector>
// #define RV32I_DEBUG
#include "rv32i.hpp"
//
#include "main_config.hpp"

// #define LOG_UART_IN_TO_STDERR

using namespace std;

// initialize RAM with -1 being the default value from flash
static vector<uint8_t> ram(osqa::memory_end, 0xff);

// initialize SD card 8 MB
static vector<uint8_t> sdcard(8 * 1024 * 1024, 0);

// sdcard sector buffer
static array<uint8_t, 512> sector_buffer;
static size_t sector_buffer_index;

// preserved terminal settings
static struct termios saved_termios;

// bus callback
static auto bus(uint32_t const address, rv32i::bus_op_width const op_width,
                bool const is_store, uint32_t &data) -> rv32i::bus_status {

  // check if address is not an IO address and outside the memory range
  if (address < osqa::io_addresses_start &&
      address + uint32_t(op_width) > ram.size()) {
    return 1;
  }

  if (is_store) {
    switch (address) {
    case osqa::sdcard_busy: {
      // address does not support write
      return 2;
    }
    case osqa::sdcard_status: {
      // address does not support write
      return 3;
    }
    case osqa::sdcard_next_byte: {
      sector_buffer[sector_buffer_index] = uint8_t(data);
      sector_buffer_index = (sector_buffer_index + 1) % sector_buffer.size();
      break;
    }
    case osqa::sdcard_write_sector: {
      auto const dst = sdcard.begin() + data * sector_buffer.size();
      auto const bgn = sector_buffer.begin();
      auto const end = sector_buffer.end();
      if (dst + sector_buffer.size() > sdcard.end()) {
        return 4;
      }
      copy(bgn, end, dst);
      break;
    }
    case osqa::sdcard_read_sector: {
      auto const bgn = sdcard.begin() + data * sector_buffer.size();
      auto const end = bgn + sector_buffer.size();
      if (end > sdcard.end()) {
        return 5;
      }
      copy(bgn, end, sector_buffer.data());
      break;
    }
    case osqa::uart_out: {
      int const ch = data & 0xff;
      if (ch == 0x7f) {
        // convert from serial to terminal
        printf("\b \b");
      } else {
        putchar(ch);
      }
      fflush(stdout);
      break;
    }
    case osqa::uart_in: {
      // address does not support write
      return 6;
    }
    case osqa::led: {
      // do nothing when writing to address LED
      break;
    }
    default: {
      for (uint32_t i = 0; i < uint32_t(op_width); ++i) {
        ram[address + i] = uint8_t(data >> (i * 8));
      }
    }
    }
  } else {
    // read op
    switch (address) {
    case osqa::sdcard_status: {
      data = 6;
      break;
    }
    case osqa::sdcard_busy: {
      data = 0;
      break;
    }
    case osqa::sdcard_next_byte: {
      data = sector_buffer.at(sector_buffer_index);
      sector_buffer_index = (sector_buffer_index + 1) % sector_buffer.size();
      break;
    }
    case osqa::sdcard_read_sector: {
      // address does not support read
      return 7;
    }
    case osqa::sdcard_write_sector: {
      // address does not support read
      return 8;
    }
    case osqa::led: {
      // address does not support read
      return 9;
    }
    case osqa::uart_out: {
      data = 0xffff'ffff; // -1
      break;
    }
    case osqa::uart_in: {
      int const ch = getchar();
      // convert terminal to serial
      switch (ch) {
      case EOF:             // no data available
        data = 0xffff'ffff; // -1
        break;
      case '\n': // newline to carriage return
        data = '\r';
        break;
      case 0x08: // backspace
        data = 0x7f;
        break;
      default:
        data = uint32_t(ch);
        break;
      }
#ifdef LOG_UART_IN_TO_STDERR
      if (ch != -1) {
        fputc(char(data), stderr);
      }
#endif
      break;
    }
    default: {
      data = 0;
      for (uint32_t i = 0; i < uint32_t(op_width); ++i) {
        data |= uint32_t(ram[address + i]) << (i * 8);
      }
    }
    }
  }

  return 0;
}

static auto load_file(char const *file_name, char const *data_name,
                      vector<uint8_t> &data) -> bool {

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

auto main(int argc, char **argv) -> int {
  if (argc != 3) {
    printf("Usage: %s <firmware.bin> <sdcard.bin>\n", argv[0]);
    return 1;
  }

  if (!load_file(argv[1], "Firmware", ram)) {
    return 2;
  }

  if (!load_file(argv[2], "SD card", sdcard)) {
    return 3;
  }

  // configure terminal to not echo and enable non-blocking getchar()
  tcgetattr(STDIN_FILENO, &saved_termios);
  struct termios newt = saved_termios;
  newt.c_lflag &= tcflag_t(~(ICANON | ECHO));
  tcsetattr(STDIN_FILENO, TCSANOW, &newt);
  { // note: code block to not get shadowed by 'flags' in 'atexit'
    int const flags = fcntl(STDIN_FILENO, F_GETFL, 0);
    fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK);
  }
  // reset terminal settings at exit
  atexit([] {
    tcsetattr(STDIN_FILENO, TCSANOW, &saved_termios);
    int const flags = fcntl(STDIN_FILENO, F_GETFL, 0);
    fcntl(STDIN_FILENO, F_SETFL, flags & ~O_NONBLOCK);
  });

  rv32i::cpu cpu{bus};

  while (true) {
    if (rv32i::cpu::status const s = cpu.tick()) {
      printf("CPU error: %d\n", s);
      return int32_t(s);
    }
  }

  return 0;
}
