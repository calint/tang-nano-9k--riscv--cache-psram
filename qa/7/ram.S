.global _start

_start:
  lui	x2,0x10
  jal	x1,run

run:
  addi	x2,x2,-16 # fff0 <__global_pointer$+0xe760>
  sw	x1,12(x2)
  sw	x8,8(x2)
  addi	x8,x2,16
#   print_pointer_address((void *)0);
  addi	x10,x0,0
  auipc	x1,0x0
  jalr	x1,28(x1) # 38 <print_pointer_address>
# }
  addi	x0,x0,0
  lw	x1,12(x2)
  lw	x8,8(x2)
  addi	x2,x2,16
  jalr	x0,0(x1)

# 00000038 <print_pointer_address>:
# void print_pointer_address(void *ptr) {
  addi	x2,x2,-48
  sw	x8,44(x2)
  addi	x8,x2,48
  sw	x10,-36(x8)
#   const unsigned address = (unsigned)ptr;
  lw	x15,-36(x8)
  sw	x15,-24(x8)
#   *leds = (char)address;
  lui	x15,0x1
  lw	x15,144(x15) # 1090 <leds>
  lw	x14,-24(x8)
  andi	x14,x14,255
  sb	x14,0(x15)
#   int i = 0;
  sw	x0,-20(x8)
#   while(i--);
  addi	x0,x0,0
  lw	x15,-20(x8)
  addi	x14,x15,-1
  sw	x14,-20(x8)
  bne	x15,x0,0x6c
# }
  addi	x0,x0,0
  addi	x0,x0,0
  lw	x8,44(x2)
  addi	x2,x2,48
  jalr	x0,0(x1)

.org 0x1090
.word 0xffffffff