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
    input wire [WIDTH-1:0] rd_wd,  // data to write to register 'rd' when 'rd_we' is enabled
    input wire rd_we,
    output wire [WIDTH-1:0] rd1,  // value of register 'ra1'
    output wire [WIDTH-1:0] rd2  // value of register 'ra2'
);

  reg signed [WIDTH-1:0] mem[0:2**ADDR_WIDTH-1];

  // register 0 is hardwired to value 0
  assign rd1 = rs1 == 0 ? 0 : mem[rs1];
  assign rd2 = rs2 == 0 ? 0 : mem[rs2];

  always @(posedge clk) begin
`ifdef DBG
    if (rd_we) begin
      $display("%0t: clk+: Registers (rs1,rs2,rd,we,rd_dat)=(%0h,%0h,%0h,%0d,%0h)", $time, rs1,
               rs2, rd, rd_we, rd_wd);
    end
`endif
    if (rd_we) mem[rd] <= rd_wd;
  end

endmodule

`undef DBG
`default_nettype wire
