`timescale 100ps / 100ps
//
// RAMIO + BurstRAM
//
`default_nettype none

module TestBench;

  localparam RAM_DEPTH_BITWIDTH = 4;  // 2^4 * 8 B

  reg sys_rst_n = 0;
  reg clk = 1;
  localparam clk_tk = 36;
  always #(clk_tk / 2) clk = ~clk;

  wire br_cmd;
  wire br_cmd_en;
  wire [RAM_DEPTH_BITWIDTH-1:0] br_addr;
  wire [63:0] br_wr_data;
  wire [7:0] br_data_mask;
  wire [63:0] br_rd_data;
  wire br_rd_data_valid;
  wire br_init_calib;
  wire br_busy;

  BurstRAM #(
      .DATA_FILE("RAM.mem"),  // initial RAM content
      .DEPTH_BITWIDTH(RAM_DEPTH_BITWIDTH),  // 2 ^ 4 * 8 B entries
      .BURST_COUNT(4),  // 4 * 64 bit data per burst
      .CYCLES_BEFORE_DATA_VALID(6)
  ) burst_ram (
      .clk(clk),
      .rst_n(sys_rst_n),
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

  reg enable = 0;
  reg [1:0] write_type = 0;
  reg [2:0] read_type = 0;
  reg [31:0] address = 0;
  wire [31:0] data_out;
  wire data_out_ready;
  reg [31:0] data_in = 0;
  wire busy;
  wire [5:0] led = 0;
  reg uart_tx;
  reg uart_rx = 1;

  RAMIO #(
      .RAM_DEPTH_BITWIDTH(RAM_DEPTH_BITWIDTH),
      .RAM_ADDRESSING_MODE(3),  // 64 bit word RAM
      .CACHE_LINE_IX_BITWIDTH(1),
      .CLK_FREQ(20_250_000),
      .BAUD_RATE(20_250_000)
  ) ramio (
      .rst_n(sys_rst_n && br_init_calib),
      .clk(clk),
      .enable(enable),
      .write_type(write_type),
      .read_type(read_type),
      .address(address),
      .data_in(data_in),
      .data_out(data_out),
      .data_out_ready(data_out_ready),
      .busy(busy),
      .led(led[3:0]),
      .uart_tx(uart_tx),
      .uart_rx(uart_rx),

      // burst RAM wiring; prefix 'br_'
      .br_cmd(br_cmd),  // 0: read, 1: write
      .br_cmd_en(br_cmd_en),  // 1: cmd and addr is valid
      .br_addr(br_addr),  // see 'RAM_ADDRESSING_MODE'
      .br_wr_data(br_wr_data),  // data to write
      .br_data_mask(br_data_mask),  // always 0 meaning write all bytes
      .br_rd_data(br_rd_data),  // data out
      .br_rd_data_valid(br_rd_data_valid)  // rd_data is valid
  );

  initial begin
    $dumpfile("log.vcd");
    $dumpvars(0, TestBench);

    #clk_tk;
    #clk_tk;
    sys_rst_n <= 1;
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
    else $display("Test 1 FAILED");

    // read unsigned byte; cache hit
    address <= 17;
    read_type <= 3'b001;
    write_type <= 2'b00;
    enable <= 1;
    #clk_tk;

    while (!data_out_ready) #clk_tk;

    if (data_out == 32'h0000_00A9) $display("Test 2 passed");
    else $display("Test 2 FAILED");

    // read unsigned short; cache hit
    address <= 18;
    read_type <= 3'b010;
    write_type <= 2'b00;
    enable <= 1;
    #clk_tk;

    while (!data_out_ready) #clk_tk;

    if (data_out == 32'h0000_D5B8) $display("Test 3 passed");
    else $display("Test 3 FAILED");

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
    else $display("Test 4 FAILED");

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
    else $display("Test 5 FAILED");

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
    else $display("Test 6 FAILED");

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
    else $display("Test 7 FAILED");
    // bit 1
    #clk_tk;
    if (uart_tx == 0) $display("Test 8 passed");
    else $display("Test 8 FAILED");
    // bit 2
    #clk_tk;
    if (uart_tx == 1) $display("Test 9 passed");
    else $display("Test 9 FAILED");
    // bit 3
    #clk_tk;
    if (uart_tx == 0) $display("Test 10 passed");
    else $display("Test 10 FAILED");
    // bit 4
    #clk_tk;
    if (uart_tx == 1) $display("Test 11 passed");
    else $display("Test 11 FAILED");
    // bit 5
    #clk_tk;
    if (uart_tx == 0) $display("Test 12 passed");
    else $display("Test 12 FAILED");
    // bit 6
    #clk_tk;
    if (uart_tx == 1) $display("Test 13 passed");
    else $display("Test 13 FAILED");
    // bit 7
    #clk_tk;
    if (uart_tx == 0) $display("Test 14 passed");
    else $display("Test 14 FAILED");
    // stop bit
    #clk_tk;
    if (uart_tx == 1) $display("Test 15 passed");
    else $display("Test 15 FAILED");
    #clk_tk;
    if (uart_tx == 1) $display("Test 16 passed");
    else $display("Test 16 FAILED");

    #clk_tk;
    if (ramio.uarttx.bsy == 0) $display("Test 17 passed");
    else $display("Test 17 FAILED");

    #clk_tk;

    if (ramio.uarttx_data_sending == 0) $display("Test 18 passed");
    else $display("Test 18 FAILED");

    // read from UART
    enable <= 1;
    address <= 32'hffff_fffd;
    read_type <= 3'b001;
    write_type <= 0;
    #clk_tk;

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
    uart_rx <= 1;
    #clk_tk;

    if (ramio.uartrx_dr && ramio.uartrx_data == 8'haa) $display("Test 19 passed");
    else $display("Test 19 FAILED");

    #clk_tk; // RAMIO transfers data from UartRx

    if (data_out == 8'haa) $display("Test 20 passed");
    else $display("Test 20 FAILED");

    uart_rx <= 0;

    // read from UART again, should be 0
    enable <= 1;
    address <= 32'hffff_fffd;
    read_type <= 3'b001;
    write_type <= 0;
    #clk_tk;

    if (data_out == 0) $display("Test 21 passed");
    else $display("Test 21 FAILED");

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
    else $display("Test 22 FAILED");

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
    else $display("Test 23 FAILED");

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
    else $display("Test 24 FAILED");

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
