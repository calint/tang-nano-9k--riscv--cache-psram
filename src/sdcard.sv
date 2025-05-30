//
// Interface to SD card IP
//
`timescale 1ns / 1ps
//
`default_nettype none
// `define DBG
// `define INFO

module sdcard #(
    parameter bit Simulate = 0,
    // set 1 to shorten some delay cycles

    parameter int unsigned ClockDivider = 4,
    // generates slow clock for SD
    //  0: at ~30 MHz, 54 MHz, 60 MHz

    parameter int unsigned SectorToSDCardAddressShiftLeft = 0
    // 8 GB card is addressed in sectors thus shift 0
    // 64 MB card is addressed in multiple of 512 bytes thus shift 9
) (
    input wire clk,

    input wire rst_n,

    input wire [2:0] command,
    // 0: idle
    // 1: start read of sector specified by 'sector'
    // 2: update 'data_out' with next byte in buffer
    // 3: write 'data_in' to buffer and increment index
    // 4: write buffer to sector specified by 'sector'

    input wire [31:0] sector,
    // sector to read with 'command' 1 and write with 'command' 3

    output logic [7:0] data_out,
    // data at current buffer index

    input wire [7:0] data_in,
    // data to write when 'command' is 3

    output logic busy,
    // true while reading or writing SD card

    output logic [31:0] status,
    // state of 'sd_reader'

    // wires to SD card
    output logic sd_cs_n,
    output logic sd_clk,
    output logic sd_mosi,
    input  wire  sd_miso
);

  logic [7:0] buffer[512];
  logic [8:0] buffer_index;

  // related to 'sd_controller'
  logic rd;
  logic wr;
  wire [7:0] dout;
  wire [7:0] recv_data;  // unused
  logic [7:0] din;
  logic [31:0] address;
  wire byte_available;
  wire ready_for_next_byte;
  wire ready;
  //

  logic waiting_ready_for_next_byte;
  // used to handle 'ready_for_next_byte' being asserted
  // multiple cycles for same data

  typedef enum {
    Init,
    Idle,
    PreReadSector,
    ReadSector,
    PreWriteSector,
    WriteSector
  } state_e;

  state_e state;

  assign data_out = buffer[buffer_index];
  assign busy = state != Idle;

  // wiring of 'sd_controller' status to 32 bit output
  wire [4:0] status_in;
  assign status = {27'b0, status_in};

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      rd <= 0;
      wr <= 0;
      din <= 0;
      buffer_index <= 0;
      state <= Init;
    end else begin

      case (state)

        Init: begin
          if (ready) begin
            // wait for card to be ready
            state <= Idle;
          end
        end

        Idle: begin
          case (command)
            1: begin  // read sector
              rd <= 1;
              address <= sector << SectorToSDCardAddressShiftLeft;
              state <= PreReadSector;
            end
            2: begin  // advance buffer index
              buffer_index <= buffer_index + 1'b1;
            end
            3: begin  // write to buffer
              buffer[buffer_index] <= data_in;
              buffer_index <= buffer_index + 1'b1;
            end
            4: begin  // write sector
              wr <= 1;
              waiting_ready_for_next_byte <= 1;
              address <= sector << SectorToSDCardAddressShiftLeft;
              state <= PreWriteSector;
            end
          endcase
        end

        PreReadSector: begin
          // note: this state is necessary because in this cycle 'sd_controller' state is IDLE 
          //       with 'ready' asserted. next cycle state is READ_BLOCK and 'ready' de-asserted
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

        PreWriteSector: begin
          // note: this state is necessary because in this cycle 'sd_controller' state is IDLE 
          //       with 'ready' asserted. next cycle state is WRITE_BLOCK_CMD and 'ready' de-asserted
          wr <= 0;
          state <= WriteSector;
        end

        WriteSector: begin

          // note: 'ready_for_next_byte' lasts for several cycles so a switch is
          //       needed to not write multiple times per 'ready_for_next_byte'
          if (ready_for_next_byte && waiting_ready_for_next_byte) begin
            din <= buffer[buffer_index];
            buffer_index <= buffer_index + 1'b1;
            waiting_ready_for_next_byte <= 0;
          end

          if (!ready_for_next_byte && !waiting_ready_for_next_byte) begin
            waiting_ready_for_next_byte <= 1;
          end

          if (ready) begin
            // note: buffer_index har rolled over to 0
            state <= Idle;
          end

        end

      endcase
    end
  end

  // slow clock for 'sd_controller'
  // 'ClockDivider' adjusted depending on 'clk' frequency

  logic [ClockDivider == 0 ? 0 : ClockDivider-1:0] counter;
  wire clk_pulse_slow = (counter == 0);
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      counter <= 0;
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

      .reset (!rst_n),    // Resets controller on assertion.
      .ready,  // HIGH if the SD card is ready for a read or write operation.
      .address,  // Memory address for read/write operation. This MUST 
      // be a multiple of 512 bytes, due to SD sectoring.
      // note: on the card tested 'address' is sector number starting at 0
      .status(status_in), // For debug purposes: Current state of controller.
      .recv_data
  );

endmodule

`undef DBG
`undef INFO
`default_nettype wire
