// from https://github.com/alexriegler12/riscv
//  converted to C++23 + some refinements

#pragma once

namespace rv32i {

enum class bus_op_width { BYTE = 1, HALF_WORD = 2, WORD = 4 };

using bus = unsigned (*)(unsigned address, bus_op_width width, bool is_store,
                         unsigned &data);

class cpu final {

  static auto constexpr OPCODE_from(unsigned const instruction) -> unsigned {
    return instruction & 0x7F;
  }

  static auto constexpr FUNCT3_from(unsigned const instruction) -> unsigned {
    return (instruction >> 12) & 0x7;
  }

  static auto constexpr FUNCT7_from(unsigned const instruction) -> unsigned {
    return (instruction >> 25) & 0x7F;
  }

  static auto constexpr RS1_from(unsigned const instruction) -> unsigned {
    return (instruction >> 15) & 0x1F;
  }

  static auto constexpr RS2_from(unsigned const instruction) -> unsigned {
    return (instruction >> 20) & 0x1F;
  }

  static auto constexpr RD_from(unsigned const instruction) -> unsigned {
    return (instruction >> 7) & 0x1F;
  }

  static auto constexpr U_imm20_from(unsigned const instruction) -> unsigned {
    return instruction & 0xFFFFF000;
  }

  static auto constexpr I_imm12_from(unsigned const instruction) -> int {
    return (instruction & 0x80000000) ? 0xFFFFF000 | instruction >> 20
                                      : instruction >> 20;
  }

  static auto constexpr S_imm12_from(unsigned const instruction) -> int {
    return (instruction & 0x80000000)
               ? 0xFFFFF000 | ((instruction >> 7) & 0x1F) |
                     ((instruction >> 20) & 0xFE0)
               : ((instruction >> 7) & 0x1F) | ((instruction >> 20) & 0xFE0);
  }

  static auto constexpr B_imm12_from(unsigned const instruction) -> int {
    return (instruction & 0x80000000)
               ? 0xFFFFE000 | ((instruction << 4) & 0x800) |
                     ((instruction >> 7) & 0x1E) |
                     ((instruction >> 20) & 0x7E0) |
                     ((instruction >> 19) & 0x1000)
               : ((instruction << 4) & 0x800) | ((instruction >> 7) & 0x1E) |
                     ((instruction >> 20) & 0x7E0) |
                     ((instruction >> 19) & 0x1000);
  }

  static auto constexpr J_imm20_from(unsigned const instruction) -> int {
    return (instruction & 0x80000000)
               ? 0xFFE00000 | ((instruction >> 20) & 0x7FE) |
                     ((instruction >> 9) & 0x800) | (instruction & 0xFF000) |
                     ((instruction >> 11) & 0x100000)
               : ((instruction >> 20) & 0x7FE) | ((instruction >> 9) & 0x800) |
                     (instruction & 0xFF000) | ((instruction >> 11) & 0x100000);
  }

  bus bus_{};
  unsigned pc_{};
  unsigned regs_[32]{};

public:
  cpu(bus const bus_callback, unsigned const initial_pc = 0)
      : bus_{bus_callback}, pc_{initial_pc} {}

  auto tick() -> unsigned {
    regs_[0] = 0;
    unsigned instruction = 0;
    if (unsigned error = bus_(pc_, bus_op_width::WORD, false, instruction)) {
      return error;
    }
#ifdef RV32I_DEBUG
    printf("pc 0x%08x instr 0x%08x ", pc, instruction);
#endif
    unsigned const opcode = OPCODE_from(instruction);
    switch (opcode) {
    case 0x3: // load
    {
      using enum bus_op_width;
      unsigned const rs1 = RS1_from(instruction);
      unsigned const rd = RD_from(instruction);
      int const I_imm12 = I_imm12_from(instruction);
      unsigned const address = regs_[rs1] + I_imm12;
      unsigned const funct3 = FUNCT3_from(instruction);
      switch (funct3) {
      case 0x0: // LB
      {
#ifdef RV32I_DEBUG
        printf("lb %i,%i,0x%x\n", rs1, rd, I_imm12);
#endif
        unsigned loaded = 0;
        bus_(address, BYTE, false, loaded);
        regs_[rd] = loaded & 0x80 ? 0xFFFFFF00 | loaded : loaded;
        break;
      }
      case 0x1: // LH
      {
#ifdef RV32I_DEBUG
        printf("lh %i,%i,0x%x\n", rs1, rd, I_imm12);
#endif
        unsigned loaded = 0;
        bus_(address, HALF_WORD, false, loaded);
        regs_[rd] = loaded & 0x8000 ? 0xFFFF0000 | loaded : loaded;
        break;
      }
      case 0x2: // LW
      {
#ifdef RV32I_DEBUG
        printf("lw %i,%i,0x%x\n", rs1, rd, I_imm12);
#endif
        unsigned loaded = 0;
        bus_(address, WORD, false, loaded);
        regs_[rd] = loaded;
        break;
      }
      case 0x4: // LBU
      {
#ifdef RV32I_DEBUG
        printf("lbu %i,%i,0x%x\n", rs1, rd, I_imm12);
#endif
        unsigned loaded = 0;
        bus_(address, BYTE, false, loaded);
        regs_[rd] = loaded;
        break;
      }
      case 0x5: // LHU
      {
#ifdef RV32I_DEBUG
        printf("lhu %i,%i,0x%x\n", rs1, rd, I_imm12);
#endif
        unsigned loaded = 0;
        bus_(address, HALF_WORD, false, loaded);
        regs_[rd] = loaded;
        break;
      }
      default:
        return 0x10;
      }
      break;
    }
    case 0x23: // store
    {
      using enum bus_op_width;
      unsigned const rs1 = RS1_from(instruction);
      unsigned const rs2 = RS2_from(instruction);
      int const S_imm12 = S_imm12_from(instruction);
      unsigned const address = regs_[rs1] + S_imm12;
      unsigned const funct3 = FUNCT3_from(instruction);
      switch (funct3) {
      case 0x0: // SB
      {
#ifdef RV32I_DEBUG
        printf("sb %i,%i,0x%x\n", rs1, rs2, S_imm12);
#endif
        unsigned value = regs_[rs2] & 0xFF;
        bus_(address, BYTE, true, value);
        break;
      }
      case 0x1: // SH
      {
#ifdef RV32I_DEBUG
        printf("sh %i,%i,0x%x\n", rs1, rs2, S_imm12);
#endif
        unsigned value = regs_[rs2] & 0xFFFF;
        bus_(address, HALF_WORD, true, value);
        break;
      }
      case 0x2: // SW
      {
#ifdef RV32I_DEBUG
        printf("sw %i,%i,0x%x\n", rs1, rs2, S_imm12);
#endif
        bus_(address, WORD, true, regs_[rs2]);
        break;
      }
      default:
        return 0x11;
      }
      break;
    }
    case 0x13: // immediate arithmetic
    {
      unsigned const rs1 = RS1_from(instruction);
      unsigned const rd = RD_from(instruction);
      int const I_imm12 = I_imm12_from(instruction);
      unsigned const funct3 = FUNCT3_from(instruction);
      switch (funct3) {
      case 0x0: // ADDI
      {
#ifdef RV32I_DEBUG
        printf("addi %i,%i\n", rs1, I_imm12);
#endif
        regs_[rd] = signed(regs_[rs1]) + I_imm12;
        break;
      }
      case 0x2: // SLTI
      {
#ifdef RV32I_DEBUG
        printf("slti %i,%i\n", rs1, I_imm12);
#endif
        regs_[rd] = signed(regs_[rs1]) < I_imm12 ? 1 : 0;
        break;
      }
      case 0x3: // SLTIU
      {
#ifdef RV32I_DEBUG
        printf("sltiu %i,%i\n", rs1, I_imm12);
#endif
        regs_[rd] = regs_[rs1] < unsigned(I_imm12) ? 1 : 0;
        break;
      }
      case 0x4: // XORI
      {
#ifdef RV32I_DEBUG
        printf("xori %i,%i\n", rs1, I_imm12);
#endif
        regs_[rd] = regs_[rs1] ^ unsigned(I_imm12);
        break;
      }
      case 0x6: // ORI
      {
#ifdef RV32I_DEBUG
        printf("ori %i,%i\n", rs1, I_imm12);
#endif
        regs_[rd] = regs_[rs1] | unsigned(I_imm12);
        break;
      }
      case 0x7: // ANDI
      {
#ifdef RV32I_DEBUG
        printf("andi %i,%i\n", rs1, I_imm12);
#endif
        regs_[rd] = regs_[rs1] & unsigned(I_imm12);
        break;
      }
      case 0x1: // SLLI
      {
        unsigned const RS2 = RS2_from(instruction);

#ifdef RV32I_DEBUG
        printf("slli %i,%i\n", rs1, RS2);
#endif
        regs_[rd] = regs_[rs1] << RS2;
        break;
      }
      case 0x5: // SRLI/SRAI
      {
        unsigned const rs2 = RS2_from(instruction);
        unsigned const funct7 = FUNCT7_from(instruction);
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
          regs_[rd] = signed(regs_[rs1]) >> rs2;
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

    case 0x33: // register arithmetic
    {
      unsigned const rs1 = RS1_from(instruction);
      unsigned const rs2 = RS2_from(instruction);
      unsigned const rd = RD_from(instruction);
      unsigned const funct3 = FUNCT3_from(instruction);
      switch (funct3) {
      case 0x0: // ADD / SUB
      {
        unsigned const FUNCT7 = FUNCT7_from(instruction);
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
        regs_[rd] = signed(regs_[rs1]) < signed(regs_[rs2]) ? 1 : 0;
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
        unsigned const funct7 = FUNCT7_from(instruction);
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
          regs_[rd] = signed(regs_[rs1]) >> (regs_[rs2] & 0x1f);
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

    case 0x37: // LUI
    {
      unsigned const rd = RD_from(instruction);
      unsigned const U_imm20 = U_imm20_from(instruction);
#ifdef RV32I_DEBUG
      printf("lui 0x%x,0x%x\n", rd, U_imm20 >> 12);
#endif
      regs_[rd] = U_imm20;
      break;
    }

    case 0x17: // AUIPC
    {
      unsigned const rd = RD_from(instruction);
      unsigned const U_imm20 = U_imm20_from(instruction);
#ifdef RV32I_DEBUG
      printf("auipc 0x%x,0x%x\n", rd, U_imm20 >> 12);
#endif
      regs_[rd] = pc_ + U_imm20;
      break;
    }

    case 0x6F: // JAL
    {
      unsigned const rd = RD_from(instruction);
      int const J_imm20 = J_imm20_from(instruction);
#ifdef RV32I_DEBUG
      printf("jal 0x%x,0x%x\n", rd, J_imm20);
#endif
      regs_[rd] = pc_ + 4;
      pc_ += J_imm20 - 4;
      // note: pc_ is incremented by 4 after the instruction
      break;
    }

    case 0x67: // JALR
    {
      unsigned const rs1 = RS1_from(instruction);
      unsigned const rd = RD_from(instruction);
      int const I_imm12 = I_imm12_from(instruction);
#ifdef RV32I_DEBUG
      printf("jalr 0x%x,0x%x,0x%x\n", rd, rs1, I_imm12);
#endif
      regs_[rd] = pc_ + 4;
      pc_ = regs_[rs1] + I_imm12 - 4;
      // note: pc_ is incremented by 4 after the instruction
      break;
    }

    case 0x63: // branching
    {
      unsigned const rs1 = RS1_from(instruction);
      unsigned const rs2 = RS2_from(instruction);
      int const B_imm12 = B_imm12_from(instruction);
      unsigned const funct3 = FUNCT3_from(instruction);
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
        if (signed(regs_[rs1]) < signed(regs_[rs2])) {
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
        if (signed(regs_[rs1]) >= signed(regs_[rs2])) {
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
    default:
      return 0x18;
    }

    pc_ += 4;
    return 0;
  }
};

} // namespace rv32i
