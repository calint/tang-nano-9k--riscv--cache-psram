//
// Registers
//
`timescale 100ps / 100ps
//
`default_nettype none
// `define DBG

module Registers #(
    parameter ADDR_WIDTH = 5,
    parameter WIDTH = 32
) (
    input wire clk,

    input wire [ADDR_WIDTH-1:0] rs1,
    input wire [ADDR_WIDTH-1:0] rs2,
    input wire [ADDR_WIDTH-1:0] rd,

    output wire [WIDTH-1:0] rs1_dat,  // value of register 'ra1'
    output wire [WIDTH-1:0] rs2_dat,  // value of register 'ra2'

    // data to write to register 'rd' when 'rd_we' is enabled
    input wire [WIDTH-1:0] rd_wd,
    input wire rd_we
);

  logic signed [WIDTH-1:0] mem[2**ADDR_WIDTH];

  // register 0 is hardwired to value 0
  assign rs1_dat = rs1 == 0 ? 0 : mem[rs1];
  assign rs2_dat = rs2 == 0 ? 0 : mem[rs2];

  always @(posedge clk) begin
`ifdef DBG
    if (rd_we) begin
      $display("%0t: clk+: Registers (rs1,rs2,rd,we,rd_dat)=(%0h,%0h,%0h,%0d,%0h)", $time, rs1,
               rs2, rd, rd_we, rd_wd);
    end
`endif
    if (rd_we) begin
      mem[rd] <= rd_wd;
    end
  end

endmodule

`undef DBG
`default_nettype wire
