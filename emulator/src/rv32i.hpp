// from https://github.com/alexriegler12/riscv
//  converted to C++23 + some refinements

#pragma once
#include <unistd.h>

namespace rv32i {

enum class bus_op_width { BYTE = 1, HALF_WORD = 2, WORD = 4 };

using bus_status = uint32_t;

using bus = auto (*)(uint32_t address, bus_op_width width, bool is_store,
                     uint32_t &data) -> bus_status;

using cpu_status = uint32_t;

class cpu final {

  bus bus_{};
  uint32_t pc_{};
  uint32_t regs_[32]{};

public:
  cpu(bus const bus_callback, uint32_t const initial_pc = 0)
      : bus_{bus_callback}, pc_{initial_pc} {}

  auto tick() -> cpu_status {
    regs_[0] = 0;
    uint32_t instruction = 0;
    if (rv32i::bus_status s =
            bus_(pc_, bus_op_width::WORD, false, instruction)) {
      return 0x1000 + s;
    }
#ifdef RV32I_DEBUG
    printf("pc 0x%08x instr 0x%08x ", pc, instruction);
#endif
    uint32_t const opcode = OPCODE_from(instruction);
    switch (opcode) {

    case 0x37: // LUI
    {
      uint32_t const rd = RD_from(instruction);
      uint32_t const U_imm20 = U_imm20_from(instruction);
#ifdef RV32I_DEBUG
      printf("lui 0x%x,0x%x\n", rd, U_imm20 >> 12);
#endif
      regs_[rd] = U_imm20;
      break;
    }
    //-----------------------------------------------------------------------
    case 0x13: //                                       logical ops immediate
    {
      uint32_t const rs1 = RS1_from(instruction);
      uint32_t const rd = RD_from(instruction);
      int32_t const I_imm12 = I_imm12_from(instruction);
      uint32_t const funct3 = FUNCT3_from(instruction);
      switch (funct3) {
      case 0x0: // ADDI
      {
#ifdef RV32I_DEBUG
        printf("addi %i,%i\n", rs1, I_imm12);
#endif
        regs_[rd] = regs_[rs1] + I_imm12;
        break;
      }
      case 0x2: // SLTI
      {
#ifdef RV32I_DEBUG
        printf("slti %i,%i\n", rs1, I_imm12);
#endif
        regs_[rd] = int32_t(regs_[rs1]) < I_imm12 ? 1 : 0;
        break;
      }
      case 0x3: // SLTIU
      {
#ifdef RV32I_DEBUG
        printf("sltiu %i,%i\n", rs1, I_imm12);
#endif
        regs_[rd] = regs_[rs1] < uint32_t(I_imm12) ? 1 : 0;
        break;
      }
      case 0x4: // XORI
      {
#ifdef RV32I_DEBUG
        printf("xori %i,%i\n", rs1, I_imm12);
#endif
        regs_[rd] = regs_[rs1] ^ I_imm12;
        break;
      }
      case 0x6: // ORI
      {
#ifdef RV32I_DEBUG
        printf("ori %i,%i\n", rs1, I_imm12);
#endif
        regs_[rd] = regs_[rs1] | I_imm12;
        break;
      }
      case 0x7: // ANDI
      {
#ifdef RV32I_DEBUG
        printf("andi %i,%i\n", rs1, I_imm12);
#endif
        regs_[rd] = regs_[rs1] & I_imm12;
        break;
      }
      case 0x1: // SLLI
      {
        uint32_t const RS2 = RS2_from(instruction);
#ifdef RV32I_DEBUG
        printf("slli %i,%i\n", rs1, RS2);
#endif
        regs_[rd] = regs_[rs1] << RS2;
        break;
      }
      case 0x5: // SRLI / SRAI
      {
        uint32_t const rs2 = RS2_from(instruction);
        uint32_t const funct7 = FUNCT7_from(instruction);
        switch (funct7) {
        case 0x0: // SRLI
        {
#ifdef RV32I_DEBUG
          printf("srli %i,%i\n", rs1, rs2);
#endif
          regs_[rd] = regs_[rs1] >> rs2;
          break;
        }
        case 0x20: // SRAI
        {
#ifdef RV32I_DEBUG
          printf("srai %i,%i\n", rs1, rs2);
#endif
          regs_[rd] = int32_t(regs_[rs1]) >> rs2;
          break;
        }
        default:
          return 0x12;
        }
        break;
      }
      default:
        return 0x13;
      }
      break;
    }
    //-----------------------------------------------------------------------
    case 0x33: //                                                 logical ops
    {
      uint32_t const rs1 = RS1_from(instruction);
      uint32_t const rs2 = RS2_from(instruction);
      uint32_t const rd = RD_from(instruction);
      uint32_t const funct3 = FUNCT3_from(instruction);
      switch (funct3) {
      case 0x0: // ADD / SUB
      {
        uint32_t const FUNCT7 = FUNCT7_from(instruction);
        switch (FUNCT7) {
        case 0x0: // ADD
        {
#ifdef RV32I_DEBUG
          printf("add %i,%i\n", rs1, rs2);
#endif
          regs_[rd] = regs_[rs1] + regs_[rs2];
          break;
        }
        case 0x20: // SUB
        {
#ifdef RV32I_DEBUG
          printf("sub %i,%i\n", rs1, rs2);
#endif
          regs_[rd] = regs_[rs1] - regs_[rs2];
          break;
        }
        default:
          return 0x14;
        }
        break;
      }
      case 0x1: // SLL
      {
#ifdef RV32I_DEBUG
        printf("sll %i,%i\n", rs1, rs2);
#endif
        regs_[rd] = regs_[rs1] << (regs_[rs2] & 0x1f);
        break;
      }
      case 0x2: // SLT
      {
#ifdef RV32I_DEBUG
        printf("slt %i,%i\n", rs1, rs2);
#endif
        regs_[rd] = int32_t(regs_[rs1]) < int32_t(regs_[rs2]) ? 1 : 0;
        break;
      }
      case 0x3: // SLTU
      {
#ifdef RV32I_DEBUG
        printf("sltu %i,%i\n", rs1, rs2);
#endif
        regs_[rd] = regs_[rs1] < regs_[rs2] ? 1 : 0;
        break;
      }
      case 0x4: // XOR
      {
#ifdef RV32I_DEBUG
        printf("xor %i,%i\n", rs1, rs2);
#endif
        regs_[rd] = regs_[rs1] ^ regs_[rs2];
        break;
      }
      case 0x5: // SRL / SRA
      {
        uint32_t const funct7 = FUNCT7_from(instruction);
        switch (funct7) {
        case 0x0: // SRL
        {
#ifdef RV32I_DEBUG
          printf("srl %i,%i\n", rs1, rs2);
#endif
          regs_[rd] = regs_[rs1] >> (regs_[rs2] & 0x1f);
          break;
        }
        case 0x20: // SRA
        {
#ifdef RV32I_DEBUG
          printf("sra %i,%i\n", rs1, rs2);
#endif
          regs_[rd] = int32_t(regs_[rs1]) >> (regs_[rs2] & 0x1f);
          break;
        }
        default:
          return 0x15;
        }
        break;
      }
      case 0x6: // OR
      {
#ifdef RV32I_DEBUG
        printf("or %i,%i\n", rs1, rs2);
#endif
        regs_[rd] = regs_[rs1] | regs_[rs2];
        break;
      }
      case 0x7: // AND
      {
#ifdef RV32I_DEBUG
        printf("and %i,%i\n", rs1, rs2);
#endif
        regs_[rd] = regs_[rs1] & regs_[rs2];
        break;
      }
      default:
        return 0x16;
      }
      break;
    }
    //-----------------------------------------------------------------------
    case 0x23: //                                                       store
    {
      using enum bus_op_width;
      uint32_t const rs1 = RS1_from(instruction);
      uint32_t const rs2 = RS2_from(instruction);
      int32_t const S_imm12 = S_imm12_from(instruction);
      uint32_t const address = regs_[rs1] + S_imm12;
      uint32_t const funct3 = FUNCT3_from(instruction);
      switch (funct3) {
      case 0x0: // SB
      {
#ifdef RV32I_DEBUG
        printf("sb %i,%i,0x%x\n", rs1, rs2, S_imm12);
#endif
        uint32_t value = regs_[rs2] & 0xFF;
        if (bus_status s = bus_(address, BYTE, true, value)) {
          return 0x1000 + s;
        }
        break;
      }
      case 0x1: // SH
      {
#ifdef RV32I_DEBUG
        printf("sh %i,%i,0x%x\n", rs1, rs2, S_imm12);
#endif
        uint32_t value = regs_[rs2] & 0xFFFF;
        if (bus_status s = bus_(address, HALF_WORD, true, value)) {
          return 0x1000 + s;
        }
        break;
      }
      case 0x2: // SW
      {
#ifdef RV32I_DEBUG
        printf("sw %i,%i,0x%x\n", rs1, rs2, S_imm12);
#endif
        if (bus_status s = bus_(address, WORD, true, regs_[rs2])) {
          return 0x1000 + s;
        }
        break;
      }
      default:
        return 0x11;
      }
      break;
    }
    //-----------------------------------------------------------------------
    case 0x3: //                                                         load
    {
      using enum bus_op_width;
      uint32_t const rs1 = RS1_from(instruction);
      uint32_t const rd = RD_from(instruction);
      int32_t const I_imm12 = I_imm12_from(instruction);
      uint32_t const address = regs_[rs1] + I_imm12;
      uint32_t const funct3 = FUNCT3_from(instruction);
      switch (funct3) {
      case 0x0: // LB
      {
#ifdef RV32I_DEBUG
        printf("lb %i,%i,0x%x\n", rs1, rd, I_imm12);
#endif
        uint32_t loaded = 0;
        if (bus_status s = bus_(address, BYTE, false, loaded)) {
          return 0x1000 + s;
        }
        regs_[rd] = loaded & 0x80 ? 0xFFFFFF00 | loaded : loaded;
        break;
      }
      case 0x1: // LH
      {
#ifdef RV32I_DEBUG
        printf("lh %i,%i,0x%x\n", rs1, rd, I_imm12);
#endif
        uint32_t loaded = 0;
        if (bus_status s = bus_(address, HALF_WORD, false, loaded)) {
          return 0x1000 + s;
        }
        regs_[rd] = loaded & 0x8000 ? 0xFFFF0000 | loaded : loaded;
        break;
      }
      case 0x2: // LW
      {
#ifdef RV32I_DEBUG
        printf("lw %i,%i,0x%x\n", rs1, rd, I_imm12);
#endif
        uint32_t loaded = 0;
        if (bus_status s = bus_(address, WORD, false, loaded)) {
          return 0x1000 + s;
        }
        regs_[rd] = loaded;
        break;
      }
      case 0x4: // LBU
      {
#ifdef RV32I_DEBUG
        printf("lbu %i,%i,0x%x\n", rs1, rd, I_imm12);
#endif
        uint32_t loaded = 0;
        if (bus_status s = bus_(address, BYTE, false, loaded)) {
          return 0x1000 + s;
        }
        regs_[rd] = loaded;
        break;
      }
      case 0x5: // LHU
      {
#ifdef RV32I_DEBUG
        printf("lhu %i,%i,0x%x\n", rs1, rd, I_imm12);
#endif
        uint32_t loaded = 0;
        if (bus_status s = bus_(address, HALF_WORD, false, loaded)) {
          return 0x1000 + s;
        }
        regs_[rd] = loaded;
        break;
      }
      default:
        return 0x10;
      }
      break;
    }
    //-----------------------------------------------------------------------
    case 0x17: //                                                       AUIPC
    {
      uint32_t const rd = RD_from(instruction);
      uint32_t const U_imm20 = U_imm20_from(instruction);
#ifdef RV32I_DEBUG
      printf("auipc 0x%x,0x%x\n", rd, U_imm20 >> 12);
#endif
      regs_[rd] = pc_ + U_imm20;
      break;
    }
    //-----------------------------------------------------------------------
    case 0x6F: //                                                         JAL
    {
      uint32_t const rd = RD_from(instruction);
      int32_t const J_imm20 = J_imm20_from(instruction);
#ifdef RV32I_DEBUG
      printf("jal 0x%x,0x%x\n", rd, J_imm20);
#endif
      regs_[rd] = pc_ + 4;
      pc_ += J_imm20 - 4;
      // note: pc_ is incremented by 4 after the instruction
      break;
    }
    //-----------------------------------------------------------------------
    case 0x67: //                                                        JALR
    {
      uint32_t const rs1 = RS1_from(instruction);
      uint32_t const rd = RD_from(instruction);
      int32_t const I_imm12 = I_imm12_from(instruction);
#ifdef RV32I_DEBUG
      printf("jalr 0x%x,0x%x,0x%x\n", rd, rs1, I_imm12);
#endif
      regs_[rd] = pc_ + 4;
      pc_ = regs_[rs1] + I_imm12 - 4;
      // note: pc_ is incremented by 4 after the instruction
      break;
    }
    //-----------------------------------------------------------------------
    case 0x63: //                                                    branches
    {
      uint32_t const rs1 = RS1_from(instruction);
      uint32_t const rs2 = RS2_from(instruction);
      int32_t const B_imm12 = B_imm12_from(instruction);
      uint32_t const funct3 = FUNCT3_from(instruction);
      switch (funct3) {
      case 0x0: // BEQ
      {
#ifdef RV32I_DEBUG
        printf("beq %i,%i\n", rs1, rs2);
#endif
        if (regs_[rs1] == regs_[rs2]) {
          pc_ += B_imm12 - 4;
          // note: pc_ is incremented by 4 after the instruction
        }
        break;
      }
      case 0x1: // BNE
      {
#ifdef RV32I_DEBUG
        printf("bne %i,%i\n", rs1, rs2);
#endif
        if (regs_[rs1] != regs_[rs2]) {
          pc_ += B_imm12 - 4;
          // note: pc_ is incremented by 4 after the instruction
        }
        break;
      }
      case 0x4: // BLT
      {
#ifdef RV32I_DEBUG
        printf("blt %i,%i\n", rs1, rs2);
#endif
        if (int32_t(regs_[rs1]) < int32_t(regs_[rs2])) {
          pc_ += B_imm12 - 4;
          // note: pc_ is incremented by 4 after the instruction
        }
        break;
      }
      case 0x5: // BGE
      {
#ifdef RV32I_DEBUG
        printf("bge %i,%i\n", rs1, rs2);
#endif
        if (int32_t(regs_[rs1]) >= int32_t(regs_[rs2])) {
          pc_ += B_imm12 - 4;
          // note: pc is incremented by 4 after the instruction
        }
        break;
      }
      case 0x6: // BLTU
      {
#ifdef RV32I_DEBUG
        printf("bltu %i,%i,%i\n", rs1, rs2, B_imm12);
#endif
        if (regs_[rs1] < regs_[rs2]) {
          pc_ += B_imm12 - 4;
        }
        break;
      }
      case 0x7: // BGEU
      {
#ifdef RV32I_DEBUG
        printf("bgeu %i,%i\n", rs1, rs2);
#endif
        if (regs_[rs1] >= regs_[rs2]) {
          pc_ += B_imm12 - 4;
        }
        break;
      }
      default:
        return 0x17;
      }
      break;
    }
    //-----------------------------------------------------------------------
    default:
      return 0x18;
    }

    pc_ += 4;
    return 0;
  }

