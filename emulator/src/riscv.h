// from https://github.com/alexriegler12/riscv with minor modifications.

#ifndef RISCV_H
#define RISCV_H

#define I_IMM                                                                  \
  (instruction & 0x80000000) ? 0xFFFFF000 | instruction >> 20                  \
                             : instruction >> 20
#define S_IMM                                                                  \
  (instruction & 0x80000000)                                                   \
      ? 0xFFFFF000 | ((instruction >> 7) & 0x1F) |                             \
            ((instruction >> 20) & 0xFE0)                                      \
      : ((instruction >> 7) & 0x1F) | ((instruction >> 20) & 0xFE0)
#define U_IMM instruction & 0xFFFFF000
#define B_IMM                                                                  \
  (instruction & 0x80000000)                                                   \
      ? 0xFFFFE000 | ((instruction << 4) & 0x800) |                            \
            ((instruction >> 7) & 0x1E) | ((instruction >> 20) & 0x7E0) |      \
            ((instruction >> 19) & 0x1000)                                     \
      : ((instruction << 4) & 0x800) | ((instruction >> 7) & 0x1E) |           \
            ((instruction >> 20) & 0x7E0) | ((instruction >> 19) & 0x1000)
#define J_IMM                                                                  \
  (instruction & 0x80000000)                                                   \
      ? 0xFFE00000 | ((instruction >> 20) & 0x7FE) |                           \
            ((instruction >> 9) & 0x800) | (instruction & 0xFF000) |           \
            ((instruction >> 11) & 0x100000)                                   \
      : ((instruction >> 20) & 0x7FE) | ((instruction >> 9) & 0x800) |         \
            (instruction & 0xFF000) | ((instruction >> 11) & 0x100000)

#define OPCODE instruction & 0x7F
#define RS1 ((instruction >> 15) & 0x1F)
#define RS2 ((instruction >> 20) & 0x1F)
#define RD ((instruction >> 7) & 0x1F)
#define FUNCT3 ((instruction >> 12) & 0x7)
#define FUNCT7 ((instruction >> 25) & 0x7F)

typedef unsigned int rv_uint32;
typedef signed int rv_int32;

typedef enum buswidth {
  RVBUS_BYTE = 1,
  RVBUS_SHORT = 2,
  RVBUS_LONG = 4
} RISCV_BUSWIDTH;

typedef rv_uint32 (*rvbuscallback)(rv_uint32 addr, RISCV_BUSWIDTH width,
                                   rv_uint32 is_store, rv_uint32 *data);

typedef struct rvcpu {
  rv_uint32 regs[32];
  rv_uint32 pc;
  rvbuscallback bus;
} RISCV;

rv_uint32 riscv_init(RISCV *cpu, rvbuscallback bus, rv_uint32 resetvec) {
  cpu->pc = resetvec;
  cpu->bus = bus;
  return 0;
}

