//
// a partial emulator of flash circuit (P25Q32U) used in simulation
//  mock IP component
//
// reviewed 2024-06-26
//
`timescale 100ps / 100ps
//
`default_nettype none
// `define DBG
// `define INFO

module flash #(
    parameter string DataFilePath = "",
    // initial RAM content; one byte per line in hex text

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
  logic [8:0] counter;
  // note: one extra bit to decrement into negative for more efficient comparison

  typedef enum {
    ReceiveCommand,
    ReceiveAddress,
    SendData
  } state_e;

  state_e state;

  initial begin
`ifdef INFO
    $display("----------------------------------------");
    $display("  flash");
    $display("----------------------------------------");
    $display("  data file: %s", DataFilePath);
    $display("       size: %0d B", DEPTH);
    $display("----------------------------------------");
`endif
    if (DataFilePath != "") begin
      $readmemh(DataFilePath, data);
    end
  end

  always_ff @(negedge clk or negedge rst_n) begin
    // note: on negedge so that data is available during the whole cycle
    if (!rst_n) begin
      counter <= 8 - 2;  // -2 because decrementing into negative
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
          if (!cs) begin
            // note: assume 'read', the only command implemented
            counter <= counter - 1'b1;
            if (counter[8]) begin
              counter <= 24 - 2;  // -2 because decrementing into negative
              state   <= ReceiveAddress;
            end
          end
        end

        ReceiveAddress: begin
          if (!cs) begin
            counter <= counter - 1'b1;
            if (counter[8]) begin
              counter <= 7 - 2;
              // 7 because first bit sent in this cycle
              // -2 because decrementing into negative

              miso <= current_byte[7];
              current_byte <= {current_byte[6:0], 1'b0};
              address <= address + 1'b1;
              state <= SendData;
            end
          end
        end

        SendData: begin
          if (!cs) begin
            miso <= current_byte[7];
            current_byte <= {current_byte[6:0], 1'b0};
            counter <= counter - 1'b1;
            if (counter[8]) begin
              counter <= 8 - 2;  // -2 because decrementing into negative
              current_byte <= data[address];
              address <= address + 1'b1;
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
