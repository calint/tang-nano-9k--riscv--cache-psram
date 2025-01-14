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
    parameter int unsigned AddressBitWidth = 16,
    parameter int unsigned DataBitWidth = 32,
    parameter int unsigned ColumnBitWidth = 8
) (
    input wire rst_n,
    input wire clk,

    input wire [ColumnCount-1:0] write_enable,
    input wire [AddressBitWidth-1:0] address,
    output logic [DataBitWidth-1:0] data_out,
    input wire [DataBitWidth-1:0] data_in
);

  localparam int unsigned ColumnCount = DataBitWidth / ColumnBitWidth;

  logic [DataBitWidth-1:0] data[2**AddressBitWidth];

  assign data_out = data[address];

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      for (int i = 0; i < 2 ** AddressBitWidth; i++) begin
        data[i] <= 0;
      end
    end else begin
      for (int i = 0; i < ColumnCount; i++) begin
        if (write_enable[i]) begin
          data[address][(i+1)*ColumnBitWidth-1-:ColumnBitWidth] <= data_in[(i+1)*ColumnBitWidth-1-:ColumnBitWidth];
        end
      end
    end
  end

endmodule

`undef DBG
`undef INFO
`default_nettype wire
