//
// flash
//
`timescale 1ns / 1ps
//
`default_nettype none

module testbench;

  logic rst_n;
  logic clk = 1;
  localparam int unsigned clk_tk = 10;
  localparam int unsigned clk_tk_half = clk_tk / 2;
  always #(clk_tk_half) clk = ~clk;

  //------------------------------------------------------------------------
  // flash
  //------------------------------------------------------------------------

  logic flash_clk;
  wire  flash_miso;
  logic flash_mosi;
  logic flash_cs_n;

  flash #(
      .DataFilePath("flash.mem"),
      .AddressBitwidth(6)
  ) flash (
      .rst_n,
      .clk (flash_clk),
      .miso(flash_miso),
      .mosi(flash_mosi),
      .cs_n(flash_cs_n)
  );

  //------------------------------------------------------------------------

  logic [7:0] received_byte = 0;

  initial begin
    $dumpfile("log.vcd");
    $dumpvars(0, testbench);

    rst_n <= 0;
    #clk_tk;
    #clk_tk;
    rst_n <= 1;
    #clk_tk;

    flash_cs_n <= 0;

    // send 8 bits command 0x3
    flash_mosi <= 0;  // bit 7
    flash_clk  <= 1;
    #clk_tk_half;
    flash_clk <= 0;
    #clk_tk_half;

    flash_mosi <= 0;  // bit 6
    flash_clk  <= 1;
    #clk_tk_half;
    flash_clk <= 0;
    #clk_tk_half;

    flash_mosi <= 0;  // bit 5
    flash_clk  <= 1;
    #clk_tk_half;
    flash_clk <= 0;
    #clk_tk_half;

    flash_mosi <= 0;  // bit 4
    flash_clk  <= 1;
    #clk_tk_half;
    flash_clk <= 0;
    #clk_tk_half;

    flash_mosi <= 0;  // bit 3
    flash_clk  <= 1;
    #clk_tk_half;
    flash_clk <= 0;
    #clk_tk_half;

    flash_mosi <= 0;  // bit 2
    flash_clk  <= 1;
    #clk_tk_half;
    flash_clk <= 0;
    #clk_tk_half;

    flash_mosi <= 1;  // bit 1
    flash_clk  <= 1;
    #clk_tk_half;
    flash_clk <= 0;
    #clk_tk_half;

    flash_mosi <= 1;  // bit 0
    flash_clk  <= 1;
    #clk_tk_half;
    flash_clk <= 0;
    #clk_tk_half;

    // send adress 0x0
    for (int i = 0; i < 24; i++) begin
      flash_mosi <= 0;
      flash_clk  <= 1;
      #clk_tk_half;
      flash_clk <= 0;
      #clk_tk_half;
    end

    // receive bytes
    for (int i = 0; i < 16; i++) begin
      for (int j = 0; j < 8; j++) begin
        flash_clk <= 0;
        #clk_tk_half;
        // 
        received_byte <= {received_byte[6:0], flash_miso};
        flash_clk <= 1;
        #clk_tk_half;
      end
      assert (flash.data[i] == received_byte)
      else $fatal;
    end

    $display("");
    $display("PASSED");
    $display("");
    $finish;
  end

endmodule

`default_nettype wire
