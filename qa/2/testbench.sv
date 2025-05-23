//
// burst_ram
//
`timescale 1ns / 1ps
//
`default_nettype none

module testbench;

  logic rst_n;
  localparam int unsigned clk_tk = 10;
  logic clk = 0;
  always #(clk_tk / 2) clk = ~clk;

  //------------------------------------------------------------------------
  // burst_ram
  //------------------------------------------------------------------------

  logic cmd = 0;
  logic cmd_en = 0;
  logic [3:0] addr = 0;
  wire [63:0] wr_data = 0;
  logic [7:0] data_mask = 0;
  logic [63:0] rd_data;
  logic rd_data_valid;
  wire busy;

  burst_ram #(
      .DataFilePath("ram.mem"),
      .AddressBitwidth(4),
      .DataBitwidth(64),
      .BurstDataCount(4),
      .CyclesBeforeInitiated(10),
      .CyclesBeforeDataValid(4)
  ) burst_ram (
      .clk,
      .rst_n,
      .cmd,
      .cmd_en,
      .addr,
      .wr_data,
      .data_mask,
      .rd_data,
      .rd_data_valid,
      .busy
  );

  //------------------------------------------------------------------------

  initial begin
    $dumpfile("log.vcd");
    $dumpvars(0, testbench);

    rst_n <= 0;
    #clk_tk;
    #clk_tk;
    rst_n <= 1;
    #clk_tk;

    // wait for initiation to complete
    while (busy) #clk_tk;

    // read
    cmd <= 0;
    addr <= 0;
    cmd_en <= 1;
    #clk_tk;

    // delay before burst (DELAY_BEFORE_RD_DATA_AVAILABLE)
    cmd_en <= 0;
    #clk_tk;
    #clk_tk;
    #clk_tk;
    #clk_tk;

    assert (rd_data_valid)
    else $fatal;

    // first data
    assert (rd_data == 64'h3F5A2E14B7C6A980)
    else $fatal;

    #clk_tk;

    // second data
    assert (rd_data == 64'h9D8E2F17AB4C3E6F)
    else $fatal;

    #clk_tk;

    // third data
    assert (rd_data == 64'hA1C3F7E2D5B8A9C4)
    else $fatal;

    #clk_tk;

    // fourth data
    assert (rd_data == 64'h7D4E9F2C1B6A3D8F)
    else $fatal;

    #clk_tk;

    assert (!rd_data_valid)
    else $fatal;

    #clk_tk;
    #clk_tk;
    #clk_tk;
    #clk_tk;

    // read
    cmd_en <= 1;
    cmd <= 0;
    addr <= 32 / 8;  // 8 bytes words
    #clk_tk;

    // delay before burst (DELAY_BEFORE_RD_DATA_AVAILABLE)
    cmd_en <= 0;
    #clk_tk;
    #clk_tk;
    #clk_tk;
    #clk_tk;

    assert (rd_data_valid)
    else $fatal;

    // first data
    assert (rd_data == 64'h6C4B9A8D2F5E3C7A)
    else $fatal;

    #clk_tk;

    // second data
    assert (rd_data == 64'hE1A7D0B5C8F3E6A9)
    else $fatal;

    #clk_tk;

    // third data
    assert (rd_data == 64'hF8E9D2C3B4A5F6E7)
    else $fatal;

    #clk_tk;

    // fourth data
    assert (rd_data == 64'hD4E7F2C5B8A3D6E9)
    else $fatal;

    #clk_tk;

    assert (!rd_data_valid)
    else $fatal;

    #clk_tk;
    #clk_tk;
    #clk_tk;
    #clk_tk;

    $display("");
    $display("PASSED");
    $display("");
    $finish;
  end

endmodule
