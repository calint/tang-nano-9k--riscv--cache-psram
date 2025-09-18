//
// UART transmitter
//
// reviewed 2024-06-25
//
`timescale 1ns / 1ps
//
`default_nettype none
// `define DBG
// `define INFO

module uarttx #(
    parameter int unsigned ClockFrequencyHz = 66_000_000,
    parameter int unsigned BaudRate = 9600
) (
    input wire rst_n,
    input wire clk,

    input wire [7:0] data,
    // data to send

    input wire go,
    // enable to start transmission
    // disable after 'busy' has gone low to acknowledge that data has been sent
    //   then enable to start sending new data

    output logic tx,
    // UART tx wire

    output logic busy
    // enabled while sending
    //  after sending, 'busy' is set to low and needs to be acknowledged by setting 'go' low
    //   before transmitting new 'data' by enabling 'go'
);

  localparam int unsigned BIT_TIME = ClockFrequencyHz / BaudRate;

  typedef enum {
    Idle,
    StartBit,
    DataBits,
    StopBit,
    WaitForGoLow
  } state_e;

  state_e state;

  logic [2:0] bit_count;  // 3 bits to fit number 7

  logic [(BIT_TIME == 1 ? 1 : $clog2(BIT_TIME))-1:0] bit_time_counter;

  always_comb begin
    unique case (state)

      Idle: begin
        if (go) begin
          // start sending start bit in this cycle
          tx   = 0;
          busy = 1;
        end else begin
          tx   = 1;
          busy = 0;
        end
      end

      StartBit: begin
        tx   = 0;
        busy = 1;
      end

      DataBits: begin
        tx   = data[bit_count];
        busy = 1;
      end

      StopBit: begin
        tx   = 1;
        busy = 1;
      end

      WaitForGoLow: begin
        tx   = 1;
        busy = 0;
      end

      default: begin
        // note: not necessary but otherwise Gowin EDA 1.9.10.03 Educational
        //       infers latches for 'busy' and 'tx'
        tx   = 1;
        busy = 0;
      end

    endcase
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state <= Idle;
    end else begin
      unique case (state)

        Idle: begin
          if (go) begin
            // start bit starts sending during this cycle
            if (BIT_TIME == 1) begin
              // special case: full start bit was sent during
              // this cycle. jump to send data bits
              bit_time_counter <= BIT_TIME - 1;
              bit_count <= 0;
              state <= DataBits;
            end else begin
              bit_time_counter <= BIT_TIME - 2;
              // note: -2: -1 because first cycle in the start bit
              //       is sent during this cycle and another -1
              //       because of the comparison when non-blocking
              //       assignments
              state <= StartBit;
            end
          end
        end

        StartBit: begin
          bit_time_counter <= bit_time_counter - 1'b1;
          if (bit_time_counter == 0) begin
            bit_time_counter <= BIT_TIME - 1;
            bit_count <= 0;
            state <= DataBits;
          end
        end

        DataBits: begin
          bit_time_counter <= bit_time_counter - 1'b1;
          if (bit_time_counter == 0) begin
            bit_time_counter <= BIT_TIME - 1;
            bit_count <= bit_count + 1'b1;
            if (bit_count == 8 - 1) begin
              state <= StopBit;
            end
          end
        end

        StopBit: begin
          bit_time_counter <= bit_time_counter - 1'b1;
          if (bit_time_counter == 0) begin
            state <= WaitForGoLow;
          end
        end

        WaitForGoLow: begin
          // wait for acknowledge that 'data' has been sent
          if (!go) begin
            state <= Idle;
          end
        end

        default: ;  // note: not necessary

      endcase
    end
  end

endmodule

`undef DBG
`undef INFO
`default_nettype wire
