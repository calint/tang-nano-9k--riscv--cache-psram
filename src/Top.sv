`timescale 100ps / 100ps
//
`default_nettype none

`include "Configuration.sv"

module Top (
    input wire sys_clk,  // 27 MHz
    input wire sys_rst_n,
    output reg [5:0] led,
    input wire uart_rx,
    output wire uart_tx,
    input wire btn1,

    // magic ports for PSRAM to be inferred
    output wire [ 1:0] O_psram_ck,
    output wire [ 1:0] O_psram_ck_n,
    inout  wire [ 1:0] IO_psram_rwds,
    inout  wire [15:0] IO_psram_dq,
    output wire [ 1:0] O_psram_reset_n,
    output wire [ 1:0] O_psram_cs_n,

    // flash
    output reg  flash_clk,
    input  wire flash_miso,
    output reg  flash_mosi,
    output reg  flash_cs
);

  localparam CPU_FREQUENCY_MHZ = 37_500_000;

  // ----------------------------------------------------------
  // -- Gowin_rPLLs
  // ----------------------------------------------------------
  wire rpll_clkin = sys_clk;
  wire rpll_lock;
  wire rpll_clkout;
  wire rpll_clkoutp;
  wire rpll_clkoutd;

  Gowin_rPLL rpll (
      .clkin(rpll_clkin),  // 27 MHz
      .lock(rpll_lock),
      .clkout(rpll_clkout),  // 75 MHz
      .clkoutp(rpll_clkoutp),  // clkout 75 MHz 90 degrees phased
      .clkoutd(rpll_clkoutd)  // clkout / 4 = 18.75 MHz (IPUG943-1.2E page 15)
  );

  // ----------------------------------------------------------
  // -- PSRAM_Memory_Interface_HS_V2_Top
  // ----------------------------------------------------------
  wire br_clk_d = rpll_clkoutd;
  wire br_pll_lock = rpll_lock;
  wire br_memory_clk = rpll_clkout;
  wire br_memory_clk_p = rpll_clkoutp;
  wire br_clk_out;
  wire rst_n = sys_rst_n;
  wire [63:0] br_wr_data;
  wire [63:0] br_rd_data;
  wire br_rd_data_valid;
  wire [20:0] br_addr;
  wire br_cmd;
  wire br_cmd_en;
  wire br_init_calib;
  wire [7:0] br_data_mask;

  PSRAM_Memory_Interface_HS_V2_Top br (
      .rst_n(rst_n),
      .clk_d(br_clk_d),
      .memory_clk(br_memory_clk),
      .memory_clk_p(br_memory_clk_p),
      .clk_out(br_clk_out),  // memory_clk / 2
      .pll_lock(br_pll_lock),
      .init_calib(br_init_calib),

      .cmd(br_cmd),
      .cmd_en(br_cmd_en),
      .addr(br_addr),
      .wr_data(br_wr_data),
      .data_mask(br_data_mask),
      .rd_data(br_rd_data),
      .rd_data_valid(br_rd_data_valid),

      // inferred PSRAM ports
      .O_psram_ck(O_psram_ck),
      .O_psram_ck_n(O_psram_ck_n),
      .IO_psram_dq(IO_psram_dq),
      .IO_psram_rwds(IO_psram_rwds),
      .O_psram_cs_n(O_psram_cs_n),
      .O_psram_reset_n(O_psram_reset_n)
  );

  // ----------------------------------------------------------
  // -- RAMIO
  // ----------------------------------------------------------
  reg ramio_enable;
  reg [1:0] ramio_write_type;
  reg [2:0] ramio_read_type;
  reg [31:0] ramio_address;
  reg [31:0] ramio_data_in;
  wire [31:0] ramio_data_out;
  wire ramio_data_out_ready;
  wire ramio_busy;

  RAMIO #(
      .RAM_DEPTH_BITWIDTH(`RAM_ADDRESS_BITWIDTH),
      .RAM_ADDRESSING_MODE(0),  // addressing 8 bit words
      .CACHE_LINE_IX_BITWIDTH(`CACHE_LINE_IX_BITWIDTH),
      .CLK_FREQ(CPU_FREQUENCY_MHZ),
      .BAUD_RATE(`UART_BAUD_RATE)
  ) ramio (
      .rst_n(sys_rst_n && rpll_lock && br_init_calib),
      .clk  (br_clk_out),

      // interface
      .enable(ramio_enable),
      .write_type(ramio_write_type),
      .read_type(ramio_read_type),
      .address(ramio_address),
      .data_in(ramio_data_in),
      .data_out(ramio_data_out),
      .data_out_ready(ramio_data_out_ready),
      .busy(ramio_busy),

      .led(led[4:1]),

      // UART
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

  // ----------------------------------------------------------
  // -- Core
  // ----------------------------------------------------------

  Core core (
      .rst_n(sys_rst_n && rpll_lock && br_init_calib),
      .clk  (br_clk_out),
      .led  (led[0]),

      .ramio_enable(ramio_enable),
      .ramio_write_type(ramio_write_type),
      .ramio_read_type(ramio_read_type),
      .ramio_address(ramio_address),
      .ramio_data_in(ramio_data_in),
      .ramio_data_out(ramio_data_out),
      .ramio_data_out_ready(ramio_data_out_ready),
      .ramio_busy(ramio_busy),

      .flash_clk (flash_clk),
      .flash_miso(flash_miso),
      .flash_mosi(flash_mosi),
      .flash_cs  (flash_cs)
  );

  assign led[5] = ~ramio_busy;

endmodule

`default_nettype wire
