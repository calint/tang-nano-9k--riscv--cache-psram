`timescale 100ps / 100ps
//
`default_nettype none

module Top (
    input wire sys_clk,  // 27 MHz
    input wire sys_rst_n,
    output reg [5:0] led,
    input wire uart_rx,
    output wire uart_tx,
    input wire btn1
);

  Device dut (
      .clk(sys_clk),
      .rst_n(sys_rst_n),
      .address(led),
      .data_out(uart_tx)
  );

endmodule