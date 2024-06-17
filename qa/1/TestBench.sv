`timescale 100ps / 100ps
//
// Cache + BurstRAM
//
`default_nettype none

module TestBench;

  localparam BURST_RAM_DEPTH_BITWIDTH = 4;

  reg sys_rst_n = 0;
  reg clk = 1;
  localparam clk_tk = 36;
  always #(clk_tk / 2) clk = ~clk;

  wire clkin = clk;
  wire clkout = clk;
  wire clkoutp;
  wire lock = 1;

  // Gowin_rPLL rpll (
  //     .clkout(clkout),  //output clkout 54 MHz
  //     .lock(lock),  //output lock
  //     .clkoutp(clkoutp),  //output clkoutp 54 MHz phased 90 degress
  //     .clkin(clkin)  //input clkin 27 MHz
  // );

  wire br_cmd;
  wire br_cmd_en;
  wire [BURST_RAM_DEPTH_BITWIDTH-1:0] br_addr;
  wire [63:0] br_wr_data;
  wire [7:0] br_data_mask;
  wire [63:0] br_rd_data;
  wire br_rd_data_valid;
  wire br_init_calib;
  wire br_busy;

  BurstRAM #(
      .DATA_FILE("RAM.mem"),  // initial RAM content
      .DEPTH_BITWIDTH(BURST_RAM_DEPTH_BITWIDTH),  // 2 ^ 4 * 8 B entries
      .BURST_COUNT(4),  // 4 * 64 bit data per burst
      .CYCLES_BEFORE_DATA_VALID(6)
  ) burst_ram (
      .clk(clkout),
      .rst_n(sys_rst_n && lock),
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

  reg [31:0] address;
  wire [31:0] data_out;
  wire data_out_ready;
  reg [31:0] data_in;
  reg [3:0] write_enable;
  wire busy;
  reg enable;

  Cache #(
      .LINE_IX_BITWIDTH(1),
      .RAM_DEPTH_BITWIDTH(BURST_RAM_DEPTH_BITWIDTH),
      .RAM_ADDRESSING_MODE(3)  // 64 bit words
  ) cache (
      .clk  (clkout),
      .rst_n(sys_rst_n && lock && br_init_calib),

      .enable(enable),
      .write_enable(write_enable),
      .address(address),
      .data_out(data_out),
      .data_out_ready(data_out_ready),
      .data_in(data_in),
      .busy(busy),

      // burst ram wiring; prefix 'br_'
      .br_cmd(br_cmd),
      .br_cmd_en(br_cmd_en),
      .br_addr(br_addr),
      .br_wr_data(br_wr_data),
      .br_data_mask(br_data_mask),
      .br_rd_data(br_rd_data),
      .br_rd_data_valid(br_rd_data_valid)
  );

  initial begin
    $dumpfile("log.vcd");
    $dumpvars(0, TestBench);

    #clk_tk;
    sys_rst_n <= 1;

    // wait for burst RAM to initiate
    while (br_busy || !lock) #clk_tk;

    // keep enabled
    enable <= 1;

    // read; cache miss
    while (busy) #clk_tk;
    address <= 16;
    write_enable <= 0;
    #clk_tk;

    while (!data_out_ready) #clk_tk;

    if (data_out == 32'hD5B8A9C4) $display("Test 1 passed");
    else $display("Test 1 FAILED");

    // read address 8; cache hit; one cycle delay
    while (busy) #clk_tk;
    address <= 8;
    write_enable <= 0;
    #clk_tk;

    if (data_out == 32'hAB4C3E6F && data_out_ready) $display("Test 2 passed");
    else $display("Test 2 FAILED");

    // read; cache miss, invalid line
    while (busy) #clk_tk;
    address <= 32;
    write_enable <= 0;
    #clk_tk;

    if (!data_out_ready) $display("Test 3 passed");
    else $display("Test 3 FAILED");

    while (!data_out_ready) #clk_tk;

    if (data_out == 32'h2F5E3C7A && data_out_ready) $display("Test 4 passed");
    else $display("Test 4 FAILED");

    // read; cache hit valid
    while (busy) #clk_tk;
    address <= 12;
    write_enable <= 0;
    #clk_tk;

    if (data_out == 32'h9D8E2F17 && data_out_ready) $display("Test 5 passed");
    else $display("Test 5 FAILED");

    // write byte; cache hit
    while (busy) #clk_tk;
    address <= 8;
    data_in <= 32'h0000_00ad;
    write_enable <= 4'b0001;
    #clk_tk;

    // read; cache hit valid
    while (busy) #clk_tk;
    address <= 8;
    write_enable <= 0;
    #clk_tk;

    if (data_out == 32'hAB4C3Ead && data_out_ready) $display("Test 6 passed");
    else $display("Test 6 FAILED");

    // write half-word
    while (busy) #clk_tk;
    address <= 8;
    data_in <= 32'h00008765;
    write_enable <= 4'b0011;
    #clk_tk;

    // read it back
    while (busy) #clk_tk;
    address <= 8;
    write_enable <= 0;
    #clk_tk;

    if (data_out == 32'hAB4C8765 && data_out_ready) $display("Test 8 passed");
    else $display("Test 8 FAILED");

    // write upper half-word
    while (busy) #clk_tk;
    address <= 8;
    data_in <= 32'hfeef0000;
    write_enable <= 4'b1100;
    #clk_tk;

    // read it back
    while (busy) #clk_tk;
    address <= 8;
    write_enable <= 0;
    #clk_tk;

    if (data_out == 32'hfeef8765 && data_out_ready) $display("Test 9 passed");
    else $display("Test 9 FAILED");

    // write word; cache miss; evict then write
    while (busy) #clk_tk;
    address <= 64;
    data_in <= 32'habcdef12;
    write_enable <= 4'b1111;
    #clk_tk;

    // read it back
    while (busy) #clk_tk;
    address <= 64;
    write_enable <= 0;
    #clk_tk;

    if (data_out == 32'habcdef12 && data_out_ready) $display("Test 10 passed");
    else $display("Test 10 FAILED");

    // write word; cache hit
    while (busy) #clk_tk;
    address <= 64;
    data_in <= 32'h1b2d3f42;
    write_enable <= 4'b1111;
    #clk_tk;

    // read it back; cache hit
    while (busy) #clk_tk;
    address <= 64;
    write_enable <= 0;
    #clk_tk;

    if (data_out == 32'h1b2d3f42 && data_out_ready) $display("Test 11 passed");
    else $display("Test 11 FAILED");

    while (busy) #clk_tk;
    address <= 0;
    data_in <= 32'h31323334;
    write_enable <= 4'b1111;
    #clk_tk;

    if (busy) $display("Test 12 passed");
    else $display("Test 12 FAILED");

    while (busy) #clk_tk;
    address <= 8;
    write_enable <= 0;
    #clk_tk;

    if (data_out_ready) $display("Test 13 passed");
    else $display("Test 13 FAILED");

    if (data_out == 32'hfeef8765 && data_out_ready) $display("Test 9 passed");
    else $display("Test 9 FAILED");

    // read last element in the cache line
    while (busy) #clk_tk;
    address <= 32 - 4;
    write_enable <= 0;
    #clk_tk;

    if (data_out_ready) $display("Test 14 passed");
    else $display("Test 14 FAILED");

    if (data_out == 32'h7D4E9F2C && data_out_ready) $display("Test 15 passed");
    else $display("Test 15 FAILED");

    #clk_tk;
    #clk_tk;
    #clk_tk;
    #clk_tk;

    $finish;
  end

endmodule

`default_nettype wire
