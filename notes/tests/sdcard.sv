//
// Interface to SD card IP
//
`timescale 1ns / 1ps
//
`default_nettype none
//`define DBG
//`define INFO

module sdcard #(
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
    output wire sd_cs_n,
    output wire sd_clk,
    output wire sd_mosi,
    input  wire sd_miso
);

  logic [7:0] buffer[512];
  logic [8:0] buffer_index;

  // related to 'sd_reader'
  logic rd;
  logic wr;
  wire byte_available;  // when byte_available=1, a byte of sector content is read out from dout
  wire [7:0] dout;
  logic [7:0] din;
  wire ready_for_next_byte;
  wire ready;
  logic [31:0] address;
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
      rd <= 0;
      wr <= 0;
      din <= 0;
      address <= 0;
      busy <= 1;
      state <= Init;
    end else begin
      rd <= 0;

      case (state)

        Init: begin
          if (ready) begin
            busy  <= 0;
            state <= Idle;
          end
        end

        Idle: begin
          if (command == 1) begin
            address <= sector_address;
            rd <= 1;
            buffer_index <= 0;
            busy <= 1;
            state <= ReadSDCard;
          end else if (command == 2) begin
            buffer_index <= buffer_index + 1'b1;
          end
        end

        ReadSDCard: begin
          if (byte_available) begin
            buffer[buffer_index] <= dout;
            buffer_index <= buffer_index + 1'b1;
          end
          if (ready) begin
            // note: buffer_index har rolled over to 0
            // ??? don't need to wait for 'rdone' to make buffer available for read
            rd <= 0;
            busy <= 0;
            state <= Idle;
          end

        end
      endcase
    end
  end


  sd_controller #(
      .Simulate(Simulate)
  ) sd_controller (
      .cs  (sd_cs_n),  // Connect to SD_DAT[3].
      .mosi(sd_mosi),  // Connect to SD_CMD.
      .miso(sd_miso),  // Connect to SD_DAT[0].
      .sclk(sd_clk),   // Connect to SD_SCK.
      // For SPI mode, SD_DAT[2] and SD_DAT[1] should be held HIGH. 
      // SD_RESET should be held LOW.

      .rd,  // Read-enable. When [ready] is HIGH, asseting [rd] will 
      // begin a 512-byte READ operation at [address]. 
      // [byte_available] will transition HIGH as a new byte has been
      // read from the SD card. The byte is presented on [dout].
      .dout,  // Data output for READ operation.
      .byte_available,  // A new byte has been presented on [dout].

      .wr,  // Write-enable. When [ready] is HIGH, asserting [wr] will
      // begin a 512-byte WRITE operation at [address].
      // [ready_for_next_byte] will transition HIGH to request that
      // the next byte to be written should be presentaed on [din].
      .din,  // Data input for WRITE operation.
      .ready_for_next_byte,  // A new byte should be presented on [din].

      .reset (!rst_n),    // Resets controller on assertion.
      .ready,  // HIGH if the SD card is ready for a read or write operation.
      .address,  // Memory address for read/write operation. This MUST 
      // be a multiple of 512 bytes, due to SD sectoring.
      .clk,  // 25 MHz clock.
      .status(card_stat)  // For debug purposes: Current state of controller.
  );

endmodule

`undef DBG
`undef INFO
`default_nettype wire
