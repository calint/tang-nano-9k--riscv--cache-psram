//
// cache + burst_ram
//
`timescale 1ns / 1ps
//
`default_nettype none

module testbench;

  localparam int unsigned RAM_ADDRESS_BIT_WIDTH = 10;

  logic rst_n;
  logic clk = 1;
  localparam int unsigned clk_tk = 36;
  always #(clk_tk / 2) clk = ~clk;

  // wires between burst_ram and cache
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
      .AddressBitWidth(RAM_ADDRESS_BIT_WIDTH),  // 2 ^ 4 * 8 B entries
      .BurstDataCount(4),  // 4 * 64 bit data per burst
      .CyclesBeforeDataValid(6)
  ) burst_ram (
      .clk,
      .rst_n(rst_n),
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

  logic [31:0] address;
  logic [31:0] address_next;
  wire [31:0] data_out;
  wire data_out_ready;
  logic [31:0] data_in;
  logic [3:0] write_enable;
  wire busy;
  logic enable;

  cache #(
      .LineIndexBitWidth(2),
      .RamAddressBitWidth(RAM_ADDRESS_BIT_WIDTH),
      .RamAddressingMode(3)  // 64 bit words
  ) cache (
      .clk(clk),
      .rst_n(rst_n && br_init_calib),
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
    $dumpvars(0, testbench);

    rst_n <= 0;
    #clk_tk;
    rst_n <= 1;
    #clk_tk;

    // wait for burst RAM to initiate
    while (br_busy) #clk_tk;

    enable <= 1;

    address <= 0;
    address_next <= 0;
    #clk_tk;

    // write
    for (int i = 0; i < 2 ** RAM_ADDRESS_BIT_WIDTH; i = i + 1) begin
      address <= address_next;
      address_next <= address_next + 4;
      data_in = i;
      write_enable <= 4'b1111;
      #clk_tk;
      while (busy) #clk_tk;
    end

    address <= 4;
    write_enable <= 0;
    #clk_tk;
    while (!data_out_ready) #clk_tk;
    assert (data_out == 1)
    else $fatal;

    address <= 8;
    write_enable <= 0;
    #clk_tk;
    while (!data_out_ready) #clk_tk;
    assert (data_out == 2)
    else $fatal;

    address <= 4;
    data_in <= 32'habcd_1234;
    write_enable <= 4'b1111;
    #clk_tk;
    address <= 4;
    write_enable <= 0;
    #clk_tk;
    assert (data_out_ready)
    else $fatal;
    assert (data_out == 32'habcd_1234)
    else $fatal;

    $display("");
    $display("PASSED");
    $display("");
    $finish;
  end

endmodule

`default_nettype wire
