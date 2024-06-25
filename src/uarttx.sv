//
// UART transmitter
//
// reviewed 2024-06-25
//
`timescale 100ps / 100ps
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
    // disable after 'bsy' has gone low to acknowledge that data has been sent
    //   then enable to start sending new data

    output logic tx,
    // UART tx wire

    output logic bsy
    // enabled while sending
    //  after sending, 'bsy' is set to low and needs to be acknowledged by setting 'go' low
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

  logic [3:0] bit_count;  // 4 bits to fit number 8

  logic [(BIT_TIME == 1 ? 1 : $clog2(BIT_TIME))-1:0] bit_time_counter;

  always_ff @(negedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= Idle;
      bit_count <= 0;
      bit_time_counter <= 0;
      tx <= 1;
      bsy <= 0;
    end else begin
      unique case (state)

        Idle: begin
          if (go) begin
            bsy <= 1;
            bit_time_counter <= BIT_TIME - 1;
            // note: -1 because first 'tick' of 'start bit' is being sent in this state
            tx <= 0;  // start sending 'start bit'
            state <= StartBit;
          end
        end

        StartBit: begin
          bit_time_counter <= bit_time_counter - 1'b1;
          if (bit_time_counter == 0) begin
            bit_time_counter <= BIT_TIME - 1;
            // note: -1 because first 'tick' of the first bit is being sent in this state
            tx <= data[0];  // start sending first bit of data
            bit_count <= 1;  // first bit is being sent during this cycle
            state <= DataBits;
          end
        end

        DataBits: begin
          bit_time_counter <= bit_time_counter - 1'b1;
          if (bit_time_counter == 0) begin
            tx <= data[bit_count];
            bit_time_counter <= BIT_TIME - 1;
            // note: -1 because first 'tick' of next bit is sent in this state
            bit_count <= bit_count + 1'b1;
            if (bit_count == 8) begin
              bit_count <= 0;
              tx <= 1;  // overwrite tx, start sending stop bit
              state <= StopBit;
            end
          end
        end

        StopBit: begin
          bit_time_counter <= bit_time_counter - 1'b1;
          if (bit_time_counter == 0) begin
            bsy   <= 0;
            state <= WaitForGoLow;
          end
        end

        WaitForGoLow: begin
          // wait for acknowledge that 'data' has been sent
          if (!go) begin
            state <= Idle;
          end
        end

        default: ;

      endcase
    end
  end

endmodule

`undef DBG
`undef INFO
`default_nettype wire
