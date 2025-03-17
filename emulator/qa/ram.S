.global _start

_start:
	addi x0, x0, 0			# nop
	lui x10, 0x12345		# x10 = 0x1234_5678
	addi x10, x10, 0x678
	addi x11, x0, 3			# x11 = 3
	slti x12, x11, 4		# x12 = 1
	slti x12, x11, -1		# x12 = 0
	sltiu x12, x11, 4		# x12 = 1
	sltiu x12, x11, -1		# x12 = 1
	xori x13, x12, -1		# x13 = 0xffff_fffe
	ori x13, x13, 1			# x13 = 0xffff_ffff
	andi x13, x13, 2		# x13 = 2
	slli x13, x13, 3		# x13 = 16
	srli x13, x13, 3		# x13 = 2
	xori x13, x13, -1       # x13 = 0xffff_fffd == -3
	srai x13, x13, 1		# x13 = 0xffff_fffe == -2
	add x14, x13, x12		# x14 = -2 + 1 == -1
	sub x14, x14, x12		# x14 = -1 - 1 == -2
	sll x15, x12, x12		# x15 = 1 << 1 == 2
	slt x16, x12, x15		# x16 = 1 (1 < 2)
	slt x16, x12, x12		# x16 = 0 (1 < 1)
	sltu x16, x16, x13		# x16 = 1 (0 < 0xfff_ffe)
	xor x17, x16, x13		# x17 = -1 (1 ^ 0xffff_fffe)
	srl x18, x11, x16		# x18 = 3 >> 1 == 1
	sra x18, x17, x16		# x18 = 0xffff_fffe >>> 1 == -1
	or x19, x16, x11		# x19 = 1 | 3 == 3
	and x19, x19, x16		# x19 = 3 & 1 == 1
	lui x20, 0x1			# x20 = 0x0000_1000
	sw x19, 4(x20)			# ram[0x1000 + 4] == 0x0000_0001
	lw x21, 4(x20)			# x21 = ram[0x1000 + 4] == 0x0000_0001
	sh x19, 6(x20)			# ram[0x1000 + 6] == 0x0001
	lh x21, 6(x20)			# x21 = ram[0x1000 + 6] == 0x0000_0001
	sb x19, 7(x20)			# ram[0x1000 + 7] == 0x01
	lb x21, 7(x20)			# x21 = ram[0x1000 + 7] == 0x01
	lb x21, 4(x20)			# x21 = ram[0x1000 + 4] == 0x01
	lh x21, 6(x20)			# x21 = ram[0x1000 + 6] == 0x0101
	lw x21, 4(x20)			# x21 = ram[0x1000 + 4] == 0x0101_0001
	sw x17, 0(x20)			# ram[0x1000] = 0xffff_ffff
	lbu x21, 0(x20)			# x21 = ram[0x1000] == 0xff
	lhu x21, 2(x20)			# x21 = ram[0x1000 + 2] == 0xffff
	addi x22, x21, 1        # x22 = 0xffff + 1 == 0x1_0000
	jal x1, lbl_jal			#
	beq x22, x22, lbl_beq	# x22 == x22 -> branch taken
lbl1:
	bne x22, x21, lbl_bne	# 0x1_0000 != 0xffff -> branch taken
lbl2:
	blt x21, x22, lbl_blt   # 0xffff < 0x1_0000 -> branch taken
lbl3:
	bge x22, x21, lbl_bge	# 0x1_0000 >= 0xffff -> branch taken
lbl4:
	bltu x19, x18, lbl_bltu	# 1 < 0xffff_ffff -> branch taken
lbl5:
	bgeu x18, x19, lbl_bgeu	# 0xffff_ffff > 1 -> branch taken
lbl6:
	beq x22, x21, lbl_beq	# 0x1_0000 != 0xffff -> branch not taken 
	bne x21, x21, lbl_beq	# 0xffff == 0xffff -> branch not taken 
	blt x22, x21, lbl_blt   # 0x1_0000 > 0xffff -> branch not taken
	bge x21, x22, lbl_bge	# 0xffff < 0x1_0000 -> branch not taken
	bltu x18, x19, lbl_bltu	# 0xffff_ffff > 1 -> branch not taken
	bgeu x19, x18, lbl_bgeu	# 1 < 0xffff_ffff -> branch not taken
	jal x1, lbl_auipc
	# test the leds
	ori x24, x24, -1		# x24 = 0xffff_ffff
	addi x23, x0, 0b1010101
#	addi x23, x0, 0b0000000
	sb x23, 0(x24)			#  write to memory mapped I/O ram[0xffff_ffff] = 0b111_1111

	# check that register is writting the result of the op instead of the ram
	lhu x21, 2(x20)			# x21 = ram[0x1000 + 2] == 0xffff
	addi x21, x21, 1        # x21 = 0xffff + 1 == 0x1_0000

	sw x21, (x20)			# ram[0x1000] = 0x1_0000
	lw x25, (x20)			# x25 = ram[0x1000] == 0x1_0000
	addi x26, x25, 1		# x26 = 0x1_0000 + 1 == 0x1_0001
	addi x26, x26,-1		# x26 = 0x1_0001 - 1 == 0x1_0000

lbl_done:
	jal x0, lbl_done

.org 0x400
lbl_jal:
	jalr x1, 0(x1)

.org 0x408
lbl_beq:
	jal x0, lbl1

.org 0x410
lbl_bne:
	jal x0, lbl2

.org 0x418
lbl_blt:
	jal x0, lbl3

.org 0x420
lbl_bge:
	jal x0, lbl4

.org 0x428
lbl_bltu:
	jal x0, lbl5

.org 0x430
lbl_bgeu:
	jal x0, lbl6

.org 0x438
lbl_auipc:
	auipc x2, 0xfffff	# 0x0438 + 0xffff_f0000 (-4096) == -3016 = 0xffff_f438
	jalr x0, 0(x1)
