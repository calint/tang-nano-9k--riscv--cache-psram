//
// RISC-V reduced rv32i for Tang Nano 9K
//
// reviewed 2024-06-25
//
`timescale 1ns / 1ps
//
`default_nettype none

module top (
    input wire rst_n,
    input wire clk,    // 27 MHz

    output logic [5:0] led,
    input wire uart_rx,
    output logic uart_tx,
    input wire btn1,

    output logic flash_clk,
    input  wire  flash_miso,
    output logic flash_mosi,
    output logic flash_cs_n,

    // magic ports for PSRAM to be inferred
    output logic [ 1:0] O_psram_ck,
    output logic [ 1:0] O_psram_ck_n,
    inout  wire  [ 1:0] IO_psram_rwds,
    inout  wire  [15:0] IO_psram_dq,
    output logic [ 1:0] O_psram_reset_n,
    output logic [ 1:0] O_psram_cs_n
);

  logic [7:0] data;
  logic go;
  wire bsy;

  uarttx #(
      .ClockFrequencyHz(27_000_000),
      .BaudRate(1200)
  ) utx (
      .rst_n,
      .clk,
      .data,
      .go,
      .tx(uart_tx),
      .bsy
  );

  logic [4:0] state;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state <= 0;
      go <= 0;
      data <= 8'h61;
    end else begin

      case (state)

        0: begin
          go <= 1;
          state <= 1;
        end

        1: begin
          state <= 2;
        end

        2: begin
          if (!bsy) begin
            go   <= 0;
            data <= data + 1'b1;
            if (data == 8'h7a) begin
              data <= 8'h61;
            end
            state <= 0;
          end
        end

      endcase

    end

  end


endmodule

`default_nettype wire
