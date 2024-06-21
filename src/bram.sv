//
// Synthesized to Byte Enabled Semi Dual Port Block RAM by Gowin EDA
//
`timescale 100ps / 100ps
//
`default_nettype none
// `define DBG
// `define INFO

module bram #(
    parameter DataFilePath = "",
    parameter AddressBitWidth = 16,
    parameter DataBitWidth = 32,
    parameter ColumnBitWidth = 8,
    localparam ColumnCount = DataBitWidth / ColumnBitWidth
) (
    input wire clk,

    input wire [ColumnCount-1:0] write_enable,
    input wire [AddressBitWidth-1:0] address,
    output logic [DataBitWidth-1:0] data_out,
    input wire [DataBitWidth-1:0] data_in
);

  logic [DataBitWidth-1:0] data[2**AddressBitWidth];

  assign data_out = data[address];

  initial begin
    for (int i = 0; i < 2 ** AddressBitWidth; i++) begin
      data[i] = 0;
    end

    if (DataFilePath != "") begin
      $readmemh(DataFilePath, data, 0, 2 ** AddressBitWidth - 1);
    end
  end

  always_ff @(posedge clk) begin
    for (int i = 0; i < ColumnCount; i++) begin
      if (write_enable[i]) begin
        data[address][(i+1)*ColumnBitWidth-1-:ColumnBitWidth] <= data_in[(i+1)*ColumnBitWidth-1-:ColumnBitWidth];
      end
    end
  end

endmodule

`undef DBG
`undef INFO
`default_nettype wire
