#include <array>
#include <cstdint>
#include <cstdio>
#include <fstream>
#include <termios.h>
#include <unistd.h>
#include <vector>
// #define RV32I_DEBUG
#include "rv32i.hpp"
//
#include "main_config.hpp"

using namespace std;

// initialize RAM with -1 being the default value from flash
static vector<uint8_t> ram(osqa::memory_end, 0xff);

// initialize SD card 1 GB
static vector<uint8_t> sdcard(1024 * 1024 * 1024, 0);

// sdcard sector buffer
static array<uint8_t, 512> sector_buffer;
static size_t sector_buffer_index;

// preserved terminal settings
static struct termios saved_termios;

// bus callback
static auto bus(uint32_t const address, rv32i::bus_op_width const op_width,
                bool const is_store, uint32_t &data) -> rv32i::bus_status {

  uint32_t const width = static_cast<uint32_t>(op_width);

  // check if address is not an IO address and outside the memory range
  if (address < osqa::io_addresses_start && address + width > ram.size()) {
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
        return 3;
      }
      copy(bgn, end, dst);
      break;
    }
    case osqa::sdcard_read_sector: {
      int32_t const ix = int32_t(data * sector_buffer.size());
      auto const bgn = sdcard.begin() + ix;
      auto const end = sdcard.begin() + ix + sector_buffer.size();
      if (end > sdcard.end()) {
        return 2;
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
      return 4;
    }
    case osqa::led: {
      // do nothing when writing to address LED
      break;
    }
    default: {
      for (uint32_t i = 0; i < width; ++i) {
        ram[address + i] = uint8_t(data >> (i * 8));
      }
    }
    }
  } else {
    // read op
    switch (address) {
    case osqa::sdcard_status: {
      data = 0;
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
      return 5;
    }
    case osqa::sdcard_write_sector: {
      // address does not support read
      return 6;
    }
    case osqa::led: {
      // address does not support read
      return 7;
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
      break;
    }
    default: {
      data = 0;
      for (uint32_t i = 0; i < width; ++i) {
        data |= uint32_t(ram[address + i]) << (i * 8);
      }
    }
    }
  }

  return 0;
}

auto main(int argc, char **argv) -> int {
  if (argc != 3) {
    printf("Usage: %s <firmware.bin> <sdcard.bin>\n", argv[0]);
    return 1;
  }

  // load firmware
  {
    size_t const arg = 1;

    ifstream file{argv[1], ios::binary | ios::ate};
    if (!file) {
      printf("Error opening file '%s'\n", argv[arg]);
      return 1;
    }

    streamsize const size = file.tellg();
    if (size == -1) {
      printf("Error determining size of file '%s'\n", argv[arg]);
      return 1;
    }

    if (size > streamsize(ram.size())) {
      printf("Firmware size (%zu B) exceeds RAM size (%zu B)\n", size,
             ram.size());
      return 1;
    }

    file.seekg(0, ios::beg);
    if (file.fail()) {
      printf("Error seeking to beginning of file '%s'\n", argv[arg]);
      return 1;
    }

    if (!file.read(reinterpret_cast<char *>(ram.data()), size)) {
      printf("Error reading file '%s'\n", argv[1]);
      return 1;
    }

    file.close();
  }

  // load sdcard
  {
    size_t const arg = 2;

    ifstream file{argv[2], ios::binary | ios::ate};
    if (!file) {
      printf("Error opening file '%s'\n", argv[arg]);
      return 1;
    }

    streamsize const size = file.tellg();
    if (size == -1) {
      printf("Error determining size of file '%s'\n", argv[arg]);
      return 1;
    }

    if (size > streamsize(sdcard.size())) {
      printf("SD card file size (%zu B) exceeds SD card size (%zu B)\n", size,
             sdcard.size());
      return 1;
    }

    file.seekg(0, ios::beg);
    if (file.fail()) {
      printf("Error seeking to beginning of file '%s'\n", argv[arg]);
      return 1;
    }

    if (!file.read(reinterpret_cast<char *>(sdcard.data()), size)) {
      printf("Error reading file '%s'\n", argv[arg]);
      return 1;
    }

    file.close();
  }

  // configure terminal to not echo and enable non-blocking getchar()
  struct termios newt;
  tcgetattr(STDIN_FILENO, &saved_termios);
  newt = saved_termios;
  newt.c_lflag &= tcflag_t(~(ICANON | ECHO));
  tcsetattr(STDIN_FILENO, TCSANOW, &newt);

  // reset terminal settings at exit
  atexit([] { tcsetattr(STDIN_FILENO, TCSANOW, &saved_termios); });

  // run CPU

  rv32i::cpu cpu{bus};

  while (true) {
    if (rv32i::cpu::status const s = cpu.tick()) {
      printf("CPU error: %d\n", s);
      return int32_t(s);
    }
  }

  return 0;
}