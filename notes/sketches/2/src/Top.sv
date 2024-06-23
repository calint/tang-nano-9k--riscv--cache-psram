`timescale 100ps / 100ps
//
`default_nettype none

module Top (
    input wire clk,   // 27 MHz
    input wire rst_n,

    output logic [5:0] led,
    input wire btn1
);

  Device dut (
      .rst_n,
      .clk,

      .address (btn1),
      .data_out(led[0])
  );

endmodule
