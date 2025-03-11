//
// RISC-V RV32I emulator
//
// from https://github.com/alexriegler12/riscv
//  re-written to C++23 with modifications
//
// reviewed: 2025-03-10
//
#pragma once

#include <cstdint>
#include <cstdio>

namespace rv32i {

using namespace std;

enum class bus_op_width { BYTE = 1, HALF_WORD = 2, WORD = 4 };

using bus_status = uint32_t;

using bus = auto (*)(uint32_t address, bus_op_width op_width, bool is_store,
                     uint32_t &data) -> bus_status;

class cpu final {

  bus bus_{};
  uint32_t pc_{};
  int32_t regs_[32]{};

public:
  using status = uint32_t;

  cpu(bus const bus_callback, uint32_t const initial_pc = 0)
      : bus_{bus_callback}, pc_{initial_pc} {}

  auto tick() -> status {
    regs_[0] = 0;
    uint32_t next_pc = pc_ + 4;
    uint32_t instruction = 0;
    if (bus_status const s =
            bus_(pc_, bus_op_width::WORD, false, instruction)) {
      return 1000 + s;
    }
#ifdef RV32I_DEBUG
    printf("pc 0x%08x instr 0x%08x ", pc_, instruction);
#endif
    uint32_t const opcode = OPCODE_from(instruction);
    switch (opcode) {
    //-----------------------------------------------------------------------
    case OPCODE_LUI: //                                                   LUI
    {
      uint32_t const rd = RD_from(instruction);
      uint32_t const U_imm20 = U_imm20_from(instruction);
#ifdef RV32I_DEBUG
      printf("lui x%u, 0x%x\n", rd, U_imm20 >> 12);
#endif
      regs_[rd] = int32_t(U_imm20);
      break;
    }
    //-----------------------------------------------------------------------
    case OPCODE_LOGICAL_IMM: //                         logical ops immediate
    {
      uint32_t const rs1 = RS1_from(instruction);
      uint32_t const rd = RD_from(instruction);
      int32_t const I_imm12 = I_imm12_from(instruction);
      uint32_t const funct3 = FUNCT3_from(instruction);
      switch (funct3) {
      case FUNCT3_ADDI: {
#ifdef RV32I_DEBUG
        printf("addi x%u, x%u, %d\n", rd, rs1, I_imm12);
#endif
        regs_[rd] = regs_[rs1] + I_imm12;
        break;
      }
      case FUNCT3_SLTI: {
#ifdef RV32I_DEBUG
        printf("slti x%u, x%u, %d\n", rd, rs1, I_imm12);
#endif
        regs_[rd] = regs_[rs1] < I_imm12 ? 1 : 0;
        break;
      }
      case FUNCT3_SLTIU: {
#ifdef RV32I_DEBUG
        printf("sltiu x%u, x%u, %d\n", rd, rs1, I_imm12);
#endif
        regs_[rd] = uint32_t(regs_[rs1]) < uint32_t(I_imm12) ? 1 : 0;
        break;
      }
      case FUNCT3_XORI: {
#ifdef RV32I_DEBUG
        printf("xori x%u, x%u, %d\n", rd, rs1, I_imm12);
#endif
        regs_[rd] = regs_[rs1] ^ I_imm12;
        break;
      }
      case FUNCT3_ORI: {
#ifdef RV32I_DEBUG
        printf("ori x%u, x%u, %d\n", rd, rs1, I_imm12);
#endif
        regs_[rd] = regs_[rs1] | I_imm12;
        break;
      }
      case FUNCT3_ANDI: {
#ifdef RV32I_DEBUG
        printf("andi x%u, x%u, %d\n", rd, rs1, I_imm12);
#endif
        regs_[rd] = regs_[rs1] & I_imm12;
        break;
      }
      case FUNCT3_SLLI: {
        uint32_t const shift_amount = RS2_from(instruction);
#ifdef RV32I_DEBUG
        printf("slli x%u, x%u, %u\n", rd, rs1, shift_amount);
#endif
        regs_[rd] = regs_[rs1] << shift_amount;
        break;
      }
      case FUNCT3_SRLI_SRAI: {
        uint32_t const shift_amount = RS2_from(instruction);
        uint32_t const funct7 = FUNCT7_from(instruction);
        switch (funct7) {
        case FUNCT7_SRLI: {
#ifdef RV32I_DEBUG
          printf("srli x%u, x%u, %u\n", rd, rs1, shift_amount);
#endif
          regs_[rd] = int32_t(uint32_t(regs_[rs1]) >> shift_amount);
          break;
        }
        case FUNCT7_SRAI: {
#ifdef RV32I_DEBUG
          printf("srai x%u, x%u, %u\n", rd, rs1, shift_amount);
#endif
          regs_[rd] = regs_[rs1] >> shift_amount;
          break;
        }
        default:
          return 1;
        }
        break;
      }
      default:
        return 2;
      }
      break;
    }
    //-----------------------------------------------------------------------
    case OPCODE_LOGICAL: //                                       logical ops
    {
      uint32_t const rs1 = RS1_from(instruction);
      uint32_t const rs2 = RS2_from(instruction);
      uint32_t const rd = RD_from(instruction);
      uint32_t const funct3 = FUNCT3_from(instruction);
      switch (funct3) {
      case FUNCT3_ADD_SUB: {
        uint32_t const FUNCT7 = FUNCT7_from(instruction);
        switch (FUNCT7) {
        case FUNCT7_ADD: {
#ifdef RV32I_DEBUG
          printf("add x%u, x%u, x%u\n", rd, rs1, rs2);
#endif
          regs_[rd] = regs_[rs1] + regs_[rs2];
          break;
        }
        case FUNCT7_SUB: {
#ifdef RV32I_DEBUG
          printf("sub x%u, x%u, x%u\n", rd, rs1, rs2);
#endif
          regs_[rd] = regs_[rs1] - regs_[rs2];
          break;
        }
        default:
          return 3;
        }
        break;
      }
      case FUNCT3_SLL: {
#ifdef RV32I_DEBUG
        printf("sll x%u, x%u, x%u\n", rd, rs1, rs2);
#endif
        regs_[rd] = regs_[rs1] << (regs_[rs2] & 0x1f);
        break;
      }
      case FUNCT3_SLT: {
#ifdef RV32I_DEBUG
        printf("slt x%u, x%u, x%u\n", rd, rs1, rs2);
#endif
        regs_[rd] = regs_[rs1] < regs_[rs2] ? 1 : 0;
        break;
      }
      case FUNCT3_SLTU: {
#ifdef RV32I_DEBUG
        printf("sltu x%u, x%u, x%u\n", rd, rs1, rs2);
#endif
        regs_[rd] = uint32_t(regs_[rs1]) < uint32_t(regs_[rs2]) ? 1 : 0;
        break;
      }
      case FUNCT3_XOR: {
#ifdef RV32I_DEBUG
        printf("xor x%u, x%u, x%u\n", rd, rs1, rs2);
#endif
        regs_[rd] = regs_[rs1] ^ regs_[rs2];
        break;
      }
      case FUNCT3_SRL_SRA: {
        uint32_t const shift_amount = regs_[rs2] & 0x1f;
        uint32_t const funct7 = FUNCT7_from(instruction);
        switch (funct7) {
        case FUNCT7_SRL: {
#ifdef RV32I_DEBUG
          printf("srl x%u, x%u, x%u\n", rd, rs1, rs2);
#endif
          regs_[rd] = int32_t(uint32_t(regs_[rs1]) >> shift_amount);
          break;
        }
        case FUNCT7_SRA: {
#ifdef RV32I_DEBUG
          printf("sra x%u, x%u, x%u\n", rd, rs1, rs2);
#endif
          regs_[rd] = regs_[rs1] >> shift_amount;
          break;
        }
        default:
          return 4;
        }
        break;
      }
      case FUNCT3_OR: {
#ifdef RV32I_DEBUG
        printf("or x%u, x%u, x%u\n", rd, rs1, rs2);
#endif
        regs_[rd] = regs_[rs1] | regs_[rs2];
        break;
      }
      case FUNCT3_AND: {
#ifdef RV32I_DEBUG
        printf("and x%u, x%u, x%u\n", rd, rs1, rs2);
#endif
        regs_[rd] = regs_[rs1] & regs_[rs2];
        break;
      }
      default:
        return 5;
      }
      break;
    }
    //-----------------------------------------------------------------------
    case OPCODE_STORE: //                                               store
    {
      using enum bus_op_width;
      uint32_t const rs1 = RS1_from(instruction);
      uint32_t const rs2 = RS2_from(instruction);
      int32_t const S_imm12 = S_imm12_from(instruction);
      uint32_t const address = uint32_t(regs_[rs1] + S_imm12);
      uint32_t value = uint32_t(regs_[rs2]);
      uint32_t const funct3 = FUNCT3_from(instruction);
      switch (funct3) {
      case FUNCT3_SB: {
#ifdef RV32I_DEBUG
        printf("sb x%u, %d(x%u)\n", rs2, S_imm12, rs1);
#endif
        if (bus_status const s = bus_(address, BYTE, true, value)) {
          return 1100 + s;
        }
        break;
      }
      case FUNCT3_SH: {
#ifdef RV32I_DEBUG
        printf("sh x%u, %d(x%u)\n", rs2, S_imm12, rs1);
#endif
        if (bus_status const s = bus_(address, HALF_WORD, true, value)) {
          return 1200 + s;
        }
        break;
      }
      case FUNCT3_SW: {
#ifdef RV32I_DEBUG
        printf("sw x%u, %d(x%u)\n", rs2, S_imm12, rs1);
#endif
        if (bus_status const s = bus_(address, WORD, true, value)) {
          return 1300 + s;
        }
        break;
      }
      default:
        return 6;
      }
      break;
    }
    //-----------------------------------------------------------------------
    case OPCODE_LOAD: //                                                 load
    {
      using enum bus_op_width;
      uint32_t const rs1 = RS1_from(instruction);
      uint32_t const rd = RD_from(instruction);
      int32_t const I_imm12 = I_imm12_from(instruction);
      uint32_t const address = uint32_t(regs_[rs1] + I_imm12);
      uint32_t value = 0;
      uint32_t const funct3 = FUNCT3_from(instruction);
      switch (funct3) {
      case FUNCT3_LB: {
#ifdef RV32I_DEBUG
        printf("lb x%u, %d(x%u)\n", rd, I_imm12, rs1);
#endif
        if (bus_status const s = bus_(address, BYTE, false, value)) {
          return 1400 + s;
        }
        regs_[rd] = int32_t(value & 0x80 ? 0xffff'ff00 | value : value);
        break;
      }
      case FUNCT3_LH: {
#ifdef RV32I_DEBUG
        printf("lh x%u, %d(x%u)\n", rd, I_imm12, rs1);
#endif
        if (bus_status const s = bus_(address, HALF_WORD, false, value)) {
          return 1500 + s;
        }
        regs_[rd] = int32_t(value & 0x8000 ? 0xffff'0000 | value : value);
        break;
      }
      case FUNCT3_LW: {
#ifdef RV32I_DEBUG
        printf("lw x%u, %d(x%u)\n", rd, I_imm12, rs1);
#endif
        if (bus_status const s = bus_(address, WORD, false, value)) {
          return 1600 + s;
        }
        regs_[rd] = int32_t(value);
        break;
      }
      case FUNCT3_LBU: {
#ifdef RV32I_DEBUG
        printf("lbu x%u, %d(x%u)\n", rd, I_imm12, rs1);
#endif
        if (bus_status const s = bus_(address, BYTE, false, value)) {
          return 1700 + s;
        }
        regs_[rd] = int32_t(value);
        break;
      }
      case FUNCT3_LHU: {
#ifdef RV32I_DEBUG
        printf("lhu x%u, %d(x%u)\n", rd, I_imm12, rs1);
#endif
        if (bus_status const s = bus_(address, HALF_WORD, false, value)) {
          return 1800 + s;
        }
        regs_[rd] = int32_t(value);
        break;
      }
      default:
        return 7;
      }
      break;
    }
    //-----------------------------------------------------------------------
    case OPCODE_AUIPC: //                                               AUIPC
    {
      uint32_t const rd = RD_from(instruction);
      uint32_t const U_imm20 = U_imm20_from(instruction);
#ifdef RV32I_DEBUG
      printf("auipc x%u, 0x%x\n", rd, U_imm20 >> 12);
#endif
      regs_[rd] = int32_t(pc_ + U_imm20);
      break;
    }
    //-----------------------------------------------------------------------
    case OPCODE_JAL: //                                                   JAL
    {
      uint32_t const rd = RD_from(instruction);
      int32_t const J_imm20 = J_imm20_from(instruction);
#ifdef RV32I_DEBUG
      printf("jal x%u, 0x%x\n", rd, pc_ + uint32_t(J_imm20));
#endif
      regs_[rd] = int32_t(pc_ + 4);
      next_pc = uint32_t(int32_t(pc_) + J_imm20);
      break;
    }
    //-----------------------------------------------------------------------
    case OPCODE_JALR: //                                                 JALR
    {
      uint32_t const rs1 = RS1_from(instruction);
      uint32_t const rd = RD_from(instruction);
      int32_t const I_imm12 = I_imm12_from(instruction);
#ifdef RV32I_DEBUG
      printf("jalr x%u, %d(x%u)\n", rd, I_imm12, rs1);
#endif
      regs_[rd] = int32_t(pc_ + 4);
      next_pc = uint32_t(regs_[rs1] + I_imm12);
      break;
    }
    //-----------------------------------------------------------------------
    case OPCODE_BRANCH: //                                           branches
    {
      uint32_t const rs1 = RS1_from(instruction);
      uint32_t const rs2 = RS2_from(instruction);
      int32_t const B_imm12 = B_imm12_from(instruction);
      uint32_t const branch_taken_pc = uint32_t(int32_t(pc_) + B_imm12);
      uint32_t const funct3 = FUNCT3_from(instruction);
      switch (funct3) {
      case FUNCT3_BEQ: {
#ifdef RV32I_DEBUG
        printf("beq x%u, x%u, 0x%x\n", rs1, rs2, branch_taken_pc);
#endif
        if (regs_[rs1] == regs_[rs2]) {
          next_pc = branch_taken_pc;
        }
        break;
      }
      case FUNCT3_BNE: {
#ifdef RV32I_DEBUG
        printf("bne x%u, x%u, 0x%x\n", rs1, rs2, branch_taken_pc);
#endif
        if (regs_[rs1] != regs_[rs2]) {
          next_pc = branch_taken_pc;
        }
        break;
      }
      case FUNCT3_BLT: {
#ifdef RV32I_DEBUG
        printf("blt x%u, x%u, 0x%x\n", rs1, rs2, branch_taken_pc);
#endif
        if (regs_[rs1] < regs_[rs2]) {
          next_pc = branch_taken_pc;
        }
        break;
      }
      case FUNCT3_BGE: {
#ifdef RV32I_DEBUG
        printf("bge x%u, x%u, 0x%x\n", rs1, rs2, branch_taken_pc);
#endif
        if (regs_[rs1] >= regs_[rs2]) {
          next_pc = branch_taken_pc;
        }
        break;
      }
      case FUNCT3_BLTU: {
#ifdef RV32I_DEBUG
        printf("bltu x%u, x%u, 0x%x\n", rs1, rs2, branch_taken_pc);
#endif
        if (uint32_t(regs_[rs1]) < uint32_t(regs_[rs2])) {
          next_pc = branch_taken_pc;
        }
        break;
      }
      case FUNCT3_BGEU: {
#ifdef RV32I_DEBUG
        printf("bgeu x%u, x%u, 0x%x\n", rs1, rs2, branch_taken_pc);
#endif
        if (uint32_t(regs_[rs1]) >= uint32_t(regs_[rs2])) {
          next_pc = branch_taken_pc;
        }
        break;
      }
      default:
        return 8;
      }
      break;
    }
    //-----------------------------------------------------------------------
    default:
      return 9;
    }

    pc_ = next_pc;
    return 0;
  }

  auto reg(uint32_t const num) const -> int32_t { return regs_[num]; }
  auto pc() const -> uint32_t { return pc_; }

private:
  //
  // instruction decoding
  //  see: /notes/riscv-docs/rv32i-base-instruction-set.png
  //

  static auto constexpr OPCODE_from(uint32_t const instruction) -> uint32_t {
    return extract_bits(instruction, 0, 6, 0);
  }

  static auto constexpr FUNCT3_from(uint32_t const instruction) -> uint32_t {
    return extract_bits(instruction, 12, 14, 0);
  }

  static auto constexpr FUNCT7_from(uint32_t const instruction) -> uint32_t {
    return extract_bits(instruction, 25, 31, 0);
  }

  static auto constexpr RS1_from(uint32_t const instruction) -> uint32_t {
    return extract_bits(instruction, 15, 19, 0);
  }

  static auto constexpr RS2_from(uint32_t const instruction) -> uint32_t {
    return extract_bits(instruction, 20, 24, 0);
  }

  static auto constexpr RD_from(uint32_t const instruction) -> uint32_t {
    return extract_bits(instruction, 7, 11, 0);
  }

  //
  // immedidates decoding
  //  see /notes/riscv-docs/riscv-immediate-encodings.png
  //

  static auto constexpr U_imm20_from(uint32_t const instruction) -> uint32_t {
    return extract_bits(instruction, 12, 31, 12);
  }

  static auto constexpr I_imm12_from(uint32_t const instruction) -> int32_t {
    uint32_t const bits = extract_bits(instruction, 20, 31, 0);
    if (instruction & 0x8000'0000) {
      // sign extend
      return int32_t(0xffff'f000 | bits);
    } else {
      return int32_t(bits);
    }
  }

  static auto constexpr S_imm12_from(uint32_t const instruction) -> int32_t {
    uint32_t const bits = extract_bits(instruction, 7, 11, 0) |
                          extract_bits(instruction, 25, 31, 5);
    if (instruction & 0x8000'0000) {
      // sign extend
      return int32_t(0xffff'f000 | bits);
    } else {
      return int32_t(bits);
    }
  }

  static auto constexpr B_imm12_from(uint32_t const instruction) -> int32_t {
    uint32_t const bits = extract_bits(instruction, 8, 11, 1) |
                          extract_bits(instruction, 25, 30, 5) |
                          extract_bits(instruction, 7, 7, 11) |
                          extract_bits(instruction, 31, 31, 12);
    if (instruction & 0x8000'0000) {
      // sign extend
      return int32_t(0xffff'e000 | bits);
      // note: not 0xffff'f000 because of the always 0 first bit
      //       making the immediate value 13 bits
    } else {
      return int32_t(bits);
    }
  }

  static auto constexpr J_imm20_from(uint32_t const instruction) -> int32_t {
    uint32_t const bits = extract_bits(instruction, 21, 30, 1) |
                          extract_bits(instruction, 20, 20, 11) |
                          extract_bits(instruction, 12, 19, 12) |
                          extract_bits(instruction, 31, 31, 20);
    if (instruction & 0x8000'0000) {
      // sign extend
      return int32_t(0xffe0'0000 | bits);
      // note: not 0xfff0'0000 because of the always 0 first bit
      //       making the immediate value 21 bits
    } else {
      return int32_t(bits);
    }
  }

  static auto constexpr extract_bits(uint32_t const instruction,
                                     uint32_t const from_bit_num,
                                     uint32_t const through_bit_num,
                                     uint32_t const place_at) -> uint32_t {
    uint32_t const mask = (1u << (through_bit_num - from_bit_num + 1)) - 1;
    uint32_t const shifted = instruction >> from_bit_num;
    uint32_t const masked = shifted & mask;
    return masked << place_at;
  }

  //
  // encoding bits
  //  see: /notes/riscv-docs/rv32i-base-instruction-set.png
  //

  static uint32_t constexpr OPCODE_LUI = 0b01101'11;

  static uint32_t constexpr OPCODE_LOGICAL_IMM = 0b00100'11;
  static uint32_t constexpr FUNCT3_ADDI = 0b000;
  static uint32_t constexpr FUNCT3_SLTI = 0b010;
  static uint32_t constexpr FUNCT3_SLTIU = 0b011;
  static uint32_t constexpr FUNCT3_XORI = 0b100;
  static uint32_t constexpr FUNCT3_ORI = 0b110;
  static uint32_t constexpr FUNCT3_ANDI = 0b111;
  static uint32_t constexpr FUNCT3_SLLI = 0b001;
  static uint32_t constexpr FUNCT3_SRLI_SRAI = 0b101;
  static uint32_t constexpr FUNCT7_SRLI = 0b000'0000;
  static uint32_t constexpr FUNCT7_SRAI = 0b010'0000;

  static uint32_t constexpr OPCODE_LOGICAL = 0b01100'11;
  static uint32_t constexpr FUNCT3_ADD_SUB = 0;
  static uint32_t constexpr FUNCT7_ADD = 0b000'0000;
  static uint32_t constexpr FUNCT7_SUB = 0b010'0000;
  static uint32_t constexpr FUNCT3_SLL = 0b001;
  static uint32_t constexpr FUNCT3_SLT = 0b010;
  static uint32_t constexpr FUNCT3_SLTU = 0b011;
  static uint32_t constexpr FUNCT3_XOR = 0b100;
  static uint32_t constexpr FUNCT3_SRL_SRA = 0b101;
  static uint32_t constexpr FUNCT7_SRL = 0b000'0000;
  static uint32_t constexpr FUNCT7_SRA = 0b010'0000;
  static uint32_t constexpr FUNCT3_OR = 0b110;
  static uint32_t constexpr FUNCT3_AND = 0b111;

  static uint32_t constexpr OPCODE_STORE = 0b01000'11;
  static uint32_t constexpr FUNCT3_SB = 0b000;
  static uint32_t constexpr FUNCT3_SH = 0b001;
  static uint32_t constexpr FUNCT3_SW = 0b010;

  static uint32_t constexpr OPCODE_LOAD = 0b00000'11;
  static uint32_t constexpr FUNCT3_LB = 0b000;
  static uint32_t constexpr FUNCT3_LH = 0b001;
  static uint32_t constexpr FUNCT3_LW = 0b010;
  static uint32_t constexpr FUNCT3_LBU = 0b100;
  static uint32_t constexpr FUNCT3_LHU = 0b101;

  static uint32_t constexpr OPCODE_AUIPC = 0b00101'11;

  static uint32_t constexpr OPCODE_JAL = 0b11011'11;

  static uint32_t constexpr OPCODE_JALR = 0b11001'11;

  static uint32_t constexpr OPCODE_BRANCH = 0b11000'11;
  static uint32_t constexpr FUNCT3_BEQ = 0b000;
  static uint32_t constexpr FUNCT3_BNE = 0b001;
  static uint32_t constexpr FUNCT3_BLT = 0b100;
  static uint32_t constexpr FUNCT3_BGE = 0b101;
  static uint32_t constexpr FUNCT3_BLTU = 0b110;
  static uint32_t constexpr FUNCT3_BGEU = 0b111;
};

} // namespace rv32i
