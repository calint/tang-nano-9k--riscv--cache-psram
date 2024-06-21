//
// a partial emulator of flash circuit (P25Q32U) used in simulation
//  mock IP component
//
`timescale 100ps / 100ps
//
`default_nettype none
// `define DBG
// `define INFO

module flash #(
    parameter string DataFilePath = "",  // initial RAM content
    parameter int unsigned AddressBitWidth = 8
) (
    input wire rst_n,
    input wire clk,

    output logic miso,
    input  wire  mosi,
    input  wire  cs
);

  localparam int unsigned DEPTH = 2 ** AddressBitWidth;

  logic [7:0] data[DEPTH];

  logic [AddressBitWidth-1:0] address;
  logic [7:0] current_byte;
  logic [7:0] counter;

  typedef enum {
    ReceiveCommand,
    ReceiveAddress,
    SendData
  } state_e;

  state_e state;

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
      state <= ReceiveCommand;
    end else begin

`ifdef DBG
      $display("state: %0d  counter: %0d  address: %h", state, counter, address);
`endif

      unique case (state)

        ReceiveCommand: begin
          counter <= counter - 1;
          if (counter == 0) begin
            counter <= 23;
            state   <= ReceiveAddress;
          end
        end

        ReceiveAddress: begin
          counter <= counter - 1;
          if (counter == 0) begin
            counter <= 6;  // not 7 because first bit is sent here
            miso <= current_byte[7];
            current_byte <= {current_byte[6:0], 1'b0};
            address <= address + 1;
            state <= SendData;
          end
        end

        SendData: begin
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
