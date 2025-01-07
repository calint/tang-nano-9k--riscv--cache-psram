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
) (
    input wire clk_i,

    input wire rst_ni,

    input wire [1:0] cmd_i,
    // 0: idle
    // 1: start read SD card at 'sector_address_i'
    // 2: write next byte from buffer to 'data_o'

    input wire [31:0] sector_address_i,

    output logic [7:0] data_o,
    // ??? why not word instead of byte

    output logic busy_o,
    // true while busy reading SD card

    output wire [3:0] card_stat_o,

    output wire [1:0] card_type_o,

    // interface to SD card
    output wire clk_sd_o,
    inout wire sd_cmd_io,
    input wire [3:0] sd_dat_i
);

  logic [7:0] buffer[512];
  logic [8:0] buffer_index;

  logic u_sd_reader_rstart;
  wire u_sd_reader_rbusy;
  wire u_sd_reader_rdone;
  wire u_sd_reader_outen;  // when outen=1, a byte of sector content is read out from outbyte
  wire [8:0] u_sd_reader_outaddr;  // outaddr from 0 to 511, because the sector size is 512
  wire [7:0] u_sd_reader_outbyte;
  logic [31:0] u_sd_reader_rsector;

  typedef enum {
    Init,
    Idle,
    ReadSDCard
  } state_e;

  state_e state;

  always_comb begin
    data_o = buffer[buffer_index];
  end

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      buffer_index <= 0;
      u_sd_reader_rstart <= 0;
      u_sd_reader_rsector <= 0;
      busy_o <= 1;
      state <= Init;
    end else begin
      u_sd_reader_rstart <= 0;

      case (state)

        Init: begin
          if (!u_sd_reader_rbusy) begin
            busy_o <= 0;
            state  <= Idle;
          end
        end

        Idle: begin
          if (cmd_i == 1) begin
            u_sd_reader_rsector <= sector_address_i;
            u_sd_reader_rstart <= 1;
            buffer_index <= 0;
            busy_o <= 1;
            state <= ReadSDCard;
          end else if (cmd_i == 2) begin
            buffer_index <= buffer_index + 1'b1;
          end
        end

        ReadSDCard: begin
          if (u_sd_reader_outen) begin
            buffer[buffer_index] <= u_sd_reader_outbyte;
            buffer_index <= buffer_index + 1'b1;
          end
          if (u_sd_reader_rdone) begin
            // note: buffer_index har rolled over to 0
            // ??? don't need to wait for 'rdone' to make buffer available for read
            busy_o <= 0;
            state  <= Idle;
          end

        end
      endcase
    end
  end

  sd_reader #(
      .CLK_DIV (ClockDivider),
      .SIMULATE(Simulate)
  ) u_sd_reader (
      .clk(clk_i),
      .rstn(rst_ni),
      // SDcard signals (connect to SDcard), this design do not use sddat1~sddat3.
      .sdclk(clk_sd_o),
      .sdcmd(sd_cmd_io),
      .sddat0(sd_dat_i[0]),  // FPGA only read SDDAT signal but never drive it
      // show card status
      .card_stat(card_stat_o),  // show the sdcard initialize status
      .card_type(card_type_o),  // 0=UNKNOWN, 1=SDv1, 2=SDv2, 3=SDHCv2
      // user read sector command interface (sync with clk)
      .rstart(u_sd_reader_rstart),
      .rsector(u_sd_reader_rsector),
      .rbusy(u_sd_reader_rbusy),
      .rdone(u_sd_reader_rdone),
      // sector data output interface (sync with clk)
      .outen(u_sd_reader_outen),  // when outen=1, a byte of sector content is read out from outbyte
      .outaddr(u_sd_reader_outaddr),  // outaddr from 0 to 511, because the sector size is 512
      .outbyte(u_sd_reader_outbyte)
  );

endmodule

`undef DBG
`undef INFO
`default_nettype wire