  static auto constexpr OPCODE_from(uint32_t const instruction) -> uint32_t {
    return instruction & 0x7F;
  }

  static auto constexpr FUNCT3_from(uint32_t const instruction) -> uint32_t {
    return (instruction >> 12) & 0x7;
  }

  static auto constexpr FUNCT7_from(uint32_t const instruction) -> uint32_t {
    return (instruction >> 25) & 0x7F;
  }

  static auto constexpr RS1_from(uint32_t const instruction) -> uint32_t {
    return (instruction >> 15) & 0x1F;
  }

  static auto constexpr RS2_from(uint32_t const instruction) -> uint32_t {
    return (instruction >> 20) & 0x1F;
  }

  static auto constexpr RD_from(uint32_t const instruction) -> uint32_t {
    return (instruction >> 7) & 0x1F;
  }

  static auto constexpr U_imm20_from(uint32_t const instruction) -> uint32_t {
    return instruction & 0xFFFFF000;
  }

  static auto constexpr I_imm12_from(uint32_t const instruction) -> int32_t {
    return (instruction & 0x80000000) ? 0xFFFFF000 | instruction >> 20
                                      : instruction >> 20;
  }

  static auto constexpr S_imm12_from(uint32_t const instruction) -> int32_t {
    return (instruction & 0x80000000)
               ? 0xFFFFF000 | ((instruction >> 7) & 0x1F) |
                     ((instruction >> 20) & 0xFE0)
               : ((instruction >> 7) & 0x1F) | ((instruction >> 20) & 0xFE0);
  }

  static auto constexpr B_imm12_from(uint32_t const instruction) -> int32_t {
    return (instruction & 0x80000000)
               ? 0xFFFFE000 | ((instruction << 4) & 0x800) |
                     ((instruction >> 7) & 0x1E) |
                     ((instruction >> 20) & 0x7E0) |
                     ((instruction >> 19) & 0x1000)
               : ((instruction << 4) & 0x800) | ((instruction >> 7) & 0x1E) |
                     ((instruction >> 20) & 0x7E0) |
                     ((instruction >> 19) & 0x1000);
  }

  static auto constexpr J_imm20_from(uint32_t const instruction) -> int32_t {
    return (instruction & 0x80000000)
               ? 0xFFE00000 | ((instruction >> 20) & 0x7FE) |
                     ((instruction >> 9) & 0x800) | (instruction & 0xFF000) |
                     ((instruction >> 11) & 0x100000)
               : ((instruction >> 20) & 0x7FE) | ((instruction >> 9) & 0x800) |
                     (instruction & 0xFF000) | ((instruction >> 11) & 0x100000);
  }
};

} // namespace rv32i
