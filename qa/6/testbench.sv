//
// core + ramio + burst_ram + flash
//
`timescale 100ps / 100ps
//
`default_nettype none

module testbench;
  logic rst_n;
  logic clk = 1;
  localparam int unsigned clk_tk = 36;
  always #(clk_tk / 2) clk = ~clk;

  localparam int unsigned RAM_ADDRESS_BIT_WIDTH = 10;  // 2^10 * 8 B = 8192 B

  logic [5:0] led;
  logic uart_tx;
  logic uart_rx;

  //------------------------------------------------------------------------
  logic br_cmd;
  logic br_cmd_en;
  logic [RAM_ADDRESS_BIT_WIDTH-1:0] br_addr;
  logic [63:0] br_wr_data;
  logic [7:0] br_data_mask;
  logic [63:0] br_rd_data;
  logic br_rd_data_valid;
  logic br_init_calib;
  logic br_busy;

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
  logic ramio_enable;
  logic [1:0] ramio_write_type;
  logic [2:0] ramio_read_type;
  logic [31:0] ramio_address;
  logic [31:0] ramio_data_out;
  logic ramio_data_out_ready;
  logic [31:0] ramio_data_in;
  logic ramio_busy;

  ramio #(
      .RamAddressBitWidth(RAM_ADDRESS_BIT_WIDTH),
      .RamAddressingMode(3),  // 64 bit word RAM
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
  logic flash_clk;
  logic flash_miso;
  logic flash_mosi;
  logic flash_cs;

  flash #(
      .DataFilePath("ram.mem"),
      .AddressBitWidth(12)  // in bytes 2^12 = 4096 B
  ) flash (
      .rst_n,
      .clk (flash_clk),
      .miso(flash_miso),
      .mosi(flash_mosi),
      .cs  (flash_cs)
  );

  //------------------------------------------------------------------------
  core #(
      .StartupWaitCycles (0),
      .FlashTransferBytes(4096)
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
      .flash_cs
  );
  //------------------------------------------------------------------------
  assign led[5] = ~ramio_busy;
  //------------------------------------------------------------------------
  initial begin
    $dumpfile("log.vcd");
    $dumpvars(0, testbench);

    rst_n <= 0;
    #clk_tk;
    rst_n <= 1;
    #clk_tk;

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
    else $error();

    // 8: 67850513 addi x10,x10,1656 # 12345678
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[10] == 32'h1234_5678)
    else $error();

    // c: 00300593 addi x11,x0,3
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[11] == 32'h3)
    else $error();

    // 10: 0045a613 slti x12,x11,4
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[12] == 32'h1)
    else $error();

    // 14: fff5a613 slti x12,x11,-1
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[12] == 32'h0)
    else $error();

    // 18: 0045b613 sltiu x12,x11,4
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[12] == 32'h1)
    else $error();

    // 1c: fff5b613 sltiu x12,x11,-1
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[12] == 32'h1)
    else $error();

    // 20: fff64693 xori x13,x12,-1
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[13] == 32'hffff_fffe)
    else $error();

    // 24: 0016e693 ori x13,x13,1
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[13] == 32'hffff_ffff)
    else $error();

    // 28: 0026f693 andi x13,x13,2
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[13] == 32'h2)
    else $error();

    // 2c: 00369693 slli x13,x13,0x3
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[13] == 16)
    else $error();

    // 30: 0036d693 srli x13,x13,0x3
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[13] == 2)
    else $error();

    // 34: fff6c693 xori x13,x13,-1
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[13] == -3)
    else $error();

    // 38: 4016d693 srai x13,x13,0x1
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[13] == -2)
    else $error();

    // 3c: 00c68733 add x14,x13,x12
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[14] == -1)
    else $error();

    // 40: 40c70733 sub x14,x14,x12
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[14] == -2)
    else $error();

    // 44: 00c617b3 sll x15,x12,x12
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[15] == 2)
    else $error();

    // 48: 00f62833 slt x16,x12,x15
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[16] == 1)
    else $error();

    // 4c: 00c62833 slt x16,x12,x12
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[16] == 0)
    else $error();

    // 50: 00d83833 sltu x16,x16,x13
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[16] == 1)
    else $error();

    // 54: 00d84833 xor x17,x16,x13
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[17] == -1)
    else $error();

    // 58: 0105d933 srl x18,x11,x16
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[18] == 1)
    else $error();

    // 5c: 4108d933 sra x18,x17,x16
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[18] == -1)
    else $error();

    // 60: 00b869b3 or x19,x16,x11
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[19] == 3)
    else $error();

    // 64: 0109f9b3 and x19,x19,x16
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[19] == 1)
    else $error();

    // 68: 00001a37 lui x20,0x1
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[20] == 32'h0000_1000)
    else $error();

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
    else $error();

    // 74: 013a1323 sh x19,6(x20) # [1006] = 0x0001
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;

    // 78: 006a1a83 lh x21,6(x20) # x21 = [1006] = 0x00001
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.CpuExecute) #clk_tk;
    assert (core.registers.data[21] == 1)
    else $error();

    // 7c: 013a03a3 sb x19,7(x20) # [1007] = 0x01
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;

    // 80: 007a0a83 lb x21,7(x20) # x21 = [1007] = 0x01
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.CpuExecute) #clk_tk;
    assert (core.registers.data[21] == 1)
    else $error();

    // 84: 004a0a83 lb x21,4(x20) # x21 = [1004] = 0x01
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.CpuExecute) #clk_tk;
    assert (core.registers.data[21] == 1)
    else $error();

    // 88: 006a1a83 lh sx21,6(x20) # x21 = [1006] = 0x0101
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.CpuExecute) #clk_tk;
    assert (core.registers.data[21] == 32'h0000_01_01)
    else $error();

    // 8c: 004a2a83 lw x21,4(x20) # x21 = [1004] = 0x01010001
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.CpuExecute) #clk_tk;
    assert (core.registers.data[21] == 32'h0101_0001)
    else $error();

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
    else $error();

    // 98: 002a5a83 lhu x21,2(x20) # x21 = [1000] = 0xffff
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.CpuExecute) #clk_tk;
    assert (core.registers.data[21] == 32'h0000_ffff)
    else $error();

    // 9c: 001a8b13 addi x22,x21,1 # x22 = 0xffff + 1 = 0x1_0000
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.registers.data[22] == 32'h0001_0000)
    else $error();

    // a0: 360000ef jal x1,400 <lbl_jal>
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_0400)
    else $error();

    // 400: 00008067 jalr x0,0(x1)
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00a4)
    else $error();

    // a4: 376b0263  beq x22,x22,408 <lbl_beq> # # x22 == x22 -> branch taken
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_0408)
    else $error();

    // 408: ca1ff06f jal x0,a8 <lbl1>
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00a8)
    else $error();

    // a8: 375b1463 bne x22,x21,410 <lbl_bne> # 0x1_0000 != 0xffff -> branch taken
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_0410)
    else $error();

    // 410: c9dff06f jal x0,ac <lbl2>
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00ac)
    else $error();

    // ac: 376ac663 blt x21,x22,418 <lbl_blt> # 0xffff < 0x1_0000 -> branch taken
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_0418)
    else $error();

    // 418: c99ff06f jal x0,b0 <lbl3>
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00b0)
    else $error();

    // b0: 375b5863 bge x22,x21,420 <lbl_bge> # 0x1_0000 >= 0xffff -> branch taken
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_0420)
    else $error();

    // 420: c95ff06f jal x0,b4 <lbl4> 
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00b4)
    else $error();

    // b4: 3729ea63 bltu x19,x18,428 <lbl_bltu> # 1 < 0xffff_ffff -> branch taken
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_0428)
    else $error();

    // 428: c91ff06f jal x0,b8 <lbl5>
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00b8)
    else $error();

    // b8: 37397c63 bgeu x18,x19,430 <lbl_bgeu> # 0xffff_ffff > 1 -> branch taken
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_0430)
    else $error();

    // 430: c8dff06f jal x0,bc <lbl6>
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00bc)
    else $error();

    // bc: 355b0663 beq x22,x21,408 <lbl_beq> # 0x1_0000 != 0xffff -> branch not taken 
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00c0)
    else $error();

    // c0: 355a9463 bne x21,x21,408 <lbl_beq> # 0xffff == 0xffff -> branch not taken
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00c4)
    else $error();

    // c4: 355b4a63 blt x22,x21,418 <lbl_blt> # 0x1_0000 > 0xffff -> branch not taken
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00c8)
    else $error();

    // c8: 356adc63 bge x21,x22,420 <lbl_bge> # 0xffff < 0x1_0000 -> branch not taken
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00cc)
    else $error();

    // cc: 35396e63 bltu x18,x19,428 <lbl_bltu> # 0xffff_ffff > 1 -> branch not taken
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00d0)
    else $error();

    // d0: 3729f063 bgeu x19,x18,430 <lbl_bgeu> # 1 < 0xffff_ffff -> branch not taken
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00d4)
    else $error();

    // d4: 364000ef jal x1,438 <lbl_auipc>
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_0438)
    else $error();

    // 438: fffff117 auipc x2,0xfffff # 0x0438 + 0xffff_f0000 (-4096) == -3016 = 0xffff_f438
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[2] == 32'hffff_f438)
    else $error();

    // 43c: 00008067 jalr x0,0(x1)
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;
    assert (core.pc == 32'h0000_00d8)
    else $error();

    $finish;

  end

endmodule

`default_nettype wire
