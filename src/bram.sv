//
// Synthesized to Byte Enabled Semi Dual Port Block RAM by Gowin EDA
//
// reviewed 2024-06-24
//
`timescale 1ns / 1ps
//
`default_nettype none
// `define DBG
// `define INFO

module bram #(
    parameter int unsigned AddressBitwidth = 16,
    parameter int unsigned DataBitwidth = 32,
    parameter int unsigned ColumnBitwidth = 8
) (
    input wire clk,

    input wire [ColumnCount-1:0] write_enable,
    input wire [AddressBitwidth-1:0] address,
    output logic [DataBitwidth-1:0] data_out,
    input wire [DataBitwidth-1:0] data_in
);

  localparam int unsigned ColumnCount = DataBitwidth / ColumnBitwidth;

  logic [DataBitwidth-1:0] data[2**AddressBitwidth];

  assign data_out = data[address];

  initial begin
    for (int i = 0; i < 2 ** AddressBitwidth; i++) begin
      data[i] <= 0;
    end
  end

  always_ff @(posedge clk) begin
    for (int i = 0; i < ColumnCount; i++) begin
      if (write_enable[i]) begin
        data[address][(i+1)*ColumnBitwidth-1-:ColumnBitwidth] <= data_in[(i+1)*ColumnBitwidth-1-:ColumnBitwidth];
      end
    end
  end

endmodule

`undef DBG
`undef INFO
`default_nettype wire
