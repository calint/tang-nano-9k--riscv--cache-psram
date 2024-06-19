`timescale 100ps / 100ps
//
`default_nettype none

module TestBench;

  reg rst_n = 0;
  reg clk = 1;
  localparam clk_tk = 36;
  always #(clk_tk / 2) clk = ~clk;

  reg  [31:0] address;
  wire [31:0] data_out;

  Device dut (
      .clk(clk),
      .rst_n(rst_n),
      .address(address),
      .data_out(data_out)
  );

  initial begin
    $dumpfile("log.vcd");
    $dumpvars(0, TestBench);

    #clk_tk;
    rst_n <= 1;
  
    address <= 1;
    #clk_tk;
    address <= 4'hf;
    #clk_tk;
    address <= 1;
    #clk_tk;
    address <= 4'hf;
    #clk_tk;
    #clk_tk;

    $finish;

  end

endmodule

`default_nettype wire
