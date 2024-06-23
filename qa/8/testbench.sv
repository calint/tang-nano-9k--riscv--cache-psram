//
// ramio (bug fix #2)
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

  logic br_cmd;
  logic br_cmd_en;
  logic [RAM_ADDRESS_BIT_WIDTH-1:0] br_addr;
  logic [63:0] br_wr_data;
  logic [7:0] br_data_mask;
  logic [63:0] br_rd_data;
  logic br_rd_data_valid;
  logic br_init_calib;
  logic br_busy;

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

  logic enable = 0;
  logic [1:0] write_type = 0;
  logic [2:0] read_type = 0;
  logic [31:0] address = 0;
  logic [31:0] data_out;
  logic data_out_ready;
  logic [31:0] data_in = 0;
  logic busy;
  logic [5:0] led;
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

    // poll UART tx
    address <= 32'hffff_fffe;
    read_type <= 3'b001;  // read unsigned byte
    write_type <= 2'b00;  // disable write
    enable <= 1;
    #clk_tk;
    #clk_tk;

    while (!data_out_ready) #clk_tk;

    assert (data_out == 0)
    else $error();

    $finish;

  end

endmodule

`default_nettype wire
