`timescale 100ps / 100ps
//
// Cache + BurstRAM
//
`default_nettype none

module TestBench;

  localparam RAM_DEPTH_BITWIDTH = 10;

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
  wire [RAM_DEPTH_BITWIDTH-1:0] br_addr;
  wire [63:0] br_wr_data;
  wire [7:0] br_data_mask;
  wire [63:0] br_rd_data;
  wire br_rd_data_valid;
  wire br_init_calib;
  wire br_busy;

  BurstRAM #(
      .DATA_FILE(""),  // initial RAM content
      .DEPTH_BITWIDTH(RAM_DEPTH_BITWIDTH),  // 2 ^ 4 * 8 B entries
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
  reg [31:0] address_next;
  wire [31:0] data_out;
  wire data_out_ready;
  reg [31:0] data_in;
  reg [3:0] write_enable;
  wire busy;
  reg enable;

  Cache #(
      .LINE_IX_BITWIDTH(2),
      .RAM_DEPTH_BITWIDTH(RAM_DEPTH_BITWIDTH),
      .RAM_ADDRESSING_MODE(3)  // 64 bit words
  ) cache (
      .clk(clkout),
      .rst_n(sys_rst_n && lock && br_init_calib),
      .enable(enable),
      .address(address),
      .data_out(data_out),
      .data_out_ready(data_out_ready),
      .data_in(data_in),
      .write_enable(write_enable),
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

    enable <= 1;

    address <= 0;
    address_next <= 0;
    #clk_tk;

    // write
    for (int i = 0; i < 2 ** RAM_DEPTH_BITWIDTH; i = i + 1) begin
      // $display("address: %h", address);
      address <= address_next;
      address_next <= address_next + 4;
      data_in = i;
      write_enable <= 4'b1111;
      #clk_tk;
      while (busy) #clk_tk;
    end

    // for (int i = 0; i < 16; i = i + 1) begin
    //   $display("%h: %h", i, burst_ram.data[i]);
    // end

    address <= 4;
    write_enable <= 0;
    #clk_tk;
    while (!data_out_ready) #clk_tk;
    if (data_out == 1) $display("Test 1 passed");
    else $display("Test 1 FAILED");

    address <= 8;
    write_enable <= 0;
    #clk_tk;
    while (!data_out_ready) #clk_tk;
    if (data_out == 2) $display("Test 2 passed");
    else $display("Test 2 FAILED");

    address <= 4;
    data_in <= 32'habcd_1234;
    write_enable <= 4'b1111;
    #clk_tk;
    address <= 4;
    write_enable <= 0;
    #clk_tk;
    if (data_out_ready) $display("Test 3 passed");
    else $display("Test 3 FAILED");
    if (data_out == 32'habcd_1234) $display("Test 4 passed");
    else $display("Test 4 FAILED");


    $finish;
  end

endmodule

`default_nettype wire
