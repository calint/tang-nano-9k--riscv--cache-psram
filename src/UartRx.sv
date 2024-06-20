//
// UART receiver
//
`timescale 100ps / 100ps
//
`default_nettype none
// `define DBG
// `define INFO

module UartRx #(
    parameter CLK_FREQ  = 66_000_000,
    parameter BAUD_RATE = 9600
) (
    input wire rst_n,
    input wire clk,

    input wire rx,
    input wire go,
    output reg [7:0] data,
    output reg dr  // enabled when data is ready
);

  localparam BIT_TIME = CLK_FREQ / BAUD_RATE;

  localparam STATE_IDLE = 5'b00001;
  localparam STATE_START_BIT = 5'b00010;
  localparam STATE_DATA_BITS = 5'b00100;
  localparam STATE_STOP_BIT = 5'b01000;
  localparam STATE_WAIT_GO_LOW = 5'b10000;

  reg [4:0] state;  // 5 states
  reg [3:0] bit_count;  // 4 bits to fit number 8
  reg [(BIT_TIME == 1 ? 1 : $clog2(BIT_TIME))-1:0] bit_counter;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= STATE_IDLE;
      data <= 0;
      bit_count <= 0;
      bit_counter <= 0;
      dr <= 0;
    end else begin
      case (state)

        STATE_IDLE: begin
          if (go && !rx) begin  // does the cpu wait for data and start bit has started?
            bit_counter <= BIT_TIME == 1 ? 0 : (BIT_TIME / 2 - 1);
            // note: -1 because one of the ticks has been read before switching state
            //  BIT_TIME / 2 to sample in the middle of next cycle

            // if BIT_TIME == 1 then the start bit has been read, jump to read bits
            state <= BIT_TIME == 1 ? STATE_DATA_BITS : STATE_START_BIT;
          end
        end

        STATE_START_BIT: begin
          bit_counter <= bit_counter - 1;
          if (bit_counter == 0) begin
            bit_counter <= BIT_TIME - 1;
            // note: -1 because one of the ticks has been read before switching state
            bit_count <= 0;
            state <= STATE_DATA_BITS;
          end
          // if (rx) begin
          //   // note: check 'rx' in case there is drifting
          //   //  some of the ticks of the start bit has been missed
          //   //   set the 'bit_counter' to half a cycle
          //   bit_counter <= BIT_TIME == 1 ? 0 : (BIT_TIME / 2 - 1);
          //   // note: -1 because one of the ticks has been read before switching state
          //   //  BIT_TIME / 2 to sample in the middle of next cycle
          //   state <= STATE_DATA_BITS;
          // end
        end

        STATE_DATA_BITS: begin
          bit_counter <= bit_counter - 1;
          if (bit_counter == 0) begin
            data[bit_count] <= rx;
            bit_counter <= BIT_TIME - 1;
            // note: -1 because one of the ticks has been read before switching state
            bit_count <= bit_count + 1;
            if (bit_count == 7) begin
              // note: 7, not 8, because of NBA
              bit_count <= 0;
              state <= STATE_STOP_BIT;
            end
          end
        end

        STATE_STOP_BIT: begin
          bit_counter <= bit_counter - 1;
          if (bit_counter == 0) begin
            // note: if drifting then start bit might arrive before expected
            dr <= 1;
            state <= STATE_WAIT_GO_LOW;
          end
        end

        STATE_WAIT_GO_LOW: begin
          if (!go) begin
            data <= 0;
            dr <= 0;
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

