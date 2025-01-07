//
// Interface to SD card IP
//
`timescale 1ns / 1ps
//
`default_nettype none
//`define DBG
//`define INFO

module sdcard #(
    parameter int unsigned ClockDivider = 2,
    // when clk =   0~ 25MHz , set 1,
    // when clk =  25~ 50MHz , set 2,
    // when clk =  50~100MHz , set 3,
    // when clk = 100~200MHz , set 4,
    // ......

    parameter int unsigned Simulate = 0
    // set 1 to shorten some delay cycles
) (
    input wire clk,

    input wire rst_n,

    input wire [1:0] command,
    // 0: idle
    // 1: start read of sector specified by 'sector_address'
    // 2: update 'data_out' with next byte in buffer

    input wire [31:0] sector_address,
    // sector to read with 'command' 1

    output logic [7:0] data_out,
    // ??? why not word instead of byte

    output logic busy,
    // true while busy reading SD card

    output wire [3:0] card_stat,
    // state of 'sd_reader'

    output wire [1:0] card_type,
    // 0 = UNKNOWN, 1 = SDv1, 2 = SDv2, 3 = SDHCv2

    // wires to SD card
    output wire sd_clk,
    output wire sd_mosi,
    input  wire sd_miso
);

  logic [7:0] buffer[512];
  logic [8:0] buffer_index;

  // related to 'sd_reader'
  logic rstart;
  wire rbusy;
  wire rdone;
  wire outen;  // when outen=1, a byte of sector content is read out from outbyte
  wire [8:0] outaddr;  // outaddr from 0 to 511, because the sector size is 512
  wire [7:0] outbyte;
  logic [31:0] rsector;
  //

  typedef enum {
    Init,
    Idle,
    ReadSDCard
  } state_e;

  state_e state;

  always_comb begin
    data_out = buffer[buffer_index];
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      buffer_index <= 0;
      rstart <= 0;
      rsector <= 0;
      busy <= 1;
      state <= Init;
    end else begin
      rstart <= 0;

      case (state)

        Init: begin
          if (!rbusy) begin
            busy  <= 0;
            state <= Idle;
          end
        end

        Idle: begin
          if (command == 1) begin
            rsector <= sector_address;
            rstart <= 1;
            buffer_index <= 0;
            busy <= 1;
            state <= ReadSDCard;
          end else if (command == 2) begin
            buffer_index <= buffer_index + 1'b1;
          end
        end

        ReadSDCard: begin
          if (outen) begin
            buffer[buffer_index] <= outbyte;
            buffer_index <= buffer_index + 1'b1;
          end
          if (rdone) begin
            // note: buffer_index har rolled over to 0
            // ??? don't need to wait for 'rdone' to make buffer available for read
            busy  <= 0;
            state <= Idle;
          end

        end
      endcase
    end
  end

  sd_reader #(
      .CLK_DIV (ClockDivider),
      .SIMULATE(Simulate)
  ) sd_reader (
      .clk,
      .rstn  (rst_n),
      // SDcard signals (connect to SDcard), this design do not use sddat1~sddat3.
      .sdclk (sd_clk),
      .sdcmd (sd_mosi),
      .sddat0(sd_miso),  // FPGA only read SDDAT signal but never drive it
      // show card status
      .card_stat,  // show the sdcard initialize status
      .card_type,  // 0=UNKNOWN, 1=SDv1, 2=SDv2, 3=SDHCv2
      // user read sector command interface (sync with clk)
      .rstart,
      .rsector,
      .rbusy,
      .rdone,
      // sector data output interface (sync with clk)
      .outen,  // when outen=1, a byte of sector content is read out from outbyte
      .outaddr,  // outaddr from 0 to 511, because the sector size is 512
      .outbyte
  );

endmodule

`undef DBG
`undef INFO
`default_nettype wire