rv_uint32 riscv_cycle(RISCV *cpu) {
  rv_uint32 instruction = 0;
  cpu->regs[0] = 0x0;
  rv_uint32 errorcode = cpu->bus(cpu->pc, RVBUS_LONG, 0, &instruction);
  if (errorcode != 0) {
    cpu->pc += 4;
    return errorcode;
  }
#ifdef RISCV_DEBUG
  printf("pc 0x%08x instr 0x%08x ", cpu->pc, instruction);
#endif
  switch (OPCODE) {
  case 0x3: /*Load*/
  {
    rv_uint32 laddr = cpu->regs[RS1] + (rv_int32)(I_IMM);
    switch (FUNCT3) {
    case 0x0: /*LB*/
    {
#ifdef RISCV_DEBUG
      printf("lb %i,%i,0x%x\n", RS1, RD, (rv_int32)(I_IMM));
#endif
      rv_uint32 loaded = 0;
      cpu->bus(laddr, RVBUS_BYTE, 0, &loaded);
      cpu->regs[RD] = loaded & 0x80 ? 0xFFFFFF00 | loaded : loaded;
      break;
    }
    case 0x1: /*LH*/
    {
#ifdef RISCV_DEBUG
      printf("lh %i,%i,0x%x\n", RS1, RD, (rv_int32)(I_IMM));
#endif
      rv_uint32 loaded = 0;
      cpu->bus(laddr, RVBUS_SHORT, 0, &loaded);
      cpu->regs[RD] = loaded & 0x8000 ? 0xFFFF0000 | loaded : loaded;
      break;
    }
    case 0x2: /*LW*/
    {
#ifdef RISCV_DEBUG
      printf("lw %i,%i,0x%x\n", RS1, RD, (rv_int32)(I_IMM));
#endif
      rv_uint32 loaded = 0;
      cpu->bus(laddr, RVBUS_LONG, 0, &loaded);
      cpu->regs[RD] = loaded;
      break;
    }
    case 0x4: /*LBU*/
    {
#ifdef RISCV_DEBUG
      printf("lbu %i,%i,0x%x\n", RS1, RD, (rv_int32)(I_IMM));
#endif
      rv_uint32 loaded = 0;
      cpu->bus(laddr, RVBUS_BYTE, 0, &loaded);
      cpu->regs[RD] = loaded;
      break;
    }
    case 0x5: /*LHU*/
    {
#ifdef RISCV_DEBUG
      printf("lhu %i,%i,0x%x\n", RS1, RD, (rv_int32)(I_IMM));
#endif
      rv_uint32 loaded = 0;
      cpu->bus(laddr, RVBUS_SHORT, 0, &loaded);
      cpu->regs[RD] = loaded;
      break;
    }
    default:
      return 0x10;
    }
    break;
  }
  case 0x23: /*Store*/
  {
    rv_uint32 saddr = cpu->regs[RS1] + (rv_int32)(S_IMM);
    switch (FUNCT3) {
    case 0x0: /*SB*/
    {
#ifdef RISCV_DEBUG
      printf("sb %i,%i,0x%x\n", RS1, RS2, (rv_int32)(S_IMM));
#endif
      rv_uint32 val = (cpu->regs[RS2]) & 0xFF;
      cpu->bus(saddr, RVBUS_BYTE, 1, &val);
      break;
    }
    case 0x1: /*SH*/
    {
#ifdef RISCV_DEBUG
      printf("sh %i,%i,0x%x\n", RS1, RS2, (rv_int32)(S_IMM));
#endif
      rv_uint32 val = (cpu->regs[RS2]) & 0xFFFF;
      cpu->bus(saddr, RVBUS_SHORT, 1, &val);
      break;
    }
    case 0x2: /*SW*/
    {
#ifdef RISCV_DEBUG
      printf("sw %i,%i,0x%x\n", RS1, RS2, (rv_int32)(S_IMM));
#endif
      cpu->bus(saddr, RVBUS_LONG, 1, &cpu->regs[RS2]);
      break;
    }
    default:
      return 0x11;
    }
    break;
  }
  case 0x13: /*Immediate Arithmetic*/
  {
    switch (FUNCT3) {
    case 0x0: /*ADDI*/
    {
#ifdef RISCV_DEBUG
      printf("addi %i,%i\n", RS1, I_IMM);
#endif
      cpu->regs[RD] = (rv_int32)(I_IMM) + cpu->regs[RS1];
      break;
    }
    case 0x2: /*SLTI*/
    {
#ifdef RISCV_DEBUG
      printf("slti %i,%i\n", RS1, I_IMM);
#endif
      cpu->regs[RD] = ((rv_int32)(cpu->regs[RS1]) < (rv_int32)(I_IMM)) ? 1 : 0;
      break;
    }
    case 0x3: /*SLTIU*/
    {
#ifdef RISCV_DEBUG
      printf("sltiu %i,%i\n", RS1, I_IMM);
#endif
      cpu->regs[RD] =
          ((rv_uint32)(cpu->regs[RS1]) < (rv_uint32)(I_IMM)) ? 1 : 0;
      break;
    }
    case 0x4: /*XORI*/
    {
#ifdef RISCV_DEBUG
      printf("xori %i,%i\n", RS1, I_IMM);
#endif
      cpu->regs[RD] = cpu->regs[RS1] ^ (rv_uint32)(I_IMM);
      break;
    }
    case 0x6: /*ORI*/
    {
#ifdef RISCV_DEBUG
      printf("ori %i,%i\n", RS1, I_IMM);
#endif
      cpu->regs[RD] = cpu->regs[RS1] | (rv_uint32)(I_IMM);
      break;
    }
    case 0x7: /*ANDI*/
    {
#ifdef RISCV_DEBUG
      printf("andi %i,%i\n", RS1, I_IMM);
#endif
      cpu->regs[RD] = cpu->regs[RS1] & (rv_uint32)(I_IMM);
      break;
    }
    case 0x1: /*SLLI*/
    {
#ifdef RISCV_DEBUG
      printf("slli %i,%i\n", RS1, (RS2));
#endif
      cpu->regs[RD] = cpu->regs[RS1] << (RS2);
      break;
    }
    case 0x5: /*SRLI/SRAI*/
    {
      switch (FUNCT7) {
      case 0x0: /*SRLI*/
      {
#ifdef RISCV_DEBUG
        printf("srli %i,%i\n", RS1, (RS2));
#endif
        cpu->regs[RD] = cpu->regs[RS1] >> (RS2);
        break;
      }
      case 0x20: /*SRAI*/
      {
#ifdef RISCV_DEBUG
        printf("srai %i,%i\n", RS1, (RS2));
#endif
#ifdef NEED_CUSTOM_ARITHSHIFT
        if (cpu->regs[RS1] & 0x80000000) {
          rv_uint32 shifttemp = cpu->regs[RS1] >> (RS2);
          cpu->regs[RD] = (0xFFFFFFFF << (32 - (RS2))) | shifttemp;
        } else {

          cpu->regs[RD] = cpu->regs[RS1] >> (RS2);
        }
#else

        cpu->regs[RD] = (rv_int32)cpu->regs[RS1] >> (RS2);
#endif
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

  case 0x33: /*Register Arithmetic*/
  {
    switch (FUNCT3) {
    case 0x0: /*ADD/SUB*/
    {
      switch (FUNCT7) {
      case 0x0: /*ADD*/
      {
#ifdef RISCV_DEBUG
        printf("add %i,%i\n", RS1, RS2);
#endif
        cpu->regs[RD] = cpu->regs[RS1] + cpu->regs[RS2];
        break;
      }
      case 0x20: /*SUB*/
      {
#ifdef RISCV_DEBUG
        printf("sub %i,%i\n", RS1, RS2);
#endif
        cpu->regs[RD] = cpu->regs[RS1] - cpu->regs[RS2];
        break;
      }
      default:
        return 0x14;
      }
      break;
    }
    case 0x1: /*SLL*/
    {
#ifdef RISCV_DEBUG
      printf("sll %i,%i\n", RS1, RS2);
#endif
      cpu->regs[RD] = cpu->regs[RS1] << (cpu->regs[RS2] & 0x1F);
      break;
    }
    case 0x2: /*SLT*/
    {
#ifdef RISCV_DEBUG
      printf("slt %i,%i\n", RS1, RS2);
#endif
      cpu->regs[RD] =
          ((rv_int32)(cpu->regs[RS1]) < (rv_int32)(cpu->regs[RS2])) ? 1 : 0;
      break;
    }
    case 0x3: /*SLTU*/
    {
#ifdef RISCV_DEBUG
      printf("sltu %i,%i\n", RS1, RS2);
#endif
      cpu->regs[RD] =
          ((rv_uint32)(cpu->regs[RS1]) < (rv_uint32)(cpu->regs[RS2])) ? 1 : 0;
      break;
    }
    case 0x4: /*XOR*/
    {
#ifdef RISCV_DEBUG
      printf("xor %i,%i\n", RS1, RS2);
#endif
      cpu->regs[RD] = cpu->regs[RS1] ^ cpu->regs[RS2];
      break;
    }
    case 0x5: /*SRL/SRA*/
    {
      switch (FUNCT7) {
      case 0x0: /*SRL*/
      {
#ifdef RISCV_DEBUG
        printf("srl %i,%i\n", RS1, RS2);
#endif
        cpu->regs[RD] = cpu->regs[RS1] >> (cpu->regs[RS2] & 0x1F);
        break;
      }
      case 0x20: /*SRA*/
      {
#ifdef RISCV_DEBUG
        printf("sra %i,%i\n", RS1, RS2);
#endif
#ifdef NEED_CUSTOM_ARITHSHIFT
        if (cpu->regs[RS1] & 0x80000000) {
          rv_uint32 shifttemp = cpu->regs[RS1] >> (cpu->regs[RS2] & 0x1F);
          cpu->regs[RD] =
              (0xFFFFFFFF << (32 - (cpu->regs[RS2] & 0x1F))) | shifttemp;
        } else {

          cpu->regs[RD] = cpu->regs[RS1] >> (cpu->regs[RS2] & 0x1F);
        }
#else

        cpu->regs[RD] = (rv_int32)cpu->regs[RS1] >> (cpu->regs[RS2] & 0x1F);
#endif
        break;
      }
      default:
        return 0x15;
      }
      break;
    }
    case 0x6: /*OR*/
    {
#ifdef RISCV_DEBUG
      printf("or %i,%i\n", RS1, RS2);
#endif
      cpu->regs[RD] = cpu->regs[RS1] | cpu->regs[RS2];
      break;
    }
    case 0x7: /*AND*/
    {
#ifdef RISCV_DEBUG
      printf("and %i,%i\n", RS1, RS2);
#endif
      cpu->regs[RD] = cpu->regs[RS1] & cpu->regs[RS2];
      break;
    }
    default:
      return 0x16;
    }
    break;
  }

  case 0x37: /*LUI*/
  {
#ifdef RISCV_DEBUG
    printf("lui 0x%x,0x%x\n", RD, (unsigned int)(U_IMM) >> 12);
#endif
    cpu->regs[RD] = U_IMM;
    break;
  }

  case 0x17: /*AUIPC*/
  {
#ifdef RISCV_DEBUG
    printf("auipc 0x%x,0x%x\n", RD, (unsigned int)(U_IMM) >> 12);
#endif
    cpu->regs[RD] = (U_IMM) + cpu->pc;
    break;
  }

  case 0x6F: /*JAL*/
  {
#ifdef RISCV_DEBUG
    printf("jal 0x%x,0x%x\n", RD, ((unsigned int)(J_IMM)));
#endif
    cpu->regs[RD] = cpu->pc + 0x4;
    cpu->pc = cpu->pc + (rv_int32)(J_IMM)-0x4;
    break;
  }

  case 0x67: /*JALR*/
  {
#ifdef RISCV_DEBUG
    printf("jalr 0x%x,0x%x,0x%x\n", RD, RS1, (unsigned int)(I_IMM));
#endif
    cpu->regs[RD] = cpu->pc + 0x4;
    cpu->pc = ((cpu->regs[RS1] + (rv_int32)(I_IMM)) & 0xFFFFFFFE) - 0x4;
    break;
  }

  case 0x63: /*Branching*/
  {
    switch (FUNCT3) {
    case 0x0: /*BEQ*/
    {
#ifdef RISCV_DEBUG
      printf("beq %i,%i\n", RS1, RS2);
#endif
      if (cpu->regs[RS1] == cpu->regs[RS2]) {
        cpu->pc = cpu->pc + (rv_int32)(B_IMM)-0x4;
      }
      break;
    }
    case 0x1: /*BNE*/
    {
#ifdef RISCV_DEBUG
      printf("bne %i,%i\n", RS1, RS2);
#endif
      if (cpu->regs[RS1] != cpu->regs[RS2]) {
        cpu->pc = cpu->pc + (rv_int32)(B_IMM)-0x4;
      }
      break;
    }
    case 0x4: /*BLT*/
    {
#ifdef RISCV_DEBUG
      printf("blt %i,%i\n", RS1, RS2);
#endif
      if ((rv_int32)(cpu->regs[RS1]) < (rv_int32)(cpu->regs[RS2])) {
        cpu->pc = cpu->pc + (rv_int32)(B_IMM)-0x4;
      }
      break;
    }
    case 0x5: /*BGE*/
    {
#ifdef RISCV_DEBUG
      printf("bge %i,%i\n", RS1, RS2);
#endif
      if ((rv_int32)(cpu->regs[RS1]) >= (rv_int32)(cpu->regs[RS2])) {
        cpu->pc = cpu->pc + (rv_int32)(B_IMM)-0x4;
      }
      break;
    }
    case 0x6: /*BLTU*/
    {
#ifdef RISCV_DEBUG
      printf("bltu %i,%i,%i\n", RS1, RS2, (rv_int32)(B_IMM));
#endif
      if (cpu->regs[RS1] < cpu->regs[RS2]) {
        cpu->pc = (cpu->pc + (rv_int32)(B_IMM)) - 0x4;
      }
      break;
    }
    case 0x7: /*BGEU*/
    {
#ifdef RISCV_DEBUG
      printf("bgeu %i,%i\n", RS1, RS2);
#endif
      if (cpu->regs[RS1] >= cpu->regs[RS2]) {
        cpu->pc = cpu->pc + (rv_int32)(B_IMM)-0x4;
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

  cpu->pc += 4;
  return 0;
}

#endif
