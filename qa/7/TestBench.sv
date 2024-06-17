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

  localparam RAM_DEPTH_BITWIDTH = 11;  // 2^11 * 8 B = 16 KB

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

    // 0:	00010137          	lui	x2,0x10
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[2] == 32'h0001_0000) $display("Test 1 passed");
    else $display("Test 1 FAILED");

    // 4:	004000ef          	jal	x1,8 <run>
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    if (core.pc == 8) $display("Test 2 passed");
    else $display("Test 2 FAILED");

    // 8:	ff010113          	addi	x2,x2,-16 # fff0 <__global_pointer$+0xd75c>
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[2] == 32'h0000_fff0) $display("Test 3 passed");
    else $display("Test 3 FAILED");

    // c:	00112623          	sw	x1,12(x2) # [0xfff0+12] = x1
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;

    // 10:	00812423          	sw	x8,8(x2)  # [0xfff0+8] = x8
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;

    // 14:	01010413          	addi	x8,x2,16  # 0xfff0 + 16
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[8] == 32'h0001_0000) $display("Test 4 passed");
    else $display("Test 4 FAILED");

    // 18:	00000513          	addi	x10,x0,0
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[10] == 0) $display("Test 5 passed");
    else $display("Test 5 FAILED");

    // 1c:	00000097          	auipc	x1,0x0
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[1] == 32'h0000_001c) $display("Test 5 passed");
    else $display("Test 5 FAILED");

    // 20:	01c080e7          	jalr	x1,28(x1) # 38 <run+0x30>
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    if (core.pc == 32'h0000_0038) $display("Test 6 passed");
    else $display("Test 6 FAILED");

    // 38:	fd010113          	addi	x2,x2,-48 # 0xffc0
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[2] == 32'h0000_ffc0) $display("Test 8 passed");
    else $display("Test 8 FAILED");

    // 3c:	02812623          	sw	x8,44(x2) #   [0xffec] = 0x1'0000
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;

    // 40:	03010413          	addi	x8,x2,48 # 0xffc0 + 48
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    if (core.registers.mem[8] == 32'h0000_fff0) $display("Test 9 passed");
    else $display("Test 9 FAILED");

    // 44:	fca42e23          	sw	x10,-36(x8) # [0xfff0 - 36] = [0xffcc] = 0
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;

    // 48:	fdc42783          	lw	x15,-36(x8) # x15 = [0xfff0 - 36] = [0xffcc] = 0
    while (core.state != core.STATE_CPU_EXECUTE) #clk_tk;
    #clk_tk;
    #clk_tk;
    while (core.state != core.STATE_CPU_FETCH) #clk_tk;
    if (core.registers.mem[15] == 32'h0000_0000) $display("Test 10 passed");
    else $display("Test 10 FAILED");

    $finish;

  end

endmodule

`default_nettype wire
