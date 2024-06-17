//
// synthesizes to Byte Enabled Semi Dual Port Block RAM (BESDPB) in Gowin EDA
//

`timescale 100ps / 100ps
//
`default_nettype none
// `define DBG
// `define INFO

module BESDPB #(
    parameter DATA_FILE = "",
    parameter ADDRESS_BITWIDTH = 16,
    parameter DATA_BITWIDTH = 32,
    parameter COLUMN_BITWIDTH = 8,
    parameter COLUMN_COUNT = DATA_BITWIDTH / COLUMN_BITWIDTH
) (
    input wire clk,
    input wire [COLUMN_COUNT-1:0] write_enable,
    input wire [ADDRESS_BITWIDTH-1:0] address,
    output wire [DATA_BITWIDTH-1:0] data_out,
    input wire [DATA_BITWIDTH-1:0] data_in
);

  reg [DATA_BITWIDTH-1:0] data[2**ADDRESS_BITWIDTH-1:0];

  assign data_out = data[address];

  initial begin
    for (int i = 0; i < 2 ** ADDRESS_BITWIDTH; i++) begin
      data[i] = 0;
    end

    if (DATA_FILE != "") begin
      $readmemh(DATA_FILE, data, 0, 2 ** ADDRESS_BITWIDTH - 1);
    end
  end

  always_ff @(posedge clk) begin
    for (int i = 0; i < COLUMN_COUNT; i++) begin
      if (write_enable[i]) begin
        data[address][(i+1)*COLUMN_BITWIDTH-1-:COLUMN_BITWIDTH] <= data_in[(i+1)*COLUMN_BITWIDTH-1-:COLUMN_BITWIDTH];
      end
    end
  end

endmodule

`undef DBG
`undef INFO
`default_nettype wire
