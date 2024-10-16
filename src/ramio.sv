//
// Interface to RAM, UART and LEDs
//
// reviewed 2024-06-25
//
`timescale 100ps / 100ps
//
`default_nettype none
// `define DBG
// `define INFO

module ramio #(
    parameter int unsigned RamAddressBitWidth = 10,
    // passed to 'cache': backing burst RAM depth

    parameter int unsigned RamAddressingMode = 3,
    // passed to 'cache': address refers to:
    //  0: byte, 1: half word, 2: word, 3: double word

    parameter int unsigned CacheLineIndexBitWidth = 1,
    // passed to 'cache': 2 ^ value * 32 B cache size

    parameter int unsigned AddressBitWidth = 32,
    // client address bit width

    parameter int unsigned DataBitWidth = 32,
    // client data bit width

    parameter int unsigned ClockFrequencyHz = 20_250_000,
    // passed to 'uartrx' and 'uarttx'

    parameter int unsigned BaudRate = 9600,
    // passed to 'uartrx' and 'uarttx'

    parameter int unsigned TopAddress = {AddressBitWidth{1'b1}},
    // last addressable byte

    parameter int unsigned AddressLed = TopAddress,
    // 4 LEDs in the lower nibble of the byte
    //  write only with 'sb'

    parameter int unsigned AddressUartOut = TopAddress - 1,
    // note: byte must be read / written with 'lb' or 'lbu'

    parameter int unsigned AddressUartIn = TopAddress - 2
    // note: received byte must be read with 'lb' or 'lbu'
    //       received byte is set to 0 after read
) (
    input wire rst_n,
    input wire clk,

    input wire enable,

    input wire [2:0] read_type,
    // b000 not a read; bit[2] flags sign extended or not, b01: byte, b10: half word, b11: word

    input wire [1:0] write_type,
    // b00 not a write; b01: byte, b10: half word, b11: word

    input wire [AddressBitWidth-1:0] address,
    // byte address (type aligned)

    input wire [DataBitWidth-1:0] data_in,
    // byte, half word, word

    output logic [DataBitWidth-1:0] data_out,
    // data at 'address' according to 'read_type'

    output logic data_out_ready,

    output logic busy,

    output logic [3:0] led,
    // I/O mapping of LEDs

    output logic uart_tx,
    input  wire  uart_rx,

    // burst RAM wiring; prefix 'br_'
    output logic br_cmd,  // 0: read, 1: write
    output logic br_cmd_en,  // 1: cmd and addr is valid
    output logic [RamAddressBitWidth-1:0] br_addr,  // see 'RamAddressingMode'
    output logic [63:0] br_wr_data,  // data to write
    output logic [7:0] br_data_mask,  // always 0 meaning write all bytes
    input wire [63:0] br_rd_data,  // data out
    input wire br_rd_data_valid  // rd_data is valid
);

  logic cache_enable;
  // enables / disables 'cache' RAM operation

  logic [DataBitWidth-1:0] cache_data_out;
  logic cache_data_out_ready;
  logic cache_busy;

  logic [AddressBitWidth-1:0] cache_address;
  // 4-byte aligned address to RAM data

  logic [DataBitWidth-1:0] cache_data_in;
  // data for byte enabled write of 4-byte word

  logic [3:0] cache_write_enable;
  // bytes in the word enabled for writing; default 4-bytes in a word

  // forward 'busy' and 'data ready' signals from cache unless it is I/O
  assign busy = address == AddressUartOut || 
                address == AddressUartIn || 
                address == AddressLed 
                ? 0 : cache_busy;

  assign data_out_ready = address == AddressUartOut || 
                          address == AddressUartIn ||
                          address == AddressLed
                          ? 1 : cache_data_out_ready;

  //
  // cache write
  //  convert 'data_in' using 'write_type' to byte enabled 4-bytes word write to cache
  // 
  always_comb begin
    // convert address to 4-byte word aligned addressing in RAM
    cache_address = {address[AddressBitWidth-1:2], 2'b00};

    // initiate result
    cache_enable = 0;
    cache_write_enable = 0;
    cache_data_in = 0;

    if (enable) begin
      if (address == AddressUartOut || address == AddressUartIn || address == AddressLed) begin
        // don't trigger cache when accessing I/O
      end else begin
        cache_enable = 1;
        // note: could be done in either 'always_comb', however this block checks
        //  address with both UART and LED

        // convert input to cache interface expected byte enabled 4-bytes word
        unique case (write_type)
          2'b01: begin  // byte
            unique case (address[1:0])
              2'b00: begin
                cache_write_enable = 4'b0001;
                cache_data_in[7:0] = data_in[7:0];
              end
              2'b01: begin
                cache_write_enable  = 4'b0010;
                cache_data_in[15:8] = data_in[7:0];
              end
              2'b10: begin
                cache_write_enable   = 4'b0100;
                cache_data_in[23:16] = data_in[7:0];
              end
              2'b11: begin
                cache_write_enable   = 4'b1000;
                cache_data_in[31:24] = data_in[7:0];
              end
            endcase
          end
          2'b10: begin  // half word
            unique case (address[1:0])
              2'b00: begin
                cache_write_enable  = 4'b0011;
                cache_data_in[15:0] = data_in[15:0];
              end
              2'b01: ;  // ? error
              2'b10: begin
                cache_write_enable   = 4'b1100;
                cache_data_in[31:16] = data_in[15:0];
              end
              2'b11: ;  // ? error
            endcase
          end
          2'b11: begin  // word
            // ? assert(addr_lower_w==0)
            cache_write_enable = 4'b1111;
            cache_data_in = data_in;
          end
          default: ;  // ? error
        endcase
      end
    end
  end

  logic [7:0] uarttx_data_sending;
  // data being sent by 'uarttx'

  logic [7:0] uartrx_data_received;
  // data copied from 'uartrx_data' when 'uartrx_data_ready' asserted

  // 
  // cache read
  //  convert 'cache_data_out' according to 'read_type' and handle UART read requests
  //
  always_comb begin
`ifdef DBG
    $display("address: %h  read_type: %b", address, read_type);
`endif
    // create the 'data_out' based on the 'address'
    data_out = 0;
    if (enable) begin
      if (address == AddressUartOut && read_type[1:0] == 2'b01) begin
        // if read byte from 'uarttx' (read_type[2] flags signed)
        data_out = read_type[2] ? 
                    {{24{uarttx_data_sending[7]}}, uarttx_data_sending} : 
                    {{24{1'b0}}, uarttx_data_sending};

      end else if (address == AddressUartIn && read_type[1:0] == 2'b01) begin
        // if read byte from 'uartrx' (read_type[2] flags signed)
        data_out = read_type[2] ? 
                    {{24{uartrx_data_received[7]}}, uartrx_data_received} :
                    {{24{1'b0}}, uartrx_data_received};

      end else begin
        // read from ram
        unique casez (read_type)
          3'b?01: begin  // byte
            unique case (address[1:0])
              2'b00: begin
                data_out = read_type[2] ? 
              {{24{cache_data_out[7]}}, cache_data_out[7:0]} :
              {{24{1'b0}}, cache_data_out[7:0]};
              end
              2'b01: begin
                data_out = read_type[2] ? 
              {{24{cache_data_out[15]}}, cache_data_out[15:8]} :
              {{24{1'b0}}, cache_data_out[15:8]};
              end
              2'b10: begin
                data_out = read_type[2] ? 
              {{24{cache_data_out[23]}}, cache_data_out[23:16]} :
              {{24{1'b0}}, cache_data_out[23:16]};
              end
              2'b11: begin
                data_out = read_type[2] ? 
              {{24{cache_data_out[31]}}, cache_data_out[31:24]} :
              {{24{1'b0}}, cache_data_out[31:24]};
              end
            endcase
          end

          3'b?10: begin  // half word
            unique case (address[1:0])
              2'b00: begin
                data_out = read_type[2] ? 
              {{16{cache_data_out[15]}}, cache_data_out[15:0]} :
              {{16{1'b0}}, cache_data_out[15:0]};
              end
              2'b01: data_out = 0;  // ? error
              2'b10: begin
                data_out = read_type[2] ? 
              {{16{cache_data_out[31]}}, cache_data_out[31:16]} :
              {{16{1'b0}}, cache_data_out[31:16]};
              end
              2'b11: data_out = 0;  // ? error
            endcase
          end

          3'b111: begin  // word
            // ? assert(addr_lower_w==0)
            data_out = cache_data_out;
          end

          default: ;
        endcase
      end
    end
  end

  logic uarttx_go;
  // enable to start sending and disable to acknowledge that data has been sent

  logic uarttx_bsy;
  // enabled when 'uarttx' is busy sending, low when done (assert with uarttx_go = 0)

  logic uartrx_data_ready;

  logic [7:0] uartrx_data;
  // data being read by 'uartrx'

  logic uartrx_go;
  // enable to start receiving
  //  disable to acknowledge that received data has been read from 'uartrx'

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      led <= 4'b1111;  // turn off all LEDs
      uarttx_data_sending <= 0;
      uarttx_go <= 0;
      uartrx_data_received <= 0;
      uartrx_go <= 1;
    end else begin
      // if read from UART then reset the read data
      if (address == AddressUartIn && read_type[1:0] == 2'b01) begin
        uartrx_data_received <= 0;

      end else if (uartrx_go && uartrx_data_ready) begin
        // ?? unclear why necessary in an 'else if' instead of stand-alone 'if'
        // ??  to avoid characters being dropped from 'uartrx'

        // if UART has data ready then copy the data and acknowledge (uartrx_go = 0)
        //  note: read data can be overrun
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
      if (address == AddressUartOut && write_type == 2'b01) begin
        uarttx_data_sending <= data_in[7:0];
        uarttx_go <= 1;
      end

      // if writing to LEDs
      if (address == AddressLed && write_type == 2'b01) begin
        led <= data_in[3:0];
      end
    end
  end

  cache #(
      .LineIndexBitWidth (CacheLineIndexBitWidth),
      .RamAddressBitWidth(RamAddressBitWidth),
      .RamAddressingMode (RamAddressingMode)
  ) cache (
      .rst_n,
      .clk,

      .enable(cache_enable),
      .address(cache_address),
      .data_out(cache_data_out),
      .data_out_ready(cache_data_out_ready),
      .data_in(cache_data_in),
      .write_enable(cache_write_enable),
      .busy(cache_busy),

      // burst ram wiring; prefix 'br_'
      .br_cmd,
      .br_cmd_en,
      .br_addr,
      .br_wr_data,
      .br_data_mask,
      .br_rd_data,
      .br_rd_data_valid
  );

  uarttx #(
      .ClockFrequencyHz(ClockFrequencyHz),
      .BaudRate(BaudRate)
  ) uarttx (
      .rst_n,
      .clk,

      .tx(uart_tx),
      // UART tx wire

      .data(uarttx_data_sending),
      // data to send

      .go(uarttx_go),
      // enable to start transmission, disable after 'data' has been read

      .bsy(uarttx_bsy)
      // enabled while sendng
  );

  uartrx #(
      .ClockFrequencyHz(ClockFrequencyHz),
      .BaudRate(BaudRate)
  ) uartrx (
      .rst_n,
      .clk,

      .rx(uart_rx),
      // UART rx wire

      .go(uartrx_go),
      // enable to start receiving, disable to acknowledge 'data_ready'

      .data(uartrx_data),
      // current data being received, is incomplete until 'data_ready' asserted

      .data_ready(uartrx_data_ready)
      // enabled when a full byte of 'data' has been received
  );

endmodule

`undef DBG
`undef INFO
`default_nettype wire
