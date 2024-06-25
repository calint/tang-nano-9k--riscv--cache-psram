//
// Registers
//
// reviewed 2024-06-24
//
`timescale 100ps / 100ps
//
`default_nettype none
// `define DBG

module registers #(
    parameter int unsigned AddressBitWidth = 5,
    parameter int unsigned DataBitWidth = 32
) (
    input wire clk,

    // source register 1
    input wire [AddressBitWidth-1:0] rs1,

    // data of register 'rs1'
    output logic [DataBitWidth-1:0] rs1_data_out,

    // source register 2
    input wire [AddressBitWidth-1:0] rs2,

    // data of register 'rs2'
    output logic [DataBitWidth-1:0] rs2_data_out,

    // destination register
    input wire [AddressBitWidth-1:0] rd,

    // write enable destination register
    input wire rd_write_enable,

    // data to write to register 'rd' when 'rd_write_enable' is enabled
    input wire [DataBitWidth-1:0] rd_data_in
);

  logic [DataBitWidth-1:0] data[2**AddressBitWidth];

  // note: register 0 is hardwired to value 0
  assign rs1_data_out = rs1 == 0 ? 0 : data[rs1];
  assign rs2_data_out = rs2 == 0 ? 0 : data[rs2];

  initial begin
    for (int i = 0; i < 2 ** AddressBitWidth; i++) begin
      data[i] = 0;
    end
  end

  always_ff @(posedge clk) begin
`ifdef DBG
    if (rd_write_enable) begin
      $display("%0t: clk+: Registers (rs1,rs2,rd,we,rd_dat)=(%0h,%0h,%0h,%0d,%0h)", $time, rs1,
               rs2, rd, rd_write_enable, rd_data_in);
    end
`endif
    if (rd_write_enable) begin
      data[rd] <= rd_data_in;
    end
  end

endmodule

`undef DBG
`default_nettype wire
