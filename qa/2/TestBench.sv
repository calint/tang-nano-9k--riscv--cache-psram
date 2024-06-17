`timescale 1ns / 1ps
//
// BurstRAM
//
`default_nettype none

module TestBench;
  BurstRAM #(
      .DATA_FILE("RAM.mem"),
      .DEPTH_BITWIDTH(4),
      .DATA_BITWIDTH(64),
      .BURST_COUNT(4),
      .CYCLES_BEFORE_INITIATED(10),
      .CYCLES_BEFORE_DATA_VALID(4)
  ) dut (
      .clk(clk),
      .rst_n(rst_n),
      .cmd(cmd),
      .cmd_en(cmd_en),
      .addr(addr),
      .wr_data(wr_data),
      .data_mask(data_mask),
      .rd_data(rd_data),
      .rd_data_valid(rd_data_valid),
      .busy(busy)
  );
  reg cmd = 0;
  reg cmd_en = 0;
  reg [3:0] addr = 0;
  reg [63:0] wr_data = 0;
  reg [7:0] data_mask = 0;
  wire [63:0] rd_data;
  wire rd_data_valid;
  wire busy;

  localparam clk_tk = 10;
  reg clk = 0;
  always #(clk_tk / 2) clk = ~clk;

  reg rst_n = 0;

  initial begin
    $dumpfile("log.vcd");
    $dumpvars(0, TestBench);

    // reset
    #clk_tk;
    #(clk_tk / 2);
    rst_n <= 1;

    // wait for initiation to complete
    while (busy) #clk_tk;

    // read
    cmd <= 0;
    addr <= 0;
    cmd_en <= 1;
    #clk_tk;
    cmd_en <= 0;
    #clk_tk;

    // delay before burst (DELAY_BEFORE_RD_DATA_AVAILABLE)
    #clk_tk;
    #clk_tk;
    #clk_tk;
    #clk_tk;

    if (rd_data_valid) $display("test 1 passed");
    else $display("test 1 FAILED");

    // first data
    if (rd_data == 64'h3F5A2E14B7C6A980) $display("test 2 passed");
    else $display("test 2 FAILED");

    #clk_tk;

    // second data
    if (rd_data == 64'h9D8E2F17AB4C3E6F) $display("test 3 passed");
    else $display("test 3 FAILED");

    #clk_tk;

    // third data
    if (rd_data == 64'hA1C3F7E2D5B8A9C4) $display("test 4 passed");
    else $display("test 4 FAILED");

    #clk_tk;

    // fourth data
    if (rd_data == 64'h7D4E9F2C1B6A3D8F) $display("test 5 passed");
    else $display("test 5 FAILED");

    #clk_tk;

    if (!rd_data_valid) $display("test 6 passed");
    else $display("test 6 FAILED");

    #clk_tk;
    #clk_tk;
    #clk_tk;
    #clk_tk;

    // read
    cmd_en <= 1;
    cmd <= 0;
    addr <= 32 / 8;  // 8 bytes words
    #clk_tk;
    cmd_en <= 0;
    #clk_tk;

    // delay before burst (DELAY_BEFORE_RD_DATA_AVAILABLE)
    #clk_tk;
    #clk_tk;
    #clk_tk;
    #clk_tk;

    if (rd_data_valid) $display("test 7 passed");
    else $display("test 7 FAILED");

    // first data
    if (rd_data == 64'h6C4B9A8D2F5E3C7A) $display("test 8 passed");
    else $display("test 8 FAILED");

    #clk_tk;

    // second data
    if (rd_data == 64'hE1A7D0B5C8F3E6A9) $display("test 9 passed");
    else $display("test 9 FAILED");

    #clk_tk;

    // third data
    if (rd_data == 64'hF8E9D2C3B4A5F6E7) $display("test 10 passed");
    else $display("test 10 FAILED");

    #clk_tk;

    // fourth data
    if (rd_data == 64'hD4E7F2C5B8A3D6E9) $display("test 11 passed");
    else $display("test 11 FAILED");

    #clk_tk;

    if (!rd_data_valid) $display("test 12 passed");
    else $display("test 12 FAILED");

    #clk_tk;
    #clk_tk;
    #clk_tk;
    #clk_tk;

    $finish;
  end

endmodule
