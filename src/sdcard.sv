//
// Interface to SD card IP
//
`timescale 1ns / 1ps
//
`default_nettype none
//`define DBG
//`define INFO

module sdcard #(
    parameter int unsigned Simulate = 0,
    // set 1 to shorten some delay cycles

    parameter int unsigned ClockDivider = 4
    // generates slow clock for SD
) (
    input wire clk,

    input wire rst_n,

    input wire [1:0] command,
    // 0: idle
    // 1: start read of sector specified by 'sector'
    // 2: update 'data_out' with next byte in buffer

    input wire [31:0] sector,
    // sector to read with 'command' 1

    output wire [7:0] data_out,
    // ??? why not word instead of byte

    output wire busy,
    // true while busy reading SD card

    output wire [31:0] status,
    // state of 'sd_reader'

    // wires to SD card
    output wire sd_cs_n,
    output wire sd_clk,
    output wire sd_mosi,
    input  wire sd_miso
);

  logic [7:0] buffer[512];
  logic [8:0] buffer_index;

  // related to 'sd_controller'
  logic rd;
  logic wr;
  wire [7:0] dout;
  wire [7:0] recv_data;
  logic [7:0] din;
  logic [31:0] address;
  wire byte_available;
  wire ready_for_next_byte;
  wire ready;
  //

  typedef enum {
    Init,
    Idle,
    PreReadSector,
    ReadSector
  } state_e;

  state_e state;

  assign data_out = buffer[buffer_index];
  assign busy = state != Idle;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      buffer_index <= 0;
      rd <= 0;
      wr <= 0;
      din <= 0;
      state <= Init;
    end else begin
      rd <= 0;

      case (state)

        Init: begin
          if (ready) begin
            state <= Idle;
          end
        end

        Idle: begin
          if (command == 1) begin
            rd <= 1;
            buffer_index <= 0;
            address <= sector;
            state <= PreReadSector;
          end else if (command == 2) begin
            buffer_index <= buffer_index + 1'b1;
          end
        end

        PreReadSector: begin
          // note: this state necessary because in this cycle 'sd_controller' state is IDLE 
          //       about to switch to READ_BLOCK in next cycle and this not 'ready'
          rd <= 0;
          state <= ReadSector;
        end

        ReadSector: begin

          if (byte_available) begin
            buffer[buffer_index] <= dout;
            buffer_index <= buffer_index + 1'b1;
          end

          if (ready) begin
            // note: buffer_index har rolled over to 0
            state <= Idle;
          end

        end

      endcase
    end
  end

  // slow clock

  logic [ClockDivider == 0 ? 0 : ClockDivider-1:0] counter;
  wire clk_pulse_slow = (counter == '0);
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      counter <= '0;
    end else begin
      if (ClockDivider != 0) begin
        counter <= counter + 1'b1;
      end
    end
  end

  sd_controller sd_controller (
      .clk,  // normal speed clock
      .clk_pulse_slow,

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

      .reset(!rst_n),  // Resets controller on assertion.
      .ready,  // HIGH if the SD card is ready for a read or write operation.
      .address,  // Memory address for read/write operation. This MUST 
      // be a multiple of 512 bytes, due to SD sectoring.
      .status,  // For debug purposes: Current state of controller.
      .recv_data
  );

endmodule

`undef DBG
`undef INFO
`default_nettype wire
