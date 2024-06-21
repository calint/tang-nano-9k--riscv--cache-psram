//
// a partial emulator of flash circuit (P25Q32U) used in simulation
//  mock IP component
//
`timescale 100ps / 100ps
//
`default_nettype none
// `define DBG
// `define INFO

module Flash #(
    parameter DataFilePath = "",  // initial RAM content
    parameter AddressBitWidth = 8
) (
    input wire rst_n,
    input wire clk,

    output reg  miso,
    input  wire mosi,
    input  wire cs
);

  localparam DEPTH = 2 ** AddressBitWidth;

  reg [7:0] data[DEPTH];

  reg [AddressBitWidth-1:0] address;
  reg [7:0] current_byte;
  reg [7:0] counter;

  localparam STATE_RECEIVE_COMMAND = 4'b0001;
  localparam STATE_RECEIVE_ADDRESS = 4'b0010;
  localparam STATE_SEND_DATA = 4'b0100;

  reg [3:0] state;

  initial begin

`ifdef INFO
    $display("----------------------------------------");
    $display("  Flash");
    $display("----------------------------------------");
    $display("  data file: %s", DataFilePath);
    $display("       size: %0d B", DEPTH);
    $display("----------------------------------------");
`endif

    if (DataFilePath != "") begin
      $readmemh(DataFilePath, data);
    end
  end

  always @(negedge clk, negedge rst_n) begin
    if (!rst_n) begin
      counter <= 7;
      address <= 0;
      current_byte <= data[0];
      miso <= 0;
      state <= STATE_RECEIVE_COMMAND;
    end else begin

`ifdef DBG
      $display("state: %0d  counter: %0d  address: %h", state, counter, address);
`endif

      unique case (state)

        STATE_RECEIVE_COMMAND: begin
          counter <= counter - 1;
          if (counter == 0) begin
            counter <= 23;
            state   <= STATE_RECEIVE_ADDRESS;
          end
        end

        STATE_RECEIVE_ADDRESS: begin
          counter <= counter - 1;
          if (counter == 0) begin
            counter <= 6;  // not 7 because first bit is sent here
            miso <= current_byte[7];
            current_byte <= {current_byte[6:0], 1'b0};
            address <= address + 1;
            state <= STATE_SEND_DATA;
          end
        end

        STATE_SEND_DATA: begin
          if (!cs) begin
            miso <= current_byte[7];
            current_byte <= {current_byte[6:0], 1'b0};
            counter <= counter - 1;
            if (counter == 0) begin
              counter <= 7;
              current_byte <= data[address];
              address <= address + 1;
            end
          end
        end

      endcase
    end
  end
endmodule

`undef DBG
`undef INFO
`default_nettype wire
