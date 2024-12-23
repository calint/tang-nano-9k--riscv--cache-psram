#include <cstdint>
#include <fstream>
#include <iostream>
#include <termios.h>
#include <unistd.h>
#include <vector>
// #define RISCV_DEBUG
#include "riscv.hpp"

unsigned constexpr LED = 0xffffffff;
unsigned constexpr UART_OUT = 0xfffffffe;
unsigned constexpr UART_IN = 0xfffffffd;

static std::vector<int8_t> ram(2 * 1024 * 1024, -1);

static struct termios saved_termio;

auto bus(unsigned const address, bus_op_width const bus_op_width,
         bool const is_store, unsigned *const data) -> unsigned {

  unsigned const width = static_cast<unsigned>(bus_op_width);
  if (address + width > ram.size() && address != UART_OUT &&
      address != UART_IN && address != LED) {
    return 1;
  }

  if (is_store) {
    if (address == UART_OUT) {
      char const ch = static_cast<char>(*data & 0xFF);
      if (ch == 0x7f) {
        // convert from serial to terminal
        std::cout << "\b \b";
      } else {
        std::cout << ch;
      }
      std::cout.flush();
    } else if (address == UART_IN) {
      // do nothing when writing to address UART_IN
    } else if (address == LED) {
      // do nothing when writing to address LED
    } else {
      for (unsigned i = 0; i < width; ++i) {
        ram[address + i] = (*data >> (i * 8)) & 0xFF;
      }
    }
  } else {
    if (address == UART_OUT) {
      *data = 0;
    } else if (address == UART_IN) {
      int const ch = getchar();
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
    } else if (address == LED) {
      // do nothing when reading from address LED
    } else {
      *data = 0;
      for (unsigned i = 0; i < width; ++i) {
        *data |= (ram[address + i] & 0xFF) << (i * 8);
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
  tcgetattr(STDIN_FILENO, &saved_termio);
  newt = saved_termio;
  newt.c_lflag &= ~(ICANON | ECHO);
  tcsetattr(STDIN_FILENO, TCSANOW, &newt);

  atexit([]() -> void { tcsetattr(STDIN_FILENO, TCSANOW, &saved_termio); });

  std::ifstream file{argv[1], std::ios::binary | std::ios::ate};
  if (!file) {
    std::cerr << "Error opening file" << std::endl;
    return 1;
  }

  std::streamsize const size = file.tellg();
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

  rv32i cpu{bus, 0x0};

  while (true) {
    if (const unsigned err = cpu.tick()) {
      std::cout << "Error: " << err << std::endl;
      return err;
    }
  }

  return 0;
}