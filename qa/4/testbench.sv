//
// ramio + burst_ram + uartrx + uarttx
//
`timescale 1ns / 1ps
//
`default_nettype none

module testbench;

  localparam int unsigned RAM_ADDRESS_BIT_WIDTH = 4;  // 2 ^ 4 * 8 B = 128 B

  localparam int unsigned UART_OUT_ADDRESS = 32'hffff_fff8;
  localparam int unsigned UART_IN_ADDRESS = 32'hffff_fff4;

  logic rst_n;
  logic clk = 1;
  localparam int unsigned clk_tk = 10;
  always #(clk_tk / 2) clk = ~clk;

  //------------------------------------------------------------------------
  // burst_ram
  //------------------------------------------------------------------------

  // wires between 'burst_ram' and 'cache'
  wire br_cmd;
  wire br_cmd_en;
  wire [RAM_ADDRESS_BIT_WIDTH-1:0] br_addr;
  wire [63:0] br_wr_data;
  wire [7:0] br_data_mask;
  wire [63:0] br_rd_data;
  wire br_rd_data_valid;
  wire br_init_calib;
  wire br_busy;

  burst_ram #(
      .DataFilePath("ram.mem"),  // initial RAM content
      .AddressBitWidth(RAM_ADDRESS_BIT_WIDTH),  // 2 ^ 4 * 8 B entries
      .BurstDataCount(4),  // 4 * 64 bit data per burst
      .CyclesBeforeDataValid(6)
  ) burst_ram (
      .clk,
      .rst_n,
      .cmd(br_cmd),  // 0: read, 1: write
      .cmd_en(br_cmd_en),  // 1: cmd and addr is valid
      .addr(br_addr),  // 8 bytes word
      .wr_data(br_wr_data),  // data to write
      .data_mask(br_data_mask),  // not implemented (same as 0 in IP component)
      .rd_data(br_rd_data),  // read data
      .rd_data_valid(br_rd_data_valid),  // rd_data is valid
      .init_calib(br_init_calib),
      .busy(br_busy)
  );

  //------------------------------------------------------------------------
  // ramio
  //------------------------------------------------------------------------

  logic enable = 0;
  logic [1:0] write_type = 0;
  logic [2:0] read_type = 0;
  logic [31:0] address = 0;
  wire [31:0] data_out;
  wire data_out_ready;
  logic [31:0] data_in = 0;
  wire busy;
  logic [5:0] led;
  wire uart_tx;
  logic uart_rx = 1;

  ramio #(
      .RamAddressBitWidth(RAM_ADDRESS_BIT_WIDTH),
      .RamAddressingMode(3),  // 64 bit word RAM
      .CacheLineIndexBitWidth(1),
      .ClockFrequencyHz(20_250_000),
      .BaudRate(20_250_000 / 2)
  ) ramio (
      .rst_n(rst_n && br_init_calib),
      .clk,
      .enable,
      .write_type,
      .read_type,
      .address,
      .data_in,
      .data_out,
      .data_out_ready,
      .busy,
      .led  (led[3:0]),
      .uart_tx,
      .uart_rx,

      // burst RAM wiring; prefix 'br_'
      .br_cmd,  // 0: read, 1: write
      .br_cmd_en,  // 1: cmd and addr is valid
      .br_addr,  // see 'RAM_ADDRESSING_MODE'
      .br_wr_data,  // data to write
      .br_data_mask,  // always 0 meaning write all bytes
      .br_rd_data,  // data out
      .br_rd_data_valid  // rd_data is valid
  );

  //------------------------------------------------------------------------

  initial begin
    $dumpfile("log.vcd");
    $dumpvars(0, testbench);

    rst_n <= 0;
    #clk_tk;
    #clk_tk;
    rst_n <= 1;
    #clk_tk;

    // wait for burst RAM to initiate
    while (br_busy) #clk_tk;

    data_in <= 0;

    // read; cache miss
    address <= 16;
    read_type <= 3'b111;  // read full word
    write_type <= 2'b00;  // disable write
    enable <= 1;
    #clk_tk;

    while (!data_out_ready) #clk_tk;

    assert (data_out == 32'hD5B8A9C4)
    else $fatal;

    // read unsigned byte; cache hit
    address <= 17;
    read_type <= 3'b001;
    write_type <= 2'b00;
    enable <= 1;
    #clk_tk;

    while (!data_out_ready) #clk_tk;

    assert (data_out == 32'h0000_00A9)
    else $fatal;

    // read unsigned short; cache hit
    address <= 18;
    read_type <= 3'b010;
    write_type <= 2'b00;
    enable <= 1;
    #clk_tk;

    while (!data_out_ready) #clk_tk;

    assert (data_out == 32'h0000_D5B8)
    else $fatal;

    // write unsigned byte; cache hit
    enable <= 1;
    read_type <= 0;
    write_type <= 2'b01;
    address <= 17;
    data_in <= 32'hab;
    #clk_tk;
    while (busy) #clk_tk;

    // read unsigned byte; cache hit
    enable <= 1;
    address <= 17;
    read_type <= 3'b001;
    write_type <= 0;
    #clk_tk;

    while (!data_out_ready) #clk_tk;

    assert (data_out == 32'h0000_00ab)
    else $fatal;

    // write half-word; cache hit
    enable <= 1;
    read_type <= 0;
    write_type <= 2'b10;
    address <= 18;
    data_in <= 32'h1234;
    #clk_tk;
    while (busy) #clk_tk;

    // read unsigned half-word; cache hit
    enable <= 1;
    address <= 18;
    read_type <= 3'b010;
    write_type <= 0;
    #clk_tk;

    while (!data_out_ready) #clk_tk;

    assert (data_out == 32'h0000_1234)
    else $fatal;

    // write word; cache hit
    enable <= 1;
    read_type <= 0;
    write_type <= 2'b11;
    address <= 20;
    data_in <= 32'habcd_1234;
    #clk_tk;
    while (busy) #clk_tk;

    // read word; cache hit
    enable <= 1;
    address <= 20;
    read_type <= 3'b111;
    write_type <= 0;
    #clk_tk;

    while (!data_out_ready) #clk_tk;

    assert (data_out == 32'habcd_1234)
    else $fatal;

    // assert UART tx to be idle
    enable <= 1;
    address <= UART_OUT_ADDRESS;
    read_type <= 3'b111;
    write_type <= 0;
    #clk_tk;
    assert (data_out == -1)
    else $fatal;

    // write to UART
    enable <= 1;
    address <= UART_OUT_ADDRESS;
    read_type <= 0;
    write_type <= 3'b001;
    data_in <= 8'b1010_1010;
    #clk_tk;

    // poll UART tx for done
    enable <= 1;
    address <= UART_OUT_ADDRESS;
    read_type <= 3'b111;
    write_type <= 0;
    #clk_tk;

    #clk_tk;
    // uarttx starts sending

    // start bit
    assert (uart_tx == 0)
    else $fatal;
    #clk_tk;
    // bit 0
    #clk_tk;
    assert (uart_tx == 0)
    else $fatal;
    #clk_tk;
    // bit 1
    #clk_tk;
    assert (uart_tx == 1)
    else $fatal;
    #clk_tk;
    // bit 2
    #clk_tk;
    assert (uart_tx == 0)
    else $fatal;
    #clk_tk;
    // bit 3
    #clk_tk;
    assert (uart_tx == 1)
    else $fatal;
    #clk_tk;
    // bit 4
    #clk_tk;
    assert (uart_tx == 0)
    else $fatal;
    #clk_tk;
    // bit 5
    #clk_tk;
    assert (uart_tx == 1)
    else $fatal;
    #clk_tk;
    // bit 6
    #clk_tk;
    assert (uart_tx == 0)
    else $fatal;
    #clk_tk;
    // bit 7
    #clk_tk;
    assert (uart_tx == 1)
    else $fatal;
    #clk_tk;
    // stop bit
    #clk_tk;
    assert (uart_tx == 1)
    else $fatal;
    #clk_tk;

    // uarttx sets 'busy' low
    #clk_tk;

    assert (ramio.uarttx.busy == 0)
    else $fatal;

    // ramio sets 'go' low to acknowledge 'bsy' 0
    #clk_tk;

    assert (ramio.uarttx_data_sending == -1)
    else $fatal;

    assert (data_out == -1)
    else $fatal;

    // start bit
    uart_rx <= 0;
    #clk_tk;
    #clk_tk;
    // bit 0
    uart_rx <= 0;
    #clk_tk;
    #clk_tk;
    // bit 1
    uart_rx <= 1;
    #clk_tk;
    #clk_tk;
    // bit 2
    uart_rx <= 0;
    #clk_tk;
    #clk_tk;
    // bit 3
    uart_rx <= 1;
    #clk_tk;
    #clk_tk;
    // bit 4
    uart_rx <= 0;
    #clk_tk;
    #clk_tk;
    // bit 5
    uart_rx <= 1;
    #clk_tk;
    #clk_tk;
    // bit 6
    uart_rx <= 0;
    #clk_tk;
    #clk_tk;
    // bit 7
    uart_rx <= 1;
    #clk_tk;
    #clk_tk;
    // stop bit
    uart_rx <= 1;
    #clk_tk;
    #clk_tk;

    assert (data_out == -1)
    else $fatal;

    #clk_tk;  // 'ramio' transfers data from 'uartrx'

    assert (ramio.uartrx_data_ready && ramio.uartrx_data == 8'haa)
    else $fatal;

    // read from UART
    enable <= 1;
    address <= UART_IN_ADDRESS;
    read_type <= 3'b001;
    write_type <= 0;
    #clk_tk;

    assert (data_out[7:0] == 8'haa)
    else $fatal;

    // 'ramio' has cleared data from 'uartrx' and now returns -1

    // read from UART again, should be -1
    enable <= 1;
    address <= UART_IN_ADDRESS;
    read_type <= 3'b001;
    write_type <= 0;
    #clk_tk;

    assert (data_out == -1)
    else $fatal;

    // write unsigned byte; cache miss, eviction
    enable <= 1;
    read_type <= 0;
    write_type <= 2'b01;
    address <= 81;
    data_in <= 32'hab;
    #clk_tk;
    while (busy) #clk_tk;

    // read unsigned byte; cache hit
    enable <= 1;
    address <= 81;
    read_type <= 3'b001;
    write_type <= 0;
    #clk_tk;

    while (!data_out_ready) #clk_tk;

    assert (data_out == 32'h0000_00ab)
    else $fatal;

    // write half-word; cache hit
    enable <= 1;
    read_type <= 0;
    write_type <= 2'b10;
    address <= 82;
    data_in <= 32'h1234;
    #clk_tk;
    while (busy) #clk_tk;

    // read unsigned half-word; cache hit
    enable <= 1;
    address <= 82;
    read_type <= 3'b010;
    write_type <= 0;
    #clk_tk;

    while (!data_out_ready) #clk_tk;

    assert (data_out == 32'h0000_1234)
    else $fatal;

    // write word; cache hit
    enable <= 1;
    read_type <= 0;
    write_type <= 2'b11;
    address <= 84;
    data_in <= 32'habcd_1234;
    #clk_tk;
    while (busy) #clk_tk;

    // read word; cache hit
    enable <= 1;
    address <= 84;
    read_type <= 3'b111;
    write_type <= 0;
    #clk_tk;

    while (!data_out_ready) #clk_tk;

    assert (data_out == 32'habcd_1234)
    else $fatal;

    #clk_tk;
    #clk_tk;
    #clk_tk;
    #clk_tk;
    #clk_tk;
    #clk_tk;
    #clk_tk;
    #clk_tk;
    #clk_tk;

    $display("");
    $display("PASSED");
    $display("");
    $finish;
  end

endmodule

`default_nettype wire
