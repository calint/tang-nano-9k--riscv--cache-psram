`timescale 100ps / 100ps
//
// RAMIO + BurstRAM
//
`default_nettype none

module TestBench;
  reg sys_rst_n = 0;
  reg clk = 1;
  localparam clk_tk = 36;
  always #(clk_tk / 2) clk = ~clk;

  localparam RAM_DEPTH_BITWIDTH = 10;  // 2^10 * 8 B = 8192 B

  wire [5:0] led;
  wire uart_tx;
  reg uart_rx;

  //------------------------------------------------------------------------
  wire br_cmd;
  wire br_cmd_en;
  wire [RAM_DEPTH_BITWIDTH-1:0] br_addr;
  wire [63:0] br_wr_data;
  wire [7:0] br_data_mask;
  wire [63:0] br_rd_data;
  wire br_rd_data_valid;
  wire br_init_calib;
  wire br_busy;

  BurstRAM #(
      .DATA_FILE(""),  // initial RAM content
      .DEPTH_BITWIDTH(RAM_DEPTH_BITWIDTH),  // 2 ^ x * 8 B entries
      .BURST_COUNT(4),  // 4 * 64 bit data per burst
      .CYCLES_BEFORE_DATA_VALID(6),
      .CYCLES_BEFORE_INITIATED(0)
  ) burst_ram (
      .clk(clk),
      .rst_n(sys_rst_n),
      .cmd(br_cmd),  // 0: read, 1: write
      .cmd_en(br_cmd_en),  // 1: cmd and addr is valid
      .addr(br_addr),  // 8 bytes word
      .wr_data(br_wr_data),  // data to write
      .data_mask(br_data_mask),  // not implemented (same as 0 in IP component)
      .rd_data(br_rd_data),  // read data
      .rd_data_valid(br_rd_data_valid),  // rd_data is valid
      .init_calib(br_init_calib),
      .busy(br_busy)
  );
  //------------------------------------------------------------------------
  wire ramio_enable;
  wire [1:0] ramio_write_type;
  wire [2:0] ramio_read_type;
  wire [31:0] ramio_address;
  wire [31:0] ramio_data_out;
  wire ramio_data_out_ready;
  wire [31:0] ramio_data_in;
  wire ramio_busy;

  RAMIO #(
      .RAM_DEPTH_BITWIDTH(RAM_DEPTH_BITWIDTH),
      .RAM_ADDRESSING_MODE(3),  // 64 bit word RAM
      .CACHE_LINE_IX_BITWIDTH(1),
      .CLK_FREQ(20_250_000),
      .BAUD_RATE(20_250_000)
  ) ramio (
      .rst_n(sys_rst_n && br_init_calib),
      .clk(clk),
      .enable(ramio_enable),
      .write_type(ramio_write_type),
      .read_type(ramio_read_type),
      .address(ramio_address),
      .data_in(ramio_data_in),
      .data_out(ramio_data_out),
      .data_out_ready(ramio_data_out_ready),
      .busy(ramio_busy),
      .led(led[3:0]),
      .uart_tx(uart_tx),
      .uart_rx(uart_rx),

      // burst RAM wiring; prefix 'br_'
      .br_cmd(br_cmd),  // 0: read, 1: write
      .br_cmd_en(br_cmd_en),  // 1: cmd and addr is valid
      .br_addr(br_addr),  // see 'RAM_ADDRESSING_MODE'
      .br_wr_data(br_wr_data),  // data to write
      .br_data_mask(br_data_mask),  // always 0 meaning write all bytes
      .br_rd_data(br_rd_data),  // data out
      .br_rd_data_valid(br_rd_data_valid)  // rd_data is valid
  );
  //------------------------------------------------------------------------
  output reg flash_clk;
  input wire flash_miso;
  output reg flash_mosi;
  output reg flash_cs;

  Flash #(
      .DATA_FILE("RAM.mem"),
      .DEPTH_BITWIDTH(12)  // in bytes 2^12 = 4096 B
  ) dut (
      .rst_n(sys_rst_n),
      .clk(flash_clk),
      .miso(flash_miso),
      .mosi(flash_mosi),
      .cs(flash_cs)
  );
  //------------------------------------------------------------------------
  Core #(
      .STARTUP_WAIT(0),
      .FLASH_TRANSFER_BYTES_NUM(4096)
  ) core (
      .rst_n(sys_rst_n && br_init_calib),
      .clk  (clk),
      .led  (led[4]),

      .ramio_enable(ramio_enable),
      .ramio_write_type(ramio_write_type),
      .ramio_read_type(ramio_read_type),
      .ramio_address(ramio_address),
      .ramio_data_in(ramio_data_in),
      .ramio_data_out(ramio_data_out),
      .ramio_data_out_ready(ramio_data_out_ready),
      .ramio_busy(ramio_busy),

      .flash_clk (flash_clk),
      .flash_miso(flash_miso),
      .flash_mosi(flash_mosi),
      .flash_cs  (flash_cs)
  );
  //------------------------------------------------------------------------
  assign led[5] = ~ramio_busy;
  //------------------------------------------------------------------------
  initial begin
    $dumpfile("log.vcd");
    $dumpvars(0, TestBench);

    #clk_tk;
    #clk_tk;
    sys_rst_n <= 1;
    #clk_tk;

    // wait for burst RAM to initiate
    while (br_busy) #clk_tk;

    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;

    // for (int i = 0; i < 16; i++) begin
    //   $display("%0d: %h", i, burst_ram.data[i]);
    // end

    // 0: 00000013 addi x0,x0,0
    #clk_tk;
    #clk_tk;

    // 4: 12345537 lui x10,0x12345
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[10] == 32'h1234_5000) $display("Test 1 passed");
    else $display("Test 1 FAILED");

    // 8: 67850513 addi x10,x10,1656 # 12345678
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[10] == 32'h1234_5678) $display("Test 2 passed");
    else $display("Test 2 FAILED");

    // c: 00300593 addi x11,x0,3
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[11] == 32'h3) $display("Test 3 passed");
    else $display("Test 3 FAILED");

    // 10: 0045a613 slti x12,x11,4
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[12] == 32'h1) $display("Test 4 passed");
    else $display("Test 4 FAILED");

    // 14: fff5a613 slti x12,x11,-1
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[12] == 32'h0) $display("Test 5 passed");
    else $display("Test 5 FAILED");

    // 18: 0045b613 sltiu x12,x11,4
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[12] == 32'h1) $display("Test 6 passed");
    else $display("Test 6 FAILED");

    // 1c: fff5b613 sltiu x12,x11,-1
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[12] == 32'h1) $display("Test 7 passed");
    else $display("Test 7 FAILED");

    // 20: fff64693 xori x13,x12,-1
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[13] == 32'hffff_fffe) $display("Test 8 passed");
    else $display("Test 8 FAILED");

    // 24: 0016e693 ori x13,x13,1
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[13] == 32'hffff_ffff) $display("Test 9 passed");
    else $display("Test 9 FAILED");

    // 28: 0026f693 andi x13,x13,2
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[13] == 32'h2) $display("Test 10 passed");
    else $display("Test 10 FAILED");

    // 2c: 00369693 slli x13,x13,0x3
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[13] == 16) $display("Test 11 passed");
    else $display("Test 11 FAILED");

    // 30: 0036d693 srli x13,x13,0x3
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[13] == 2) $display("Test 12 passed");
    else $display("Test 12 FAILED");

    // 34: fff6c693 xori x13,x13,-1
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[13] == -3) $display("Test 13 passed");
    else $display("Test 13 FAILED");

    // 38: 4016d693 srai x13,x13,0x1
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[13] == -2) $display("Test 14 passed");
    else $display("Test 14 FAILED");

    // 3c: 00c68733 add x14,x13,x12
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[14] == -1) $display("Test 15 passed");
    else $display("Test 15 FAILED");

    // 40: 40c70733 sub x14,x14,x12
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[14] == -2) $display("Test 16 passed");
    else $display("Test 16 FAILED");

    // 44: 00c617b3 sll x15,x12,x12
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[15] == 2) $display("Test 17 passed");
    else $display("Test 17 FAILED");

    // 48: 00f62833 slt x16,x12,x15
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[16] == 1) $display("Test 18 passed");
    else $display("Test 18 FAILED");

    // 4c: 00c62833 slt x16,x12,x12
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[16] == 0) $display("Test 19 passed");
    else $display("Test 19 FAILED");

    // 50: 00d83833 sltu x16,x16,x13
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[16] == 1) $display("Test 20 passed");
    else $display("Test 20 FAILED");

    // 54: 00d84833 xor x17,x16,x13
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[17] == -1) $display("Test 21 passed");
    else $display("Test 21 FAILED");

    // 58: 0105d933 srl x18,x11,x16
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[18] == 1) $display("Test 22 passed");
    else $display("Test 22 FAILED");

    // 5c: 4108d933 sra x18,x17,x16
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[18] == -1) $display("Test 23 passed");
    else $display("Test 23 FAILED");

    // 60: 00b869b3 or x19,x16,x11
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[19] == 3) $display("Test 24 passed");
    else $display("Test 24 FAILED");

    // 64: 0109f9b3 and x19,x19,x16
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[19] == 1) $display("Test 25 passed");
    else $display("Test 25 FAILED");

    // 68: 00001a37 lui x20,0x1
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[20] == 32'h0000_1000) $display("Test 26 passed");
    else $display("Test 26 FAILED");

    // 6c: 013a2223 sw x19,4(x20) # [1004] = 0x0000_0001
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;

    // 70: 004a2a83 lw x21,4(x20) # x21 = [1004] = 0x0000_0001
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    if (core.registers.mem[21] == 1) $display("Test 27 passed");
    else $display("Test 27 FAILED");

    // 74: 013a1323 sh x19,6(x20) # [1006] = 0x0001
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;

    // 78: 006a1a83 lh x21,6(x20) # x21 = [1006] = 0x00001
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    if (core.registers.mem[21] == 1) $display("Test 28 passed");
    else $display("Test 28 FAILED");

    // 7c: 013a03a3 sb x19,7(x20) # [1007] = 0x01
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;

    // 80: 007a0a83 lb x21,7(x20) # x21 = [1007] = 0x01
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    if (core.registers.mem[21] == 1) $display("Test 29 passed");
    else $display("Test 29 FAILED");

    // 84: 004a0a83 lb x21,4(x20) # x21 = [1004] = 0x01
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    if (core.registers.mem[21] == 1) $display("Test 30 passed");
    else $display("Test 30 FAILED");

    // 88: 006a1a83 lh sx21,6(x20) # x21 = [1006] = 0x0101
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    if (core.registers.mem[21] == 32'h0000_01_01) $display("Test 31 passed");
    else $display("Test 31 FAILED");

    // 8c: 004a2a83 lw x21,4(x20) # x21 = [1004] = 0x01010001
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    if (core.registers.mem[21] == 32'h0101_0001) $display("Test 32 passed");
    else $display("Test 32 FAILED");

    // 90: 011a2023 sw x17,0(x20) # [1000] = 0xffff_ffff
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;

    // 94: 000a4a83 lbu x21,0(x20) # x21 = [1000] = 0xff
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    if (core.registers.mem[21] == 32'h0000_00ff) $display("Test 33 passed");
    else $display("Test 33 FAILED");

    // 98: 002a5a83 lhu x21,2(x20) # x21 = [1000] = 0xffff
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    if (core.registers.mem[21] == 32'h0000_ffff) $display("Test 34 passed");
    else $display("Test 34 FAILED");

    // 9c: 001a8b13 addi x22,x21,1 # x22 = 0xffff + 1 = 0x1_0000
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;
    if (core.registers.mem[22] == 32'h0001_0000) $display("Test 35 passed");
    else $display("Test 35 FAILED");

    // a0: 360000ef jal x1,400 <lbl_jal>
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;
    if (core.pc == 32'h0000_0400) $display("Test 36 passed");
    else $display("Test 36 FAILED");

    // 400: 00008067 jalr x0,0(x1)
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;
    if (core.pc == 32'h0000_00a4) $display("Test 37 passed");
    else $display("Test 37 FAILED");

    // a4: 376b0263  beq x22,x22,408 <lbl_beq> # # x22 == x22 -> branch taken
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;
    if (core.pc == 32'h0000_0408) $display("Test 38 passed");
    else $display("Test 38 FAILED");

    // 408: ca1ff06f jal x0,a8 <lbl1>
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;
    if (core.pc == 32'h0000_00a8) $display("Test 39 passed");
    else $display("Test 39 FAILED");

    // a8: 375b1463 bne x22,x21,410 <lbl_bne> # 0x1_0000 != 0xffff -> branch taken
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;
    if (core.pc == 32'h0000_0410) $display("Test 40 passed");
    else $display("Test 40 FAILED");

    // 410: c9dff06f jal x0,ac <lbl2>
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;
    if (core.pc == 32'h0000_00ac) $display("Test 41 passed");
    else $display("Test 41 FAILED");

    // ac: 376ac663 blt x21,x22,418 <lbl_blt> # 0xffff < 0x1_0000 -> branch taken
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;
    if (core.pc == 32'h0000_0418) $display("Test 42 passed");
    else $display("Test 42 FAILED");

    // 418: c99ff06f jal x0,b0 <lbl3>
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;
    if (core.pc == 32'h0000_00b0) $display("Test 43 passed");
    else $display("Test 43 FAILED");

    // b0: 375b5863 bge x22,x21,420 <lbl_bge> # 0x1_0000 >= 0xffff -> branch taken
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;
    if (core.pc == 32'h0000_0420) $display("Test 44 passed");
    else $display("Test 44 FAILED");

    // 420: c95ff06f jal x0,b4 <lbl4> 
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;
    if (core.pc == 32'h0000_00b4) $display("Test 45 passed");
    else $display("Test 45 FAILED");

    // b4: 3729ea63 bltu x19,x18,428 <lbl_bltu> # 1 < 0xffff_ffff -> branch taken
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;
    if (core.pc == 32'h0000_0428) $display("Test 46 passed");
    else $display("Test 46 FAILED");

    // 428: c91ff06f jal x0,b8 <lbl5>
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;
    if (core.pc == 32'h0000_00b8) $display("Test 47 passed");
    else $display("Test 47 FAILED");

    // b8: 37397c63 bgeu x18,x19,430 <lbl_bgeu> # 0xffff_ffff > 1 -> branch taken
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;
    if (core.pc == 32'h0000_0430) $display("Test 48 passed");
    else $display("Test 48 FAILED");

    // 430: c8dff06f jal x0,bc <lbl6>
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;
    if (core.pc == 32'h0000_00bc) $display("Test 49 passed");
    else $display("Test 49 FAILED");

    // bc: 355b0663 beq x22,x21,408 <lbl_beq> # 0x1_0000 != 0xffff -> branch not taken 
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;
    if (core.pc == 32'h0000_00c0) $display("Test 50 passed");
    else $display("Test 50 FAILED");

    // c0: 355a9463 bne x21,x21,408 <lbl_beq> # 0xffff == 0xffff -> branch not taken
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;
    if (core.pc == 32'h0000_00c4) $display("Test 51 passed");
    else $display("Test 51 FAILED");

    // c4: 355b4a63 blt x22,x21,418 <lbl_blt> # 0x1_0000 > 0xffff -> branch not taken
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;
    if (core.pc == 32'h0000_00c8) $display("Test 52 passed");
    else $display("Test 52 FAILED");

    // c8: 356adc63 bge x21,x22,420 <lbl_bge> # 0xffff < 0x1_0000 -> branch not taken
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;
    if (core.pc == 32'h0000_00cc) $display("Test 53 passed");
    else $display("Test 53 FAILED");

    // cc: 35396e63 bltu x18,x19,428 <lbl_bltu> # 0xffff_ffff > 1 -> branch not taken
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;
    if (core.pc == 32'h0000_00d0) $display("Test 54 passed");
    else $display("Test 54 FAILED");

    // d0: 3729f063 bgeu x19,x18,430 <lbl_bgeu> # 1 < 0xffff_ffff -> branch not taken
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;
    if (core.pc == 32'h0000_00d4) $display("Test 55 passed");
    else $display("Test 55 FAILED");

    // d4: 364000ef jal x1,438 <lbl_auipc>
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;
    if (core.pc == 32'h0000_0438) $display("Test 56 passed");
    else $display("Test 56 FAILED");

    // 438: fffff117 auipc x2,0xfffff # 0x0438 + 0xffff_f0000 (-4096) == -3016 = 0xffff_f438
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[2] == 32'hffff_f438) $display("Test 57 passed");
    else $display("Test 57 FAILED");

    // 43c: 00008067 jalr x0,0(x1)
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;
    if (core.pc == 32'h0000_00d8) $display("Test 58 passed");
    else $display("Test 58 FAILED");



























    $finish;

  end

endmodule

`default_nettype wire
