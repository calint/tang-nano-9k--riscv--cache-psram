//
// Interface to RAM, UART and LEDs
//
`timescale 100ps / 100ps
//
`default_nettype none
// `define DBG
// `define INFO

module RAMIO #(
    parameter RAM_DEPTH_BITWIDTH = 10,
    parameter RAM_ADDRESSING_MODE = 3,
    parameter CACHE_LINE_IX_BITWIDTH = 1,
    parameter ADDRESS_BITWIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter CLK_FREQ = 20_250_000,
    parameter BAUD_RATE = 9600,
    parameter TOP_ADDRESS = {ADDRESS_BITWIDTH{1'b1}},
    parameter ADDRESS_LED = TOP_ADDRESS,
    parameter ADDRESS_UART_OUT = TOP_ADDRESS - 1,
    parameter ADDRESS_UART_IN = TOP_ADDRESS - 2
    // note: received byte must be read with 'lb' or 'lbu'
) (
    input wire rst_n,
    input wire clk,

    input wire enable,

    // b00 not a write; b01: byte, b10: half word, b11: word
    input wire [1:0] write_type,

    // b000 not a read; bit[2] flags sign extended or not, b01: byte, b10: half word, b11: word
    input wire [2:0] read_type,

    // address in bytes
    input wire [ADDRESS_BITWIDTH-1:0] address,

    // sign extended byte, half word, word
    input wire [DATA_WIDTH-1:0] data_in,

    // data at 'address' according to 'read_type'
    output reg [DATA_WIDTH-1:0] data_out,

    output wire data_out_ready,

    output wire busy,

    // I/O mapping of LEDs
    output reg [3:0] led,

    // UART
    output wire uart_tx,
    input  wire uart_rx,

    // burst RAM wiring; prefix 'br_'
    output reg br_cmd,  // 0: read, 1: write
    output reg br_cmd_en,  // 1: cmd and addr is valid
    output reg [RAM_DEPTH_BITWIDTH-1:0] br_addr,  // see 'RAM_ADDRESSING_MODE'
    output reg [63:0] br_wr_data,  // data to write
    output wire [7:0] br_data_mask,  // always 0 meaning write all bytes
    input wire [63:0] br_rd_data,  // data out
    input wire br_rd_data_valid  // rd_data is valid
);

  // enables / disables RAM operation, connected to cache
  reg ram_enable;
  wire ram_busy;
  wire ram_data_out_ready;

  // byte addressed into cache
  reg [ADDRESS_BITWIDTH-1:0] ram_address;

  // data formatted for byte enabled write
  reg [DATA_WIDTH-1:0] ram_data_in;

  // bytes enabled for writing
  reg [3:0] ram_write_enable;

  wire [DATA_WIDTH-1:0] ram_data_out;

  // forward busy and data ready signals from cache unless it is I/O
  assign busy = address == ADDRESS_UART_OUT || 
                address == ADDRESS_UART_IN || 
                address == ADDRESS_LED 
                ? 0 : ram_busy;

  assign data_out_ready = address == ADDRESS_UART_OUT || 
                          address == ADDRESS_UART_IN ||
                          address == ADDRESS_LED
                          ? 1 : ram_data_out_ready;

  //
  // RAM write
  //  convert 'data_in' using 'write_type' to byte enabled 4 bytes RAM write
  // 
  always_comb begin
    // convert address to 4 byte word addressing in RAM
    ram_address = {address[ADDRESS_BITWIDTH-1:2], 2'b00};

    // initiate result
    ram_enable = 0;
    ram_write_enable = 0;
    ram_data_in = 0;

    if (address == ADDRESS_UART_OUT || address == ADDRESS_UART_IN || address == ADDRESS_LED) begin
      // don't trigger cache when accessing I/O
    end else begin
      // enable RAM
      ram_enable = 1;
      // note: could be done in either 'always_comb' however in this block checks of 
      //  address is done with UART and LED

      // convert input to RAM interface expected byte enabled RAM of 4 bytes
      case (write_type)
        2'b00: begin  // none
          ram_write_enable = 4'b0000;
        end
        2'b01: begin  // byte
          case (address[1:0])
            2'b00: begin
              ram_write_enable = 4'b0001;
              ram_data_in[7:0] = data_in[7:0];
            end
            2'b01: begin
              ram_write_enable  = 4'b0010;
              ram_data_in[15:8] = data_in[7:0];
            end
            2'b10: begin
              ram_write_enable   = 4'b0100;
              ram_data_in[23:16] = data_in[7:0];
            end
            2'b11: begin
              ram_write_enable   = 4'b1000;
              ram_data_in[31:24] = data_in[7:0];
            end
          endcase
        end
        2'b10: begin  // half word
          case (address[1:0])
            2'b00: begin
              ram_write_enable  = 4'b0011;
              ram_data_in[15:0] = data_in[15:0];
            end
            2'b01: ;  // ? error
            2'b10: begin
              ram_write_enable   = 4'b1100;
              ram_data_in[31:16] = data_in[15:0];
            end
            2'b11: ;  // ? error
          endcase
        end
        2'b11: begin  // word
          // ? assert(addr_lower_w==0)
          ram_write_enable = 4'b1111;
          ram_data_in = data_in;
        end
      endcase
    end
  end

  // data being sent by UartTx
  reg [7:0] uarttx_data_sending;

  // data from 'uartrx_data' when 'uartrx_dr' (data ready) enabled
  reg [7:0] uartrx_data_received;

  // 
  // RAM read
  //  convert 'ram_data_out' according to 'read_type'
  //   and handle UART read requests
  //
  always_comb begin
`ifdef DBG
    $display("address: %h  read_type: %b", address, read_type);
`endif
    // create the 'data_out' based on the 'address'
    // data_out = 0; // note: uncommenting this creates infinite loop when simulating with iverilog
    //
    if (address == ADDRESS_UART_OUT && read_type[1:0] == 2'b01) begin
      // if read byte from uart_tx (read_type[2] flags signed)
      data_out = read_type[2] ? 
                    {{24{uarttx_data_sending[7]}}, uarttx_data_sending} : 
                    {{24{1'b0}}, uarttx_data_sending};

    end else if (address == ADDRESS_UART_IN && read_type[1:0] == 2'b01) begin
      // if read byte from uart_rx (read_type[2] flags signed)
      data_out = read_type[2] ? 
                    {{24{uartrx_data_received[7]}}, uartrx_data_received} :
                    {{24{1'b0}}, uartrx_data_received};

    end else begin
      casex (read_type)

        3'bx01: begin  // byte
          case (address[1:0])
            2'b00: begin
              data_out = read_type[2] ? {{24{ram_data_out[7]}}, ram_data_out[7:0]} : {{24{1'b0}}, ram_data_out[7:0]};
            end
            2'b01: begin
              data_out = read_type[2] ? {{24{ram_data_out[15]}}, ram_data_out[15:8]} : {{24{1'b0}}, ram_data_out[15:8]};
            end
            2'b10: begin
              data_out = read_type[2] ? {{24{ram_data_out[23]}}, ram_data_out[23:16]} : {{24{1'b0}}, ram_data_out[23:16]};
            end
            2'b11: begin
              data_out = read_type[2] ? {{24{ram_data_out[31]}}, ram_data_out[31:24]} : {{24{1'b0}}, ram_data_out[31:24]};
            end
          endcase
        end

        3'bx10: begin  // half word
          case (address[1:0])
            2'b00: begin
              data_out = read_type[2] ? {{16{ram_data_out[15]}}, ram_data_out[15:0]} : {{16{1'b0}}, ram_data_out[15:0]};
            end
            2'b01: data_out = 0;  // ? error
            2'b10: begin
              data_out = read_type[2] ? {{16{ram_data_out[31]}}, ram_data_out[31:16]} : {{16{1'b0}}, ram_data_out[31:16]};
            end
            2'b11: data_out = 0;  // ? error
          endcase
        end

        3'b111: begin  // word
          // ? assert(addr_lower_w==0)
          data_out = ram_data_out;
        end

        default: begin
          data_out = 0;
        end

      endcase
    end
  end

  // enable to start sending and disable to acknowledge that data has been sent
  reg uarttx_go;

  // high if UartTx is busy sending
  wire uarttx_bsy;

  // data ready
  wire uartrx_dr;

  // data that is being read by UartRx
  wire [7:0] uartrx_data;

  // enable to start receiving and disable to acknowledge that received data has been read
  reg uartrx_go;

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      led <= 4'b1111;  // turn off all LEDs
      uarttx_data_sending <= 0;
      uarttx_go <= 0;
      uartrx_data_received <= 0;
      uartrx_go <= 1;
    end else begin
      // if read from UART then reset the read data
      if (address == ADDRESS_UART_IN && read_type[1:0] == 2'b01) begin
        uartrx_data_received <= 0;
      end else if (uartrx_go && uartrx_dr) begin
        // ?? unclear why this must be in an 'else if'
        // // if UART has data ready then copy the data and acknowledge (uartrx_go = 0)
        // // note: read data can be overrun
        // if (uartrx_data_received != 0) begin
        //   led <= 4'b1010;
        // end
        // if (uartrx_data == 0) begin
        //   led <= 4'b0101;
        // end
        uartrx_data_received <= uartrx_data;
        uartrx_go <= 0;
      end
      // if previous cycle acknowledged receiving data
      //  then start receiving next data (uartrx_go = 1)
      if (!uartrx_go) begin
        uartrx_go <= 1;
      end
      // if UART is done sending data then acknowledge (uarttx_go = 0)
      if (uarttx_go && !uarttx_bsy) begin
        uarttx_go <= 0;
        uarttx_data_sending <= 0;
      end
      // if writing to UART out
      if (address == ADDRESS_UART_OUT && write_type == 2'b01) begin
        uarttx_data_sending <= data_in[7:0];
        uarttx_go <= 1;
      end
      // if writing to LEDs
      if (address == ADDRESS_LED && write_type == 2'b01) begin
        led <= data_in[3:0];
      end
    end
  end

  Cache #(
      .LINE_IX_BITWIDTH(CACHE_LINE_IX_BITWIDTH),
      .RAM_DEPTH_BITWIDTH(RAM_DEPTH_BITWIDTH),
      .RAM_ADDRESSING_MODE(RAM_ADDRESSING_MODE)  // 64 bit words
  ) cache (
      .rst_n(rst_n),
      .clk  (clk),

      .enable(ram_enable),
      .address(ram_address),
      .data_out(ram_data_out),
      .data_out_ready(ram_data_out_ready),
      .data_in(ram_data_in),
      .write_enable(ram_write_enable),
      .busy(ram_busy),

      // burst ram wiring; prefix 'br_'
      .br_cmd(br_cmd),
      .br_cmd_en(br_cmd_en),
      .br_addr(br_addr),
      .br_wr_data(br_wr_data),
      .br_data_mask(br_data_mask),
      .br_rd_data(br_rd_data),
      .br_rd_data_valid(br_rd_data_valid)
  );

  UartTx #(
      .CLK_FREQ (CLK_FREQ),
      .BAUD_RATE(BAUD_RATE)
  ) uarttx (
      .rst_n(rst_n),
      .clk  (clk),

      .data(uarttx_data_sending),  // data to send
      .go(uarttx_go),  // enable to start transmission, disable after 'data' has been read
      .tx(uart_tx),  // uart tx wire
      .bsy(uarttx_bsy)  // enabled while sendng
  );

  UartRx #(
      .CLK_FREQ (CLK_FREQ),
      .BAUD_RATE(BAUD_RATE)
  ) uartrx (
      .rst_n(rst_n),
      .clk  (clk),

      .rx(uart_rx),  // uart rx wire
      .go(uartrx_go),  // enable to start receiving, disable to acknowledge 'dr'
      .data(uartrx_data),  // current data being received, is incomplete until 'dr' is enabled
      .dr(uartrx_dr)  // enabled when data is ready
  );

endmodule

`undef DBG
`undef INFO
`default_nettype wire
