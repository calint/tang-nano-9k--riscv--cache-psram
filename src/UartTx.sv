`timescale 100ps / 100ps
//
`default_nettype none
// `define DBG
// `define INFO

module UartTx #(
    parameter CLK_FREQ  = 66_000_000,
    parameter BAUD_RATE = 9600
) (
    input wire rst_n,
    input wire clk,

    input wire [7:0] data,  // data to send

    // assert to start transmission, disable after 'data' has been read
    input  wire go,
    output reg  tx,  // uart tx wire
    output reg  bsy  // enabled while sendng
);

  localparam BIT_TIME = CLK_FREQ / BAUD_RATE;

  localparam STATE_IDLE = 0;
  localparam STATE_START_BIT = 1;
  localparam STATE_DATA_BITS = 2;
  localparam STATE_STOP_BIT = 3;
  localparam STATE_WAIT_GO_LOW = 4;

  reg [$clog2(5)-1:0] state;
  reg [$clog2(9)-1:0] bit_count;
  reg [(BIT_TIME == 1 ? 1 : $clog2(BIT_TIME))-1:0] bit_time_counter;

  always_ff @(negedge clk, negedge rst_n) begin
    if (!rst_n) begin
      state <= STATE_IDLE;
      bit_count <= 0;
      bit_time_counter <= 0;
      tx <= 1;
      bsy <= 0;
    end else begin
      case (state)
        STATE_IDLE: begin
          if (go) begin
            bsy <= 1;
            bit_time_counter <= BIT_TIME - 1; // -1 because first 'tick' of 'start bit' is being sent in this state
            tx <= 0;  // start sending 'start bit'
            state <= STATE_START_BIT;
          end
        end
        STATE_START_BIT: begin
          if (bit_time_counter == 0) begin
            bit_time_counter <= BIT_TIME - 1; // -1 because first 'tick' of the first bit is being sent in this state
            tx <= data[0];  // start sending first bit of data
            bit_count <= 1;  // first bit is being sent during this cycle
            state <= STATE_DATA_BITS;
          end else begin
            bit_time_counter <= bit_time_counter - 1;
          end
        end
        STATE_DATA_BITS: begin
          if (bit_time_counter == 0) begin
            tx <= data[bit_count];
            bit_time_counter <= BIT_TIME - 1; // -1 because first 'tick' of next bit is sent in this state
            bit_count <= bit_count + 1;
            if (bit_count == 8) begin
              bit_count <= 0;
              tx <= 1;  // start sending stop bit
              state <= STATE_STOP_BIT;
            end
          end else begin
            bit_time_counter <= bit_time_counter - 1;
          end
        end
        STATE_STOP_BIT: begin
          if (bit_time_counter == 0) begin
            bsy   <= 0;
            state <= STATE_WAIT_GO_LOW;
          end else begin
            bit_time_counter <= bit_time_counter - 1;
          end
        end
        STATE_WAIT_GO_LOW: begin
          if (!go) begin  // wait for acknowledge that 'data' has been sent
            state <= STATE_IDLE;
          end
        end
      endcase
    end
  end

endmodule

`undef DBG
`undef INFO
`default_nettype wire
