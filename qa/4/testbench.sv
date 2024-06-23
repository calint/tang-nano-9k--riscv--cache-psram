//
// RAMIO + BurstRAM
//
`timescale 100ps / 100ps
//
`default_nettype none

module testbench;

  localparam int unsigned RAM_ADDRESS_BIT_WIDTH = 4;  // 2^4 * 8 B

  logic rst_n;
  logic clk = 1;
  localparam int unsigned clk_tk = 36;
  always #(clk_tk / 2) clk = ~clk;

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
      .DataFilePath("RAM.mem"),  // initial RAM content
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

  logic enable = 0;
  logic [1:0] write_type = 0;
  logic [2:0] read_type = 0;
  logic [31:0] address = 0;
  wire [31:0] data_out;
  wire data_out_ready;
  logic [31:0] data_in = 0;
  wire busy;
  wire [5:0] led = 0;
  logic uart_tx;
  logic uart_rx = 1;

  ramio #(
      .RamAddressBitWidth(RAM_ADDRESS_BIT_WIDTH),
      .RamAddressingMode(3),  // 64 bit word RAM
      .CacheLineIndexBitWidth(1),
      .ClockFrequencyHz(20_250_000),
      .BaudRate(20_250_000)
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

  initial begin
    $dumpfile("log.vcd");
    $dumpvars(0, testbench);

    rst_n <= 0;
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

    if (data_out == 32'hD5B8A9C4) $display("Test 1 passed");
    else $error("Test 1 FAILED");

    // read unsigned byte; cache hit
    address <= 17;
    read_type <= 3'b001;
    write_type <= 2'b00;
    enable <= 1;
    #clk_tk;

    while (!data_out_ready) #clk_tk;

    if (data_out == 32'h0000_00A9) $display("Test 2 passed");
    else $error("Test 2 FAILED");

    // read unsigned short; cache hit
    address <= 18;
    read_type <= 3'b010;
    write_type <= 2'b00;
    enable <= 1;
    #clk_tk;

    while (!data_out_ready) #clk_tk;

    if (data_out == 32'h0000_D5B8) $display("Test 3 passed");
    else $error("Test 3 FAILED");

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

    if (data_out == 32'h0000_00ab) $display("Test 4 passed");
    else $error("Test 4 FAILED");

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

    if (data_out == 32'h0000_1234) $display("Test 5 passed");
    else $error("Test 5 FAILED");

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

    if (data_out == 32'habcd_1234) $display("Test 6 passed");
    else $error("Test 6 FAILED");

    // write to UART
    enable <= 1;
    address <= 32'hffff_fffe;
    read_type <= 0;
    write_type <= 2'b01;
    data_in <= 8'b1010_1010;
    #clk_tk;

    // poll UART tx for done
    enable <= 1;
    address <= 32'hffff_fffe;
    read_type <= 3'b001;
    write_type <= 0;

    // start bit
    #clk_tk;
    if (uart_tx == 0) $display("Test 7 passed");
    else $error("Test 7 FAILED");
    // bit 1
    #clk_tk;
    if (uart_tx == 0) $display("Test 8 passed");
    else $error("Test 8 FAILED");
    // bit 2
    #clk_tk;
    if (uart_tx == 1) $display("Test 9 passed");
    else $error("Test 9 FAILED");
    // bit 3
    #clk_tk;
    if (uart_tx == 0) $display("Test 10 passed");
    else $error("Test 10 FAILED");
    // bit 4
    #clk_tk;
    if (uart_tx == 1) $display("Test 11 passed");
    else $error("Test 11 FAILED");
    // bit 5
    #clk_tk;
    if (uart_tx == 0) $display("Test 12 passed");
    else $error("Test 12 FAILED");
    // bit 6
    #clk_tk;
    if (uart_tx == 1) $display("Test 13 passed");
    else $error("Test 13 FAILED");
    // bit 7
    #clk_tk;
    if (uart_tx == 0) $display("Test 14 passed");
    else $error("Test 14 FAILED");
    // stop bit
    #clk_tk;
    if (uart_tx == 1) $display("Test 15 passed");
    else $error("Test 15 FAILED");
    #clk_tk;
    if (uart_tx == 1) $display("Test 16 passed");
    else $error("Test 16 FAILED");

    #clk_tk;
    if (ramio.uarttx.bsy == 0) $display("Test 17 passed");
    else $error("Test 17 FAILED");

    #clk_tk;

    if (ramio.uarttx_data_sending == 0) $display("Test 18 passed");
    else $error("Test 18 FAILED");

    // start bit
    uart_rx <= 0;
    #clk_tk;
    // bit 0
    uart_rx <= 0;
    #clk_tk;
    // bit 1
    uart_rx <= 1;
    #clk_tk;
    // bit 2
    uart_rx <= 0;
    #clk_tk;
    // bit 3
    uart_rx <= 1;
    #clk_tk;
    // bit 4
    uart_rx <= 0;
    #clk_tk;
    // bit 5
    uart_rx <= 1;
    #clk_tk;
    // bit 6
    uart_rx <= 0;
    #clk_tk;
    // bit 7
    uart_rx <= 1;
    #clk_tk;
    // stop bit
    uart_rx <= 1;
    #clk_tk;

    #clk_tk;  // RAMIO transfers data from UartRx

    if (ramio.uartrx_dr && ramio.uartrx_data == 8'haa) $display("Test 19 passed");
    else $error("Test 19 FAILED");

    // read from UART
    enable <= 1;
    address <= 32'hffff_fffd;
    read_type <= 3'b001;
    write_type <= 0;
    #clk_tk;

    if (data_out == 8'haa) $display("Test 20 passed");
    else $error("Test 20 FAILED");

    #clk_tk;  // RAMIO clears data from UartRx

    // read from UART again, should be 0
    enable <= 1;
    address <= 32'hffff_fffd;
    read_type <= 3'b001;
    write_type <= 0;
    #clk_tk;

    if (data_out == 0) $display("Test 21 passed");
    else $error("Test 21 FAILED");

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

    if (data_out == 32'h0000_00ab) $display("Test 22 passed");
    else $error("Test 22 FAILED");

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

    if (data_out == 32'h0000_1234) $display("Test 23 passed");
    else $error("Test 23 FAILED");

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

    if (data_out == 32'habcd_1234) $display("Test 24 passed");
    else $error("Test 24 FAILED");

    #clk_tk;
    #clk_tk;
    #clk_tk;
    #clk_tk;
    #clk_tk;
    #clk_tk;
    #clk_tk;
    #clk_tk;
    #clk_tk;
    $finish;

  end

endmodule

`default_nettype wire
