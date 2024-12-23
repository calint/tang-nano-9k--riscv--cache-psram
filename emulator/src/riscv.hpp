// from https://github.com/alexriegler12/riscv
//  converted to C++23 + some refinements

#pragma once

#define I_IMM                                                                  \
  ((instruction & 0x80000000) ? 0xFFFFF000 | instruction >> 20                 \
                              : instruction >> 20)
#define S_IMM                                                                  \
  ((instruction & 0x80000000)                                                  \
       ? 0xFFFFF000 | ((instruction >> 7) & 0x1F) |                            \
             ((instruction >> 20) & 0xFE0)                                     \
       : ((instruction >> 7) & 0x1F) | ((instruction >> 20) & 0xFE0))
#define U_IMM (instruction & 0xFFFFF000)
#define B_IMM                                                                  \
  ((instruction & 0x80000000)                                                  \
       ? 0xFFFFE000 | ((instruction << 4) & 0x800) |                           \
             ((instruction >> 7) & 0x1E) | ((instruction >> 20) & 0x7E0) |     \
             ((instruction >> 19) & 0x1000)                                    \
       : ((instruction << 4) & 0x800) | ((instruction >> 7) & 0x1E) |          \
             ((instruction >> 20) & 0x7E0) | ((instruction >> 19) & 0x1000))
#define J_IMM                                                                  \
  ((instruction & 0x80000000)                                                  \
       ? 0xFFE00000 | ((instruction >> 20) & 0x7FE) |                          \
             ((instruction >> 9) & 0x800) | (instruction & 0xFF000) |          \
             ((instruction >> 11) & 0x100000)                                  \
       : ((instruction >> 20) & 0x7FE) | ((instruction >> 9) & 0x800) |        \
             (instruction & 0xFF000) | ((instruction >> 11) & 0x100000))

#define OPCODE (instruction & 0x7F)
#define RS1 ((instruction >> 15) & 0x1F)
#define RS2 ((instruction >> 20) & 0x1F)
#define RD ((instruction >> 7) & 0x1F)
#define FUNCT3 ((instruction >> 12) & 0x7)
#define FUNCT7 ((instruction >> 25) & 0x7F)

enum class bus_op_width { BYTE = 1, HALF_WORD = 2, WORD = 4 };

using rv32i_bus = unsigned (*)(unsigned address, bus_op_width width,
                               bool is_store, unsigned *data);

class rv32i {
  unsigned regs[32]{};
  unsigned pc{};
  rv32i_bus bus{};

public:
  rv32i(rv32i_bus bus_callback, unsigned initial_pc = 0)
      : pc{initial_pc}, bus{bus_callback} {}

