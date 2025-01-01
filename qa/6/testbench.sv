//
// core + ramio + burst_ram + flash
//
`timescale 1ns / 1ps
//
`default_nettype none

module testbench;

  logic rst_n;
  logic clk = 1;
  localparam int unsigned clk_tk = 10;
  always #(clk_tk / 2) clk = ~clk;

  localparam int unsigned RAM_ADDRESS_BIT_WIDTH = 10;  // 2^10 * 8 B = 8192 B

  wire [5:0] led;
  wire uart_tx;
  wire uart_rx;

  //------------------------------------------------------------------------
  // burst_ram
  //------------------------------------------------------------------------

  // wires between 'burst_ram' and 'cache'
  wire br_cmd;
  wire br_cmd_en;
  wire [RAM_ADDRESS_BIT_WIDTH-1:0] br_addr;
  wire [63:0] br_wr_data;
  wire [7:0] br_data_mask;
  wire [63:0] br_rd_data;
  wire br_rd_data_valid;
  wire br_init_calib;
  wire br_busy;

  burst_ram #(
      .DataFilePath(""),  // initial RAM content
      .AddressBitWidth(RAM_ADDRESS_BIT_WIDTH),  // 2 ^ x * 8 B entries
      .BurstDataCount(4),  // 4 * 64 bit data per burst
      .CyclesBeforeDataValid(6),
      .CyclesBeforeInitiated(0)
  ) burst_ram (
      .clk,
      .rst_n,
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
  // ramio
  //------------------------------------------------------------------------

  // wires between 'ramio' and 'core'
  wire ramio_enable;
  wire [1:0] ramio_write_type;
  wire [2:0] ramio_read_type;
  wire [31:0] ramio_address;
  wire [31:0] ramio_data_out;
  wire ramio_data_out_ready;
  wire [31:0] ramio_data_in;
  wire ramio_busy;

  ramio #(
      .RamAddressBitWidth(RAM_ADDRESS_BIT_WIDTH),
      .RamAddressingMode(3),  // 64 bits word per address in RAM 
      .CacheLineIndexBitWidth(1),
      .ClockFrequencyHz(20_250_000),
      .BaudRate(20_250_000)
  ) ramio (
      .rst_n(rst_n && br_init_calib),
      .clk,
      .enable(ramio_enable),
      .write_type(ramio_write_type),
      .read_type(ramio_read_type),
      .address(ramio_address),
      .data_in(ramio_data_in),
      .data_out(ramio_data_out),
      .data_out_ready(ramio_data_out_ready),
      .busy(ramio_busy),
      .led(led[3:0]),
      .uart_tx,
      .uart_rx,

      // burst RAM wiring; prefix 'br_'
      .br_cmd,  // 0: read, 1: write
      .br_cmd_en,  // 1: cmd and addr is valid
      .br_addr,  // see 'RAM_ADDRESSING_MODE'
      .br_wr_data,  // data to write
      .br_data_mask,  // always 0 meaning write all bytes
      .br_rd_data,  // data out
      .br_rd_data_valid  // rd_data is valid
  );

  //------------------------------------------------------------------------
  // flash
  //------------------------------------------------------------------------

  // wires between 'flash' and 'core'
  wire flash_clk;
  wire flash_miso;
  wire flash_mosi;
  wire flash_cs_n;

  flash #(
      .DataFilePath("ram.mem"),
      .AddressBitWidth(12)  // in bytes 2^12 = 4096 B
  ) flash (
      .rst_n,
      .clk (flash_clk),
      .miso(flash_miso),
      .mosi(flash_mosi),
      .cs_n(flash_cs_n)
  );

  //------------------------------------------------------------------------
  // core
  //------------------------------------------------------------------------

  core #(
      .StartupWaitCycles(0),
      .FlashTransferByteCount(4096)
  ) core (
      .rst_n(rst_n && br_init_calib),
      .clk,
      .led  (led[4]),

      .ramio_enable,
      .ramio_write_type,
      .ramio_read_type,
      .ramio_address,
      .ramio_data_in,
      .ramio_data_out,
      .ramio_data_out_ready,
      .ramio_busy,

      .flash_clk,
      .flash_miso,
      .flash_mosi,
      .flash_cs_n
  );

  //------------------------------------------------------------------------

  assign led[5] = ~ramio_busy;

  //------------------------------------------------------------------------

  initial begin
    $dumpfile("log.vcd");
    $dumpvars(0, testbench);

    rst_n <= 0;
    #clk_tk;
    #clk_tk;
    rst_n <= 1;

    // wait for burst RAM to initiate
    while (br_busy) #clk_tk;

    while (core.state != core.CpuExecute) #clk_tk;

    // 0: 00000013 addi x0,x0,0
    #clk_tk;
    #clk_tk;

    // 4: 12345537 lui x10,0x12345
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[10] == 32'h1234_5000)
    else $fatal;

    // 8: 67850513 addi x10,x10,1656 # 12345678
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[10] == 32'h1234_5678)
    else $fatal;

    // c: 00300593 addi x11,x0,3
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[11] == 32'h3)
    else $fatal;

    // 10: 0045a613 slti x12,x11,4
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[12] == 32'h1)
    else $fatal;

    // 14: fff5a613 slti x12,x11,-1
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[12] == 32'h0)
    else $fatal;

    // 18: 0045b613 sltiu x12,x11,4
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[12] == 32'h1)
    else $fatal;

    // 1c: fff5b613 sltiu x12,x11,-1
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[12] == 32'h1)
    else $fatal;

    // 20: fff64693 xori x13,x12,-1
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[13] == 32'hffff_fffe)
    else $fatal;

    // 24: 0016e693 ori x13,x13,1
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[13] == 32'hffff_ffff)
    else $fatal;

    // 28: 0026f693 andi x13,x13,2
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[13] == 32'h2)
    else $fatal;

    // 2c: 00369693 slli x13,x13,0x3
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[13] == 16)
    else $fatal;

    // 30: 0036d693 srli x13,x13,0x3
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[13] == 2)
    else $fatal;

    // 34: fff6c693 xori x13,x13,-1
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[13] == -3)
    else $fatal;

    // 38: 4016d693 srai x13,x13,0x1
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[13] == -2)
    else $fatal;

    // 3c: 00c68733 add x14,x13,x12
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[14] == -1)
    else $fatal;

    // 40: 40c70733 sub x14,x14,x12
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[14] == -2)
    else $fatal;

    // 44: 00c617b3 sll x15,x12,x12
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[15] == 2)
    else $fatal;

    // 48: 00f62833 slt x16,x12,x15
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[16] == 1)
    else $fatal;

    // 4c: 00c62833 slt x16,x12,x12
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[16] == 0)
    else $fatal;

    // 50: 00d83833 sltu x16,x16,x13
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[16] == 1)
    else $fatal;

    // 54: 00d84833 xor x17,x16,x13
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[17] == -1)
    else $fatal;

    // 58: 0105d933 srl x18,x11,x16
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[18] == 1)
    else $fatal;

    // 5c: 4108d933 sra x18,x17,x16
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[18] == -1)
    else $fatal;

    // 60: 00b869b3 or x19,x16,x11
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[19] == 3)
    else $fatal;

    // 64: 0109f9b3 and x19,x19,x16
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[19] == 1)
    else $fatal;

    // 68: 00001a37 lui x20,0x1
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[20] == 32'h0000_1000)
    else $fatal;

    // 6c: 013a2223 sw x19,4(x20) # [1004] = 0x0000_0001
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;

    // 70: 004a2a83 lw x21,4(x20) # x21 = [1004] = 0x0000_0001
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.CpuExecute) #clk_tk;
    assert (core.registers.data[21] == 1)
    else $fatal;

    // 74: 013a1323 sh x19,6(x20) # [1006] = 0x0001
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.CpuExecute) #clk_tk;

    // 78: 006a1a83 lh x21,6(x20) # x21 = [1006] = 0x00001
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.CpuExecute) #clk_tk;
    assert (core.registers.data[21] == 1)
    else $fatal;

    // 7c: 013a03a3 sb x19,7(x20) # [1007] = 0x01
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.CpuExecute) #clk_tk;

    // 80: 007a0a83 lb x21,7(x20) # x21 = [1007] = 0x01
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.CpuExecute) #clk_tk;
    assert (core.registers.data[21] == 1)
    else $fatal;

    // 84: 004a0a83 lb x21,4(x20) # x21 = [1004] = 0x01
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.CpuExecute) #clk_tk;
    assert (core.registers.data[21] == 1)
    else $fatal;

    // 88: 006a1a83 lh sx21,6(x20) # x21 = [1006] = 0x0101
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.CpuExecute) #clk_tk;
    assert (core.registers.data[21] == 32'h0000_01_01)
    else $fatal;

    // 8c: 004a2a83 lw x21,4(x20) # x21 = [1004] = 0x01010001
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.CpuExecute) #clk_tk;
    assert (core.registers.data[21] == 32'h0101_0001)
    else $fatal;

    // 90: 011a2023 sw x17,0(x20) # [1000] = 0xffff_ffff
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.CpuExecute) #clk_tk;

    // 94: 000a4a83 lbu x21,0(x20) # x21 = [1000] = 0xff
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.CpuExecute) #clk_tk;
    assert (core.registers.data[21] == 32'h0000_00ff)
    else $fatal;

    // 98: 002a5a83 lhu x21,2(x20) # x21 = [1000] = 0xffff
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.CpuExecute) #clk_tk;
    assert (core.registers.data[21] == 32'h0000_ffff)
    else $fatal;

    // 9c: 001a8b13 addi x22,x21,1 # x22 = 0xffff + 1 = 0x1_0000
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.CpuExecute) #clk_tk;
    assert (core.registers.data[22] == 32'h0001_0000)
    else $fatal;

    // a0: 360000ef jal x1,400 <lbl_jal>
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_0400)
    else $fatal;

    // 400: 00008067 jalr x0,0(x1)
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00a4)
    else $fatal;

    // a4: 376b0263  beq x22,x22,408 <lbl_beq> # # x22 == x22 -> branch taken
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_0408)
    else $fatal;

    // 408: ca1ff06f jal x0,a8 <lbl1>
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00a8)
    else $fatal;

    // a8: 375b1463 bne x22,x21,410 <lbl_bne> # 0x1_0000 != 0xffff -> branch taken
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_0410)
    else $fatal;

    // 410: c9dff06f jal x0,ac <lbl2>
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00ac)
    else $fatal;

    // ac: 376ac663 blt x21,x22,418 <lbl_blt> # 0xffff < 0x1_0000 -> branch taken
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_0418)
    else $fatal;

    // 418: c99ff06f jal x0,b0 <lbl3>
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00b0)
    else $fatal;

    // b0: 375b5863 bge x22,x21,420 <lbl_bge> # 0x1_0000 >= 0xffff -> branch taken
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_0420)
    else $fatal;

    // 420: c95ff06f jal x0,b4 <lbl4> 
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00b4)
    else $fatal;

    // b4: 3729ea63 bltu x19,x18,428 <lbl_bltu> # 1 < 0xffff_ffff -> branch taken
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_0428)
    else $fatal;

    // 428: c91ff06f jal x0,b8 <lbl5>
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00b8)
    else $fatal;

    // b8: 37397c63 bgeu x18,x19,430 <lbl_bgeu> # 0xffff_ffff > 1 -> branch taken
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_0430)
    else $fatal;

    // 430: c8dff06f jal x0,bc <lbl6>
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00bc)
    else $fatal;

    // bc: 355b0663 beq x22,x21,408 <lbl_beq> # 0x1_0000 != 0xffff -> branch not taken 
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00c0)
    else $fatal;

    // c0: 355a9463 bne x21,x21,408 <lbl_beq> # 0xffff == 0xffff -> branch not taken
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00c4)
    else $fatal;

    // c4: 355b4a63 blt x22,x21,418 <lbl_blt> # 0x1_0000 > 0xffff -> branch not taken
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00c8)
    else $fatal;

    // c8: 356adc63 bge x21,x22,420 <lbl_bge> # 0xffff < 0x1_0000 -> branch not taken
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00cc)
    else $fatal;

    // cc: 35396e63 bltu x18,x19,428 <lbl_bltu> # 0xffff_ffff > 1 -> branch not taken
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00d0)
    else $fatal;

    // d0: 3729f063 bgeu x19,x18,430 <lbl_bgeu> # 1 < 0xffff_ffff -> branch not taken
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00d4)
    else $fatal;

    // d4: 364000ef jal x1,438 <lbl_auipc>
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_0438)
    else $fatal;

    // 438: fffff117 auipc x2,0xfffff # 0x0438 + 0xffff_f0000 (-4096) == -3016 = 0xffff_f438
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[2] == 32'hffff_f438)
    else $fatal;

    // 43c: 00008067 jalr x0,0(x1)
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00d8)
    else $fatal;

    $display("");
    $display("PASSED");
    $display("");
    $finish;
  end

endmodule

`default_nettype wire
