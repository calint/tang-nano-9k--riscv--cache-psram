#include <cstdint>
#include <fstream>
#include <iostream>
#include <termios.h>
#include <unistd.h>
#include <vector>
// #define RISCV_DEBUG
#include "riscv.h"

#define LED 0xffffffff
#define UART_OUT 0xfffffffe
#define UART_IN 0xfffffffd

std::vector<int8_t> ram(2 * 1024 * 1024, -1);

struct termios oldt;

rv_uint32 ram_access(const rv_uint32 addr, const RISCV_BUSWIDTH width,
                     const rv_uint32 is_store, rv_uint32 *const data) {
  if (addr + width > ram.size() && addr != UART_OUT && addr != UART_IN &&
      addr != LED) {
    return 1;
  }

  if (is_store) {
    if (addr == UART_OUT) {
      const char ch = static_cast<char>(*data & 0xFF);
      if (ch == 0x7f) {
        // convert from serial to terminal
        std::cout << "\b \b";
      } else {
        std::cout << ch;
      }
      std::cout.flush();
    } else if (addr == UART_IN) {
      // do nothing when writing to address UART_IN
    } else if (addr == LED) {
      // do nothing when writing to address LED
    } else {
      for (rv_uint32 i = 0; i < width; ++i) {
        ram[addr + i] = (*data >> (i * 8)) & 0xFF;
      }
    }
  } else {
    if (addr == UART_OUT) {
      *data = 0;
    } else if (addr == UART_IN) {
      const int ch = getchar();
      if (ch == EOF) {
        *data = 0;
      } else {
        if (ch == '\n') {
          // convert from terminal to serial key code
          *data = '\r';
        } else if (ch == 0x08) {
          // convert from terminal to serial key code
          *data = 0x7f;
        } else {
          *data = ch;
        }
      }
    } else if (addr == LED) {
      // do nothing when reading from address LED
    } else {
      *data = 0;
      for (rv_uint32 i = 0; i < width; ++i) {
        *data |= (ram[addr + i] & 0xFF) << (i * 8);
      }
    }
  }

  return 0;
}

auto main(int argc, char **argv) -> int {
  if (argc != 2) {
    std::cerr << "Usage: " << argv[0] << " <firmware.bin>" << std::endl;
    return 1;
  }

  struct termios newt;
  tcgetattr(STDIN_FILENO, &oldt);
  newt = oldt;
  newt.c_lflag &= ~(ICANON | ECHO);
  tcsetattr(STDIN_FILENO, TCSANOW, &newt);

  atexit([]() -> void { tcsetattr(STDIN_FILENO, TCSANOW, &oldt); });

  std::ifstream file(argv[1], std::ios::binary | std::ios::ate);
  if (!file) {
    std::cerr << "Error opening file" << std::endl;
    return 1;
  }

  const std::streamsize size = file.tellg();
  file.seekg(0, std::ios::beg);

  if (size > static_cast<std::streamsize>(ram.size())) {
    std::cerr << "Firmware size exceeds RAM size" << std::endl;
    return 1;
  }

  if (!file.read(reinterpret_cast<char *>(ram.data()), size)) {
    std::cerr << "Error reading file" << std::endl;
    return 1;
  }

  file.close();

  RISCV cpu;
  riscv_init(&cpu, ram_access, 0x0);

  while (true) {
    if (const rv_uint32 err = riscv_cycle(&cpu)) {
      std::cout << "Error: " << err << std::endl;
      return err;
    }
  }

  return 0;
}