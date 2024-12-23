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
    std::printf("pc 0x%08x instr 0x%08x ", pc_, instruction);
#endif
    uint32_t const opcode = OPCODE_from(instruction);
    switch (opcode) {
    //-----------------------------------------------------------------------
    case OPCODE_LUI: //                                                   LUI
    {
      uint32_t const rd = RD_from(instruction);
      uint32_t const U_imm20 = U_imm20_from(instruction);
#ifdef RV32I_DEBUG
      std::printf("lui x%d, 0x%x\n", rd, U_imm20 >> 12);
#endif
      regs_[rd] = U_imm20;
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
        std::printf("addi x%d, x%d, %d\n", rd, rs1, I_imm12);
#endif
        regs_[rd] = regs_[rs1] + I_imm12;
        break;
      }
      case FUNCT3_SLTI: {
#ifdef RV32I_DEBUG
        std::printf("slti x%d, x%d, %d\n", rd, rs1, I_imm12);
#endif
        regs_[rd] = int32_t(regs_[rs1]) < I_imm12 ? 1 : 0;
        break;
      }
      case FUNCT3_SLTIU: {
#ifdef RV32I_DEBUG
        std::printf("sltiu x%d, x%d, %d\n", rd, rs1, I_imm12);
#endif
        regs_[rd] = regs_[rs1] < uint32_t(I_imm12) ? 1 : 0;
        break;
      }
      case FUNCT3_XORI: {
#ifdef RV32I_DEBUG
        std::printf("xori x%d, x%d, %d\n", rd, rs1, I_imm12);
#endif
        regs_[rd] = regs_[rs1] ^ I_imm12;
        break;
      }
      case FUNCT3_ORI: {
#ifdef RV32I_DEBUG
        std::printf("ori x%d, x%d, %d\n", rd, rs1, I_imm12);
#endif
        regs_[rd] = regs_[rs1] | I_imm12;
        break;
      }
      case FUNCT3_ANDI: {
#ifdef RV32I_DEBUG
        std::printf("andi x%d, x%d, %d\n", rd, rs1, I_imm12);
#endif
        regs_[rd] = regs_[rs1] & I_imm12;
        break;
      }
      case FUNCT3_SLLI: {
        uint32_t const rs2 = RS2_from(instruction);
#ifdef RV32I_DEBUG
        std::printf("slli x%d, x%d, %d\n", rd, rs1, rs2);
#endif
        regs_[rd] = regs_[rs1] << rs2;
        break;
      }
      case FUNCT3_SRLI_SRAI: {
        uint32_t const rs2 = RS2_from(instruction);
        uint32_t const funct7 = FUNCT7_from(instruction);
        switch (funct7) {
        case FUNCT7_SRLI: {
#ifdef RV32I_DEBUG
          std::printf("srli x%d, x%d, %d\n", rd, rs1, rs2);
#endif
          regs_[rd] = regs_[rs1] >> rs2;
          break;
        }
        case FUNCT7_SRAI: {
#ifdef RV32I_DEBUG
          std::printf("srai x%d, x%d, %d\n", rd, rs1, rs2);
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
          std::printf("add x%d, x%d, x%d\n", rd, rs1, rs2);
#endif
          regs_[rd] = regs_[rs1] + regs_[rs2];
          break;
        }
        case FUNCT7_SUB: {
#ifdef RV32I_DEBUG
          std::printf("sub x%d, x%d, x%d\n", rd, rs1, rs2);
#endif
          regs_[rd] = regs_[rs1] - regs_[rs2];
          break;
        }
        default:
          return 0x14;
        }
        break;
      }
      case FUNCT3_SLL: {
#ifdef RV32I_DEBUG
        std::printf("sll x%d, x%d, x%d\n", rd, rs1, rs2);
#endif
        regs_[rd] = regs_[rs1] << (regs_[rs2] & 0x1f);
        break;
      }
      case FUNCT3_SLT: {
#ifdef RV32I_DEBUG
        std::printf("slt x%d, x%d, x%d\n", rd, rs1, rs2);
#endif
        regs_[rd] = int32_t(regs_[rs1]) < int32_t(regs_[rs2]) ? 1 : 0;
        break;
      }
      case FUNCT3_SLTU: {
#ifdef RV32I_DEBUG
        std::printf("sltu x%d, x%d, x%d\n", rd, rs1, rs2);
#endif
        regs_[rd] = regs_[rs1] < regs_[rs2] ? 1 : 0;
        break;
      }
      case FUNCT3_XOR: {
#ifdef RV32I_DEBUG
        std::printf("xor x%d, x%d, x%d\n", rd, rs1, rs2);
#endif
        regs_[rd] = regs_[rs1] ^ regs_[rs2];
        break;
      }
      case FUNCT3_SRL_SRA: {
        uint32_t const funct7 = FUNCT7_from(instruction);
        switch (funct7) {
        case FUNCT7_SRL: {
#ifdef RV32I_DEBUG
          std::printf("srl x%d, x%d, x%d\n", rd, rs1, rs2);
#endif
          regs_[rd] = regs_[rs1] >> (regs_[rs2] & 0x1f);
          break;
        }
        case FUNCT7_SRA: {
#ifdef RV32I_DEBUG
          std::printf("sra x%d, x%d, x%d\n", rd, rs1, rs2);
#endif
          regs_[rd] = int32_t(regs_[rs1]) >> (regs_[rs2] & 0x1f);
          break;
        }
        default:
          return 0x15;
        }
        break;
      }
      case FUNCT3_OR: {
#ifdef RV32I_DEBUG
        std::printf("or x%d, x%d, x%d\n", rd, rs1, rs2);
#endif
        regs_[rd] = regs_[rs1] | regs_[rs2];
        break;
      }
      case FUNCT3_AND: {
#ifdef RV32I_DEBUG
        std::printf("and x%d, x%d, x%d\n", rd, rs1, rs2);
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
    case OPCODE_STORE: //                                               store
    {
      using enum bus_op_width;
      uint32_t const rs1 = RS1_from(instruction);
      uint32_t const rs2 = RS2_from(instruction);
      int32_t const S_imm12 = S_imm12_from(instruction);
      uint32_t const address = regs_[rs1] + S_imm12;
      uint32_t const funct3 = FUNCT3_from(instruction);
      switch (funct3) {
      case FUNCT3_SB: {
#ifdef RV32I_DEBUG
        std::printf("sb x%d, %d(x%d)\n", rs2, S_imm12, rs1);
#endif
        uint32_t value = regs_[rs2] & 0xFF;
        if (bus_status s = bus_(address, BYTE, true, value)) {
          return 0x1000 + s;
        }
        break;
      }
      case FUNCT3_SH: {
#ifdef RV32I_DEBUG
        std::printf("sh x%d, %d(x%d)\n", rs2, S_imm12, rs1);
#endif
        uint32_t value = regs_[rs2] & 0xFFFF;
        if (bus_status s = bus_(address, HALF_WORD, true, value)) {
          return 0x1000 + s;
        }
        break;
      }
      case FUNCT3_SW: {
#ifdef RV32I_DEBUG
        std::printf("sw x%d, %d(x%d)\n", rs2, S_imm12, rs1);
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
    case OPCODE_LOAD: //                                                 load
    {
      using enum bus_op_width;
      uint32_t const rs1 = RS1_from(instruction);
      uint32_t const rd = RD_from(instruction);
      int32_t const I_imm12 = I_imm12_from(instruction);
      uint32_t const address = regs_[rs1] + I_imm12;
      uint32_t const funct3 = FUNCT3_from(instruction);
      switch (funct3) {
      case FUNCT3_LB: {
#ifdef RV32I_DEBUG
        std::printf("lb x%d, %d(x%d)\n", rd, I_imm12, rs1);
#endif
        uint32_t loaded = 0;
        if (bus_status s = bus_(address, BYTE, false, loaded)) {
          return 0x1000 + s;
        }
        regs_[rd] = loaded & 0x80 ? 0xFFFFFF00 | loaded : loaded;
        break;
      }
      case FUNCT3_LH: {
#ifdef RV32I_DEBUG
        std::printf("lh x%d, %d(x%d)\n", rd, I_imm12, rs1);
#endif
        uint32_t loaded = 0;
        if (bus_status s = bus_(address, HALF_WORD, false, loaded)) {
          return 0x1000 + s;
        }
        regs_[rd] = loaded & 0x8000 ? 0xFFFF0000 | loaded : loaded;
        break;
      }
      case FUNCT3_LW: {
#ifdef RV32I_DEBUG
        std::printf("lw x%d, %d(x%d)\n", rd, I_imm12, rs1);
#endif
        uint32_t loaded = 0;
        if (bus_status s = bus_(address, WORD, false, loaded)) {
          return 0x1000 + s;
        }
        regs_[rd] = loaded;
        break;
      }
      case FUNCT3_LBU: {
#ifdef RV32I_DEBUG
        std::printf("lbu x%d, %d(x%d)\n", rd, I_imm12, rs1);
#endif
        uint32_t loaded = 0;
        if (bus_status s = bus_(address, BYTE, false, loaded)) {
          return 0x1000 + s;
        }
        regs_[rd] = loaded;
        break;
      }
      case FUNCT3_LHU: {
#ifdef RV32I_DEBUG
        std::printf("lhu x%d, %d(x%d)\n", rd, I_imm12, rs1);
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
    case OPCODE_AUIPC: //                                               AUIPC
    {
      uint32_t const rd = RD_from(instruction);
      uint32_t const U_imm20 = U_imm20_from(instruction);
#ifdef RV32I_DEBUG
      std::printf("auipc x%d, 0x%x\n", rd, U_imm20 >> 12);
#endif
      regs_[rd] = pc_ + U_imm20;
      break;
    }
    //-----------------------------------------------------------------------
    case OPCODE_JAL: //                                                   JAL
    {
      uint32_t const rd = RD_from(instruction);
      int32_t const J_imm20 = J_imm20_from(instruction);
#ifdef RV32I_DEBUG
      std::printf("jal x%d, 0x%x\n", rd, pc_ + J_imm20);
#endif
      regs_[rd] = pc_ + 4;
      pc_ += J_imm20 - 4;
      // note: pc_ is incremented by 4 after the instruction
      break;
    }
    //-----------------------------------------------------------------------
    case OPCODE_JALR: //                                                 JALR
    {
      uint32_t const rs1 = RS1_from(instruction);
      uint32_t const rd = RD_from(instruction);
      int32_t const I_imm12 = I_imm12_from(instruction);
#ifdef RV32I_DEBUG
      std::printf("jalr x%d, %d(x%d)\n", rd, I_imm12, rs1);
#endif
      regs_[rd] = pc_ + 4;
      pc_ = regs_[rs1] + I_imm12 - 4;
      // note: pc_ is incremented by 4 after the instruction
      break;
    }
    //-----------------------------------------------------------------------
    case OPCODE_BRANCH: //                                           branches
    {
      uint32_t const rs1 = RS1_from(instruction);
      uint32_t const rs2 = RS2_from(instruction);
      int32_t const B_imm12 = B_imm12_from(instruction);
      uint32_t const funct3 = FUNCT3_from(instruction);
      switch (funct3) {
      case FUNCT3_BEQ: {
#ifdef RV32I_DEBUG
        std::printf("beq x%d, x%d, 0x%x\n", rs1, rs2, pc_ + B_imm12);
#endif
        if (regs_[rs1] == regs_[rs2]) {
          pc_ += B_imm12 - 4;
          // note: pc_ is incremented by 4 after the instruction
        }
        break;
      }
      case FUNCT3_BNE: {
#ifdef RV32I_DEBUG
        std::printf("bne x%d, x%d, 0x%x\n", rs1, rs2, pc_ + B_imm12);
#endif
        if (regs_[rs1] != regs_[rs2]) {
          pc_ += B_imm12 - 4;
          // note: pc_ is incremented by 4 after the instruction
        }
        break;
      }
      case FUNCT3_BLT: {
#ifdef RV32I_DEBUG
        std::printf("blt x%d, x%d, 0x%x\n", rs1, rs2, pc_ + B_imm12);
#endif
        if (int32_t(regs_[rs1]) < int32_t(regs_[rs2])) {
          pc_ += B_imm12 - 4;
          // note: pc_ is incremented by 4 after the instruction
        }
        break;
      }
      case FUNCT3_BGE: {
#ifdef RV32I_DEBUG
        std::printf("bge x%d, x%d, 0x%x\n", rs1, rs2, pc_ + B_imm12);
#endif
        if (int32_t(regs_[rs1]) >= int32_t(regs_[rs2])) {
          pc_ += B_imm12 - 4;
          // note: pc is incremented by 4 after the instruction
        }
        break;
      }
      case FUNCT3_BLTU: {
#ifdef RV32I_DEBUG
        std::printf("bltu x%d, x%d, 0x%x\n", rs1, rs2, pc_ + B_imm12);
#endif
        if (regs_[rs1] < regs_[rs2]) {
          pc_ += B_imm12 - 4;
        }
        break;
      }
      case FUNCT3_BGEU: {
#ifdef RV32I_DEBUG
        std::printf("bgeu x%d, x%d, 0x%x\n", rs1, rs2, pc_ + B_imm12);
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

  static uint32_t constexpr OPCODE_LUI = 0x37;
  static uint32_t constexpr OPCODE_LOGICAL_IMM = 0x13;
  static uint32_t constexpr FUNCT3_ADDI = 0;
  static uint32_t constexpr FUNCT3_SLTI = 2;
  static uint32_t constexpr FUNCT3_SLTIU = 3;
  static uint32_t constexpr FUNCT3_XORI = 4;
  static uint32_t constexpr FUNCT3_ORI = 6;
  static uint32_t constexpr FUNCT3_ANDI = 7;
  static uint32_t constexpr FUNCT3_SLLI = 1;
  static uint32_t constexpr FUNCT3_SRLI_SRAI = 5;
  static uint32_t constexpr FUNCT7_SRLI = 0;
  static uint32_t constexpr FUNCT7_SRAI = 0x20;
  static uint32_t constexpr OPCODE_LOGICAL = 0x33;
  static uint32_t constexpr FUNCT3_ADD_SUB = 0;
  static uint32_t constexpr FUNCT7_ADD = 0;
  static uint32_t constexpr FUNCT7_SUB = 0x20;
  static uint32_t constexpr FUNCT3_SLL = 1;
  static uint32_t constexpr FUNCT3_SLT = 2;
  static uint32_t constexpr FUNCT3_SLTU = 3;
  static uint32_t constexpr FUNCT3_XOR = 4;
  static uint32_t constexpr FUNCT3_SRL_SRA = 5;
  static uint32_t constexpr FUNCT7_SRL = 0;
  static uint32_t constexpr FUNCT7_SRA = 0x20;
  static uint32_t constexpr FUNCT3_OR = 6;
  static uint32_t constexpr FUNCT3_AND = 7;
  static uint32_t constexpr OPCODE_STORE = 0x23;
  static uint32_t constexpr FUNCT3_SB = 0;
  static uint32_t constexpr FUNCT3_SH = 1;
  static uint32_t constexpr FUNCT3_SW = 2;
  static uint32_t constexpr OPCODE_LOAD = 3;
  static uint32_t constexpr FUNCT3_LB = 0;
  static uint32_t constexpr FUNCT3_LH = 1;
  static uint32_t constexpr FUNCT3_LW = 2;
  static uint32_t constexpr FUNCT3_LBU = 4;
  static uint32_t constexpr FUNCT3_LHU = 5;
  static uint32_t constexpr OPCODE_AUIPC = 0x17;
  static uint32_t constexpr OPCODE_JAL = 0x6F;
  static uint32_t constexpr OPCODE_JALR = 0x67;
  static uint32_t constexpr OPCODE_BRANCH = 0x63;
  static uint32_t constexpr FUNCT3_BEQ = 0;
  static uint32_t constexpr FUNCT3_BNE = 1;
  static uint32_t constexpr FUNCT3_BLT = 4;
  static uint32_t constexpr FUNCT3_BGE = 5;
  static uint32_t constexpr FUNCT3_BLTU = 6;
  static uint32_t constexpr FUNCT3_BGEU = 7;
};

} // namespace rv32i
