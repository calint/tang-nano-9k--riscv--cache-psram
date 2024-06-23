`timescale 100ps / 100ps
//
`default_nettype none

module testbench;

  logic rst_n = 0;
  logic clk = 1;
  localparam clk_tk = 36;
  always #(clk_tk / 2) clk = ~clk;

  logic address;
  wire  data_out;

  Device dut (
      .clk,
      .rst_n,
      .address,
      .data_out
  );

  initial begin
    $dumpfile("log.vcd");
    $dumpvars(0, testbench);

    #clk_tk;
    rst_n   <= 1;

    address <= 0;
    #clk_tk;
    address <= 1;
    #clk_tk;
    address <= 0;
    #clk_tk;
    address <= 1;
    #clk_tk;
    #clk_tk;

    $finish;

  end

endmodule

`default_nettype wire
