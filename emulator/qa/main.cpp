#include "../src/rv32i.hpp"
#include <fstream>
#include <vector>

using namespace std;

// initialize RAM with -1 being the default value from flash
static vector<uint8_t> ram(8 * 1024, 0xff);

// bus callback
static auto bus(uint32_t const address, rv32i::bus_op_width const op_width,
                bool const is_store, uint32_t &data) -> rv32i::bus_status {

  if (is_store) {
    for (uint32_t i = 0; i < uint32_t(op_width); ++i) {
      ram[address + i] = uint8_t(data >> (i * 8));
    }
  } else {
    data = 0;
    for (uint32_t i = 0; i < uint32_t(op_width); ++i) {
      data |= uint32_t(ram[address + i]) << (i * 8);
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

auto assert(bool const condition, int32_t const test_number) -> void {
  if (!condition) {
    printf("test %d FAILED\n", test_number);
    exit(test_number);
  }
}

auto main([[maybe_unused]] int argc, [[maybe_unused]] char **argv) -> int {

  if (!load_file("ram.bin", "Firmware", ram)) {
    return 1;
  }

  // run CPU

  rv32i::cpu cpu{bus};

  // 0: 00000013 addi x0,x0,0
  cpu.tick();

  // 4: 12345537 lui x10,0x12345
  cpu.tick();
  assert(cpu.reg(10) == 0x1234'5000, 1);

  // 8: 67850513 addi x10,x10,1656 # 12345678
  cpu.tick();
  assert(cpu.reg(10) == 0x1234'5678, 2);

  // c: 00300593 addi x11,x0,3
  cpu.tick();
  assert(cpu.reg(11) == 3, 3);

  // 10: 0045a613 slti x12,x11,4
  cpu.tick();
  assert(cpu.reg(12) == 1, 4);

  // 14: fff5a613 slti x12,x11,-1
  cpu.tick();
  assert(cpu.reg(12) == 0, 5);

  // 18: 0045b613 sltiu x12,x11,4
  cpu.tick();
  assert(cpu.reg(12) == 1, 6);

  // 1c: fff5b613 sltiu x12,x11,-1
  cpu.tick();
  assert(cpu.reg(12) == 1, 7);

  // 20: fff64693 xori x13,x12,-1
  cpu.tick();
  assert(cpu.reg(13) == int32_t(0xffff'fffe), 8);

  // 24: 0016e693 ori x13,x13,1
  cpu.tick();
  assert(cpu.reg(13) == int32_t(0xffff'ffff), 9);

  // 28: 0026f693 andi x13,x13,2
  cpu.tick();
  assert(cpu.reg(13) == 2, 10);

  // 2c: 00369693 slli x13,x13,0x3
  cpu.tick();
  assert(cpu.reg(13) == 16, 11);

  // 30: 0036d693 srli x13,x13,0x3
  cpu.tick();
  assert(cpu.reg(13) == 2, 12);

  // 34: fff6c693 xori x13,x13,-1
  cpu.tick();
  assert(cpu.reg(13) == -3, 13);

  // 38: 4016d693 srai x13,x13,0x1
  cpu.tick();
  assert(cpu.reg(13) == -2, 14);

  // 3c: 00c68733 add x14,x13,x12
  cpu.tick();
  assert(cpu.reg(14) == -1, 15);

  // 40: 40c70733 sub x14,x14,x12
  cpu.tick();
  assert(cpu.reg(14) == -2, 16);

  // 44: 00c617b3 sll x15,x12,x12
  cpu.tick();
  assert(cpu.reg(15) == 2, 17);

  // 48: 00f62833 slt x16,x12,x15
  cpu.tick();
  assert(cpu.reg(16) == 1, 18);

  // 4c: 00c62833 slt x16,x12,x12
  cpu.tick();
  assert(cpu.reg(16) == 0, 19);

  // 50: 00d83833 sltu x16,x16,x13
  cpu.tick();
  assert(cpu.reg(16) == 1, 20);

  // 54: 00d84833 xor x17,x16,x13
  cpu.tick();
  assert(cpu.reg(17) == -1, 21);

  // 58: 0105d933 srl x18,x11,x16
  cpu.tick();
  assert(cpu.reg(18) == 1, 22);

  // 5c: 4108d933 sra x18,x17,x16
  cpu.tick();
  assert(cpu.reg(18) == -1, 23);

  // 60: 00b869b3 or x19,x16,x11
  cpu.tick();
  assert(cpu.reg(19) == 3, 24);

  // 64: 0109f9b3 and x19,x19,x16
  cpu.tick();
  assert(cpu.reg(19) == 1, 25);

  // 68: 00001a37 lui x20,0x1
  cpu.tick();
  assert(cpu.reg(20) == 0x0000'1000, 26);

  // 6c: 013a2223 sw x19,4(x20) # [1004] = 0x0000_0001
  cpu.tick();

  // 70: 004a2a83 lw x21,4(x20) # x21 = [1004] = 0x0000_0001
  cpu.tick();
  assert(cpu.reg(21) == 1, 27);

  // 74: 013a1323 sh x19,6(x20) # [1006] = 0x0001
  cpu.tick();

  // 78: 006a1a83 lh x21,6(x20) # x21 = [1006] = 0x00001
  cpu.tick();
  assert(cpu.reg(21) == 1, 28);

  // 7c: 013a03a3 sb x19,7(x20) # [1007] = 0x01
  cpu.tick();

  // 80: 007a0a83 lb x21,7(x20) # x21 = [1007] = 0x01
  cpu.tick();
  assert(cpu.reg(21) == 1, 29);

  // 84: 004a0a83 lb x21,4(x20) # x21 = [1004] = 0x01
  cpu.tick();
  assert(cpu.reg(21) == 1, 30);

  // 88: 006a1a83 lh sx21,6(x20) # x21 = [1006] = 0x0101
  cpu.tick();
  assert(cpu.reg(21) == 0x0000'01'01, 31);

  // 8c: 004a2a83 lw x21,4(x20) # x21 = [1004] = 0x01010001
  cpu.tick();
  assert(cpu.reg(21) == 0x0101'0001, 32);

  // 90: 011a2023 sw x17,0(x20) # [1000] = 0xffff_ffff
  cpu.tick();

  // 94: 000a4a83 lbu x21,0(x20) # x21 = [1000] = 0xff
  cpu.tick();
  assert(cpu.reg(21) == 0xff, 33);

  // 98: 002a5a83 lhu x21,2(x20) # x21 = [1000] = 0xffff
  cpu.tick();
  assert(cpu.reg(21) == 0xffff, 34);

  // 9c: 001a8b13 addi x22,x21,1 # x22 = 0xffff + 1 = 0x1_0000
  cpu.tick();
  assert(cpu.reg(22) == 0x1'0000, 35);

  // a0: 360000ef jal x1,400 <lbl_jal>
  cpu.tick();
  assert(cpu.pc() == 0x400, 36);

  // 400: 00008067 jalr x1,0(x1)
  // test BUG 1
  cpu.tick();
  assert(cpu.pc() == 0xa4, 37);

  // a4: 376b0263  beq x22,x22,408 <lbl_beq> # # x22 == x22 -> branch taken
  cpu.tick();
  assert(cpu.pc() == 0x408, 38);

  // 408: ca1ff06f jal x0,a8 <lbl1>
  cpu.tick();
  assert(cpu.pc() == 0xa8, 39);

  // a8: 375b1463 bne x22,x21,410 <lbl_bne> # 0x1_0000 != 0xffff -> branch taken
  cpu.tick();
  assert(cpu.pc() == 0x410, 40);

  // 410: c9dff06f jal x0,ac <lbl2>
  cpu.tick();
  assert(cpu.pc() == 0xac, 41);

  // ac: 376ac663 blt x21,x22,418 <lbl_blt> # 0xffff < 0x1_0000 -> branch taken
  cpu.tick();
  assert(cpu.pc() == 0x418, 42);

  // 418: c99ff06f jal x0,b0 <lbl3>
  cpu.tick();
  assert(cpu.pc() == 0xb0, 43);

  // b0: 375b5863 bge x22,x21,420 <lbl_bge> # 0x1_0000 >= 0xffff -> branch taken
  cpu.tick();
  assert(cpu.pc() == 0x420, 44);

  // 420: c95ff06f jal x0,b4 <lbl4>
  cpu.tick();
  assert(cpu.pc() == 0xb4, 45);

  // b4: 3729ea63 bltu x19,x18,428 <lbl_bltu> # 1 < 0xffff_ffff -> branch taken
  cpu.tick();
  assert(cpu.pc() == 0x428, 46);

  // 428: c91ff06f jal x0,b8 <lbl5>
  cpu.tick();
  assert(cpu.pc() == 0xb8, 47);

  // b8: 37397c63 bgeu x18,x19,430 <lbl_bgeu> # 0xffff_ffff > 1 -> branch taken
  cpu.tick();
  assert(cpu.pc() == 0x430, 48);

  // 430: c8dff06f jal x0,bc <lbl6>
  cpu.tick();
  assert(cpu.pc() == 0xbc, 49);

  // bc: 355b0663 beq x22,x21,408 <lbl_beq> # 0x1_0000 != 0xffff -> branch not
  // taken
  cpu.tick();
  assert(cpu.pc() == 0xc0, 50);

  // c0: 355a9463 bne x21,x21,408 <lbl_beq> # 0xffff == 0xffff -> branch not
  // taken
  cpu.tick();
  assert(cpu.pc() == 0xc4, 51);

  // c4: 355b4a63 blt x22,x21,418 <lbl_blt> # 0x1_0000 > 0xffff -> branch not
  // taken
  cpu.tick();
  assert(cpu.pc() == 0xc8, 52);

  // c8: 356adc63 bge x21,x22,420 <lbl_bge> # 0xffff < 0x1_0000 -> branch not
  // taken
  cpu.tick();
  assert(cpu.pc() == 0xcc, 53);

  // cc: 35396e63 bltu x18,x19,428 <lbl_bltu> # 0xffff_ffff > 1 -> branch not
  // taken
  cpu.tick();
  assert(cpu.pc() == 0xd0, 54);

  // d0: 3729f063 bgeu x19,x18,430 <lbl_bgeu> # 1 < 0xffff_ffff -> branch not
  // taken
  cpu.tick();
  assert(cpu.pc() == 0xd4, 55);

  // d4: 364000ef jal x1,438 <lbl_auipc>
  cpu.tick();
  assert(cpu.pc() == 0x438, 56);

  // 438: fffff117 auipc x2,0xfffff # 0x0438 + 0xffff_f0000 (-4096) == -3016 =
  // 0xffff_f438
  cpu.tick();
  assert(cpu.reg(2) == int32_t(0xffff'f438), 57);

  // 43c: 00008067 jalr x1,0(x1)
  // test BUG 1
  cpu.tick();
  assert(cpu.pc() == 0xd8, 58);

  return 0;
}