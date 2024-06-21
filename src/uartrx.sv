//
// UART receiver
//
`timescale 100ps / 100ps
//
`default_nettype none
// `define DBG
// `define INFO

module uartrx #(
    parameter int unsigned ClockFrequencyMhz = 66_000_000,
    parameter int unsigned BaudRate = 9600
) (
    input wire rst_n,
    input wire clk,

    input wire rx,
    input wire go,
    output logic [7:0] data,
    output logic dr  // enabled when data is ready
);

  localparam int unsigned BIT_TIME = ClockFrequencyMhz / BaudRate;

  typedef enum {
    Idle,
    StartBit,
    DataBits,
    StopBit,
    WaitForGoLow
  } state_e;

  state_e state;  // 5 states
  logic [3:0] bit_count;  // 4 bits to fit number 8
  logic [(BIT_TIME == 1 ? 1 : $clog2(BIT_TIME))-1:0] bit_counter;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= Idle;
      data <= 0;
      bit_count <= 0;
      bit_counter <= 0;
      dr <= 0;
    end else begin
      unique case (state)

        Idle: begin
          if (go && !rx) begin  // does the cpu wait for data and start bit has started?
            bit_counter <= BIT_TIME == 1 ? 0 : (BIT_TIME / 2 - 1);
            // note: -1 because one of the ticks has been read before switching state
            //  BIT_TIME / 2 to sample in the middle of next cycle

            // if BIT_TIME == 1 then the start bit has been read, jump to read bits
            state <= BIT_TIME == 1 ? DataBits : StartBit;
          end
        end

        StartBit: begin
          bit_counter <= bit_counter - 1'b1;
          if (bit_counter == 0) begin
            bit_counter <= BIT_TIME - 1;
            // note: -1 because one of the ticks has been read before switching state
            bit_count <= 0;
            state <= DataBits;
          end
        end

        DataBits: begin
          bit_counter <= bit_counter - 1'b1;
          if (bit_counter == 0) begin
            data[bit_count] <= rx;
            bit_counter <= BIT_TIME - 1;
            // note: -1 because one of the ticks has been read before switching state
            bit_count <= bit_count + 1'b1;
            if (bit_count == 7) begin
              // note: 7, not 8, because of NBA
              bit_count <= 0;
              state <= StopBit;
            end
          end
        end

        StopBit: begin
          bit_counter <= bit_counter - 1'b1;
          if (bit_counter == 0) begin
            // note: if drifting then start bit might arrive before expected
            dr <= 1;
            state <= WaitForGoLow;
          end
        end

        WaitForGoLow: begin
          if (!go) begin
            data <= 0;
            dr <= 0;
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

