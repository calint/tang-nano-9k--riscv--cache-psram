//
// Registers
//
// reviewed 2024-06-24
//
`timescale 1ns / 1ps
//
`default_nettype none
// `define DBG

module registers #(
    parameter int unsigned AddressBitwidth = 5,
    parameter int unsigned DataBitwidth = 32
) (
    input wire clk,

    input wire [AddressBitwidth-1:0] rs1,
    // source register 1

    output logic [DataBitwidth-1:0] rs1_data_out,
    // data of register 'rs1'

    input wire [AddressBitwidth-1:0] rs2,
    // source register 2

    output logic [DataBitwidth-1:0] rs2_data_out,
    // data of register 'rs2'

    input wire [AddressBitwidth-1:0] rd,
    // destination register

    input wire rd_write_enable,
    // write enable destination register

    input wire [DataBitwidth-1:0] rd_data_in
    // data to write to register 'rd' when 'rd_write_enable' is enabled
);

  logic [DataBitwidth-1:0] data[2**AddressBitwidth];

  // note: register 0 is hardwired to value 0
  assign rs1_data_out = rs1 == 0 ? 0 : data[rs1];
  assign rs2_data_out = rs2 == 0 ? 0 : data[rs2];

  always_ff @(posedge clk) begin
    if (rd_write_enable) begin
`ifdef DBG
      $display("%m: %0t: clk+: Registers (rs1,rs2,rd,we,rd_dat)=(%0h,%0h,%0h,%0d,%0h)", $time, rs1,
               rs2, rd, rd_write_enable, rd_data_in);
`endif
      data[rd] <= rd_data_in;
    end
  end

endmodule

`undef DBG
`default_nettype wire