  auto tick() -> unsigned {
    using enum bus_op_width;

    regs[0] = 0x0;
    unsigned instruction = 0;
    if (unsigned error = bus(pc, WORD, 0, &instruction)) {
      return error;
    }
#ifdef RISCV_DEBUG
    printf("pc 0x%08x instr 0x%08x ", pc, instruction);
#endif
    switch (OPCODE) {
    case 0x3: // load
    {
      unsigned addr = regs[RS1] + (int)I_IMM;
      switch (FUNCT3) {
      case 0x0: // LB
      {
#ifdef RISCV_DEBUG
        printf("lb %i,%i,0x%x\n", RS1, RD, (int)I_IMM);
#endif
        unsigned loaded = 0;
        bus(addr, BYTE, false, &loaded);
        regs[RD] = loaded & 0x80 ? 0xFFFFFF00 | loaded : loaded;
        break;
      }
      case 0x1: // LH
      {
#ifdef RISCV_DEBUG
        printf("lh %i,%i,0x%x\n", RS1, RD, (int)I_IMM);
#endif
        unsigned loaded = 0;
        bus(addr, HALF_WORD, false, &loaded);
        regs[RD] = loaded & 0x8000 ? 0xFFFF0000 | loaded : loaded;
        break;
      }
      case 0x2: // LW
      {
#ifdef RISCV_DEBUG
        printf("lw %i,%i,0x%x\n", RS1, RD, (int)I_IMM);
#endif
        unsigned loaded = 0;
        bus(addr, WORD, false, &loaded);
        regs[RD] = loaded;
        break;
      }
      case 0x4: // LBU
      {
#ifdef RISCV_DEBUG
        printf("lbu %i,%i,0x%x\n", RS1, RD, (int)I_IMM);
#endif
        unsigned loaded = 0;
        bus(addr, BYTE, false, &loaded);
        regs[RD] = loaded;
        break;
      }
      case 0x5: // LHU
      {
#ifdef RISCV_DEBUG
        printf("lhu %i,%i,0x%x\n", RS1, RD, (int)I_IMM);
#endif
        unsigned loaded = 0;
        bus(addr, HALF_WORD, false, &loaded);
        regs[RD] = loaded;
        break;
      }
      default:
        return 0x10;
      }
      break;
    }
    case 0x23: // store
    {
      unsigned addr = regs[RS1] + (int)S_IMM;
      switch (FUNCT3) {
      case 0x0: // SB
      {
#ifdef RISCV_DEBUG
        printf("sb %i,%i,0x%x\n", RS1, RS2, (int)S_IMM);
#endif
        unsigned val = regs[RS2] & 0xFF;
        bus(addr, BYTE, true, &val);
        break;
      }
      case 0x1: // SH
      {
#ifdef RISCV_DEBUG
        printf("sh %i,%i,0x%x\n", RS1, RS2, (int)S_IMM);
#endif
        unsigned val = regs[RS2] & 0xFFFF;
        bus(addr, HALF_WORD, true, &val);
        break;
      }
      case 0x2: // SW
      {
#ifdef RISCV_DEBUG
        printf("sw %i,%i,0x%x\n", RS1, RS2, (int)S_IMM);
#endif
        bus(addr, WORD, true, &regs[RS2]);
        break;
      }
      default:
        return 0x11;
      }
      break;
    }
    case 0x13: // immediate arithmetic
    {
      switch (FUNCT3) {
      case 0x0: // ADDI
      {
#ifdef RISCV_DEBUG
        printf("addi %i,%i\n", RS1, I_IMM);
#endif
        regs[RD] = (int)regs[RS1] + (int)I_IMM;
        break;
      }
      case 0x2: // SLTI
      {
#ifdef RISCV_DEBUG
        printf("slti %i,%i\n", RS1, I_IMM);
#endif
        regs[RD] = (int)regs[RS1] < (int)I_IMM ? 1 : 0;
        break;
      }
      case 0x3: // SLTIU
      {
#ifdef RISCV_DEBUG
        printf("sltiu %i,%i\n", RS1, I_IMM);
#endif
        regs[RD] = regs[RS1] < (unsigned)I_IMM ? 1 : 0;
        break;
      }
      case 0x4: // XORI
      {
#ifdef RISCV_DEBUG
        printf("xori %i,%i\n", RS1, I_IMM);
#endif
        regs[RD] = regs[RS1] ^ (unsigned)I_IMM;
        break;
      }
      case 0x6: // ORI
      {
#ifdef RISCV_DEBUG
        printf("ori %i,%i\n", RS1, I_IMM);
#endif
        regs[RD] = regs[RS1] | (unsigned)I_IMM;
        break;
      }
      case 0x7: // ANDI
      {
#ifdef RISCV_DEBUG
        printf("andi %i,%i\n", RS1, I_IMM);
#endif
        regs[RD] = regs[RS1] & (unsigned)I_IMM;
        break;
      }
      case 0x1: // SLLI
      {
#ifdef RISCV_DEBUG
        printf("slli %i,%i\n", RS1, RS2);
#endif
        regs[RD] = regs[RS1] << (RS2);
        break;
      }
      case 0x5: // SRLI/SRAI
      {
        switch (FUNCT7) {
        case 0x0: // SRLI
        {
#ifdef RISCV_DEBUG
          printf("srli %i,%i\n", RS1, RS2);
#endif
          regs[RD] = regs[RS1] >> (RS2);
          break;
        }
        case 0x20: // SRAI
        {
#ifdef RISCV_DEBUG
          printf("srai %i,%i\n", RS1, RS2);
#endif
          regs[RD] = (int)regs[RS1] >> RS2;
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
      switch (FUNCT3) {
      case 0x0: // ADD / SUB
      {
        switch (FUNCT7) {
        case 0x0: // ADD
        {
#ifdef RISCV_DEBUG
          printf("add %i,%i\n", RS1, RS2);
#endif
          regs[RD] = regs[RS1] + regs[RS2];
          break;
        }
        case 0x20: // SUB
        {
#ifdef RISCV_DEBUG
          printf("sub %i,%i\n", RS1, RS2);
#endif
          regs[RD] = regs[RS1] - regs[RS2];
          break;
        }
        default:
          return 0x14;
        }
        break;
      }
      case 0x1: // SLL
      {
#ifdef RISCV_DEBUG
        printf("sll %i,%i\n", RS1, RS2);
#endif
        regs[RD] = regs[RS1] << (regs[RS2] & 0x1f);
        break;
      }
      case 0x2: // SLT
      {
#ifdef RISCV_DEBUG
        printf("slt %i,%i\n", RS1, RS2);
#endif
        regs[RD] = (int)regs[RS1] < (int)regs[RS2] ? 1 : 0;
        break;
      }
      case 0x3: // SLTU
      {
#ifdef RISCV_DEBUG
        printf("sltu %i,%i\n", RS1, RS2);
#endif
        regs[RD] = regs[RS1] < regs[RS2] ? 1 : 0;
        break;
      }
      case 0x4: // XOR
      {
#ifdef RISCV_DEBUG
        printf("xor %i,%i\n", RS1, RS2);
#endif
        regs[RD] = regs[RS1] ^ regs[RS2];
        break;
      }
      case 0x5: // SRL / SRA
      {
        switch (FUNCT7) {
        case 0x0: // SRL
        {
#ifdef RISCV_DEBUG
          printf("srl %i,%i\n", RS1, RS2);
#endif
          regs[RD] = regs[RS1] >> (regs[RS2] & 0x1f);
          break;
        }
        case 0x20: // SRA
        {
#ifdef RISCV_DEBUG
          printf("sra %i,%i\n", RS1, RS2);
#endif
          regs[RD] = (int)regs[RS1] >> (regs[RS2] & 0x1f);
          break;
        }
        default:
          return 0x15;
        }
        break;
      }
      case 0x6: // OR
      {
#ifdef RISCV_DEBUG
        printf("or %i,%i\n", RS1, RS2);
#endif
        regs[RD] = regs[RS1] | regs[RS2];
        break;
      }
      case 0x7: // AND
      {
#ifdef RISCV_DEBUG
        printf("and %i,%i\n", RS1, RS2);
#endif
        regs[RD] = regs[RS1] & regs[RS2];
        break;
      }
      default:
        return 0x16;
      }
      break;
    }

    case 0x37: // LUI
    {
#ifdef RISCV_DEBUG
      printf("lui 0x%x,0x%x\n", RD, (unsigned)U_IMM >> 12);
#endif
      regs[RD] = U_IMM;
      break;
    }

    case 0x17: // AUIPC
    {
#ifdef RISCV_DEBUG
      printf("auipc 0x%x,0x%x\n", RD, (unsigned)U_IMM >> 12);
#endif
      regs[RD] = U_IMM + pc;
      break;
    }

    case 0x6F: // JAL
    {
#ifdef RISCV_DEBUG
      printf("jal 0x%x,0x%x\n", RD, (int)J_IMM);
#endif
      regs[RD] = pc + 4;
      pc += (int)J_IMM - 4;
      // note: pc is incremented by 4 after the instruction
      break;
    }

    case 0x67: // JALR
    {
#ifdef RISCV_DEBUG
      printf("jalr 0x%x,0x%x,0x%x\n", RD, RS1, (int)I_IMM);
#endif
      regs[RD] = pc + 4;
      pc = regs[RS1] + (int)I_IMM - 4;
      // note: pc is incremented by 4 after the instruction
      break;
    }

    case 0x63: // branching
    {
      switch (FUNCT3) {
      case 0x0: // BEQ
      {
#ifdef RISCV_DEBUG
        printf("beq %i,%i\n", RS1, RS2);
#endif
        if (regs[RS1] == regs[RS2]) {
          pc += (int)B_IMM - 4;
          // note: pc is incremented by 4 after the instruction
        }
        break;
      }
      case 0x1: // BNE
      {
#ifdef RISCV_DEBUG
        printf("bne %i,%i\n", RS1, RS2);
#endif
        if (regs[RS1] != regs[RS2]) {
          pc += (int)B_IMM - 4;
          // note: pc is incremented by 4 after the instruction
        }
        break;
      }
      case 0x4: // BLT
      {
#ifdef RISCV_DEBUG
        printf("blt %i,%i\n", RS1, RS2);
#endif
        if ((int)regs[RS1] < (int)regs[RS2]) {
          pc += (int)B_IMM - 4;
          // note: pc is incremented by 4 after the instruction
        }
        break;
      }
      case 0x5: // BGE
      {
#ifdef RISCV_DEBUG
        printf("bge %i,%i\n", RS1, RS2);
#endif
        if ((int)regs[RS1] >= (int)regs[RS2]) {
          pc += (int)B_IMM - 4;
          // note: pc is incremented by 4 after the instruction
        }
        break;
      }
      case 0x6: // BLTU
      {
#ifdef RISCV_DEBUG
        printf("bltu %i,%i,%i\n", RS1, RS2, (int)B_IMM);
#endif
        if (regs[RS1] < regs[RS2]) {
          pc += (int)B_IMM - 4;
        }
        break;
      }
      case 0x7: // BGEU
      {
#ifdef RISCV_DEBUG
        printf("bgeu %i,%i\n", RS1, RS2);
#endif
        if (regs[RS1] >= regs[RS2]) {
          pc += (int)B_IMM - 4;
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

    pc += 4;
    return 0;
  }
};
