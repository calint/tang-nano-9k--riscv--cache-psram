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
static vector<int8_t> ram(osqa::memory_end, -1);

// initialize SD card 1 GB
static vector<int8_t> sdcard(1024 * 1024 * 1024, 0);

// sdcard sector buffer
static vector<int8_t> sector_buffer(512, 0);
static size_t sector_buffer_index;

// preserved terminal settings
static struct termios saved_termios;

// bus callback
static auto bus(uint32_t const address, rv32i::bus_op_width const op_width,
                bool const is_store, uint32_t &data) -> rv32i::bus_status {

  uint32_t const width = static_cast<uint32_t>(op_width);
  if (address + width > ram.size() && address != osqa::uart_out &&
      address != osqa::uart_in && address != osqa::led &&
      address != osqa::sdcard_busy && address != osqa::sdcard_read_sector &&
      address != osqa::sdcard_next_byte) {
    return 1;
  }

  if (is_store) {
    if (address == osqa::sdcard_read_sector) {
      size_t const ix = data * 512;
      std::copy(sdcard.begin() + ix, sdcard.begin() + ix + 512,
                sector_buffer.begin());
    } else if (address == osqa::uart_out) {
      int const ch = data & 0xff;
      if (ch == 0x7f) {
        // convert from serial to terminal
        printf("\b \b");
      } else {
        putchar(ch);
      }
      fflush(stdout);
    } else if (address == osqa::uart_in) {
      // do nothing when writing to address UART_IN
    } else if (address == osqa::led) {
      // do nothing when writing to address LED
    } else {
      for (uint32_t i = 0; i < width; ++i) {
        ram[address + i] = int8_t(data >> (i * 8));
      }
    }
  } else {
    // read op
    if (address == osqa::sdcard_busy) {
      data = 0;
    } else if (address == osqa::sdcard_next_byte) {
      data = sector_buffer[sector_buffer_index];
      sector_buffer_index = (sector_buffer_index + 1) % 512;
    } else if (address == osqa::uart_out) {
      data = 0xffff'ffff; // -1
    } else if (address == osqa::uart_in) {
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
        data = ch;
        break;
      }
      return 0;
    } else if (address == osqa::led) {
      // do nothing when reading from address LED
    } else {
      data = 0;
      for (uint32_t i = 0; i < width; ++i) {
        data |= (ram[address + i] & 0xff) << (i * 8);
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
    ifstream file{argv[1], ios::binary | ios::ate};
    if (!file) {
      printf("Error opening file '%s'\n", argv[1]);
      return 1;
    }

    streamsize const size = file.tellg();
    if (size == -1) {
      printf("Error determining size of file '%s'\n", argv[1]);
      return 1;
    }

    if (size > streamsize(ram.size())) {
      printf("Firmware size (%zu B) exceeds RAM size (%zu B)\n", size,
             ram.size());
      return 1;
    }

    file.seekg(0, ios::beg);
    if (file.fail()) {
      printf("Error seeking to beginning of file '%s'\n", argv[1]);
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
    ifstream file{argv[2], ios::binary | ios::ate};
    if (!file) {
      printf("Error opening file '%s'\n", argv[2]);
      return 1;
    }

    streamsize const size = file.tellg();
    if (size == -1) {
      printf("Error determining size of file '%s'\n", argv[1]);
      return 1;
    }

    if (size > streamsize(ram.size())) {
      printf("Firmware size (%zu B) exceeds RAM size (%zu B)\n", size,
             ram.size());
      return 1;
    }

    file.seekg(0, ios::beg);
    if (file.fail()) {
      printf("Error seeking to beginning of file '%s'\n", argv[1]);
      return 1;
    }

    if (!file.read(reinterpret_cast<char *>(sdcard.data()), size)) {
      printf("Error reading file '%s'\n", argv[1]);
      return 1;
    }

    file.close();
  }

  // configure terminal to not echo and enable non-blocking getchar()
  struct termios newt;
  tcgetattr(STDIN_FILENO, &saved_termios);
  newt = saved_termios;
  newt.c_lflag &= ~(ICANON | ECHO);
  tcsetattr(STDIN_FILENO, TCSANOW, &newt);

  // reset terminal settings at exit
  atexit([] { tcsetattr(STDIN_FILENO, TCSANOW, &saved_termios); });

  // run CPU

  rv32i::cpu cpu{bus};

  while (true) {
    if (rv32i::cpu::status const s = cpu.tick()) {
      printf("CPU error: %d\n", s);
      return s;
    }
  }

  return 0;
}