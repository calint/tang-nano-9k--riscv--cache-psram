//
// cache + burst_ram
//
`timescale 100ps / 100ps
//
`default_nettype none

module testbench;

  localparam int unsigned RAM_ADDRESS_BIT_WIDTH = 4;

  logic rst_n;
  logic clk = 1;
  localparam int unsigned clk_tk = 36;
  always #(clk_tk / 2) clk = ~clk;

  wire clkin = clk;
  wire clkout = clk;
  wire lock = 1;

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
      .DataFilePath("ram.mem"),  // initial RAM content
      .AddressBitWidth(RAM_ADDRESS_BIT_WIDTH),  // 2 ^ 4 * 8 B entries
      .BurstDataCount(4),  // 4 * 64 bit data per burst
      .CyclesBeforeDataValid(6)
  ) burst_ram (
      .clk(clkout),
      .rst_n(rst_n && lock),
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
  logic [31:0] data_out;
  logic data_out_ready;
  logic [31:0] data_in;
  logic [3:0] write_enable;
  logic busy;
  logic enable;

  cache #(
      .LineIndexBitWidth(1),
      .RamAddressBitWidth(RAM_ADDRESS_BIT_WIDTH),
      .RamAddressingMode(3)  // 64 bit words
  ) cache (
      .clk  (clkout),
      .rst_n(rst_n && lock && br_init_calib),

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
    $dumpvars(0, testbench);

    rst_n <= 0;
    #clk_tk;
    rst_n <= 1;

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

    assert (data_out == 32'hD5B8A9C4)
    else $error();

    // read address 8; cache hit; one cycle delay
    while (busy) #clk_tk;
    address <= 8;
    write_enable <= 0;
    #clk_tk;

    assert (data_out == 32'hAB4C3E6F && data_out_ready)
    else $error();

    // read; cache miss, invalid line
    while (busy) #clk_tk;
    address <= 32;
    write_enable <= 0;
    #clk_tk;

    assert (!data_out_ready)
    else $error();

    while (!data_out_ready) #clk_tk;

    assert (data_out == 32'h2F5E3C7A && data_out_ready)
    else $error();

    // read; cache hit valid
    while (busy) #clk_tk;
    address <= 12;
    write_enable <= 0;
    #clk_tk;

    assert (data_out == 32'h9D8E2F17 && data_out_ready)
    else $error();

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

    assert (data_out == 32'hAB4C3Ead && data_out_ready)
    else $error();

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

    assert (data_out == 32'hAB4C8765 && data_out_ready)
    else $error();

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

    assert (data_out == 32'hfeef8765 && data_out_ready)
    else $error();

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

    assert (data_out == 32'habcdef12 && data_out_ready)
    else $error();

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

    assert (data_out == 32'h1b2d3f42 && data_out_ready)
    else $error();

    while (busy) #clk_tk;
    address <= 0;
    data_in <= 32'h31323334;
    write_enable <= 4'b1111;
    #clk_tk;

    assert (busy)
    else $error();

    while (busy) #clk_tk;
    address <= 8;
    write_enable <= 0;
    #clk_tk;

    assert (data_out_ready)
    else $error();

    assert (data_out == 32'hfeef8765 && data_out_ready)
    else $error();

    // read last element in the cache line
    while (busy) #clk_tk;
    address <= 32 - 4;
    write_enable <= 0;
    #clk_tk;

    assert (data_out_ready)
    else $error();

    assert (data_out == 32'h7D4E9F2C && data_out_ready)
    else $error();

    #clk_tk;
    #clk_tk;
    #clk_tk;
    #clk_tk;

    $finish;
  end

endmodule

`default_nettype wire
