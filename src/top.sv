//
// RISC-V reduced rv32i for Tang Nano 9K
//
// reviewed 2024-06-25
//
`timescale 100ps / 100ps
//
`default_nettype none

module top (
    input wire rst_n,
    input wire clk,    // 27 MHz

    output logic [5:0] led,
    input wire uart_rx,
    output logic uart_tx,
    input wire btn1,

    output logic flash_clk,
    input  wire  flash_miso,
    output logic flash_mosi,
    output logic flash_cs,

    // magic ports for PSRAM to be inferred
    output logic [ 1:0] O_psram_ck,
    output logic [ 1:0] O_psram_ck_n,
    inout  wire  [ 1:0] IO_psram_rwds,
    inout  wire  [15:0] IO_psram_dq,
    output logic [ 1:0] O_psram_reset_n,
    output logic [ 1:0] O_psram_cs_n
);

  // ----------------------------------------------------------
  // -- Gowin_rPLL
  // ----------------------------------------------------------
  logic rpll_lock;
  logic rpll_clkout;
  logic rpll_clkoutp;
  logic rpll_clkoutd;

  Gowin_rPLL rpll (
      .clkin(clk),  // 27 MHz
      .lock(rpll_lock),
      .clkout(rpll_clkout),  // 60 MHz
      .clkoutp(rpll_clkoutp),  // clkout 60 MHz 90 degrees phased
      .clkoutd(rpll_clkoutd)  // 60 / 4 = 15 MHz
  );

  // ----------------------------------------------------------
  // -- PSRAM_Memory_Interface_HS_V2_Top
  // ----------------------------------------------------------
  wire br_memory_clk = rpll_clkout;
  wire br_memory_clk_p = rpll_clkoutp;
  wire br_clk_d = rpll_clkoutd;
  wire br_pll_lock = rpll_lock;
  logic br_clk_out;
  logic br_init_calib;
  logic br_cmd;
  logic br_cmd_en;
  logic [20:0] br_addr;
  logic [63:0] br_wr_data;
  logic [7:0] br_data_mask;
  logic [63:0] br_rd_data;
  logic br_rd_data_valid;

  PSRAM_Memory_Interface_HS_V2_Top br (
      .rst_n(rst_n),
      .clk_d(br_clk_d),
      .memory_clk(br_memory_clk),
      .memory_clk_p(br_memory_clk_p),
      .clk_out(br_clk_out),  // memory_clk / 2 = 60 / 2 = 30 MHz
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
      .O_psram_ck,
      .O_psram_ck_n,
      .IO_psram_dq,
      .IO_psram_rwds,
      .O_psram_cs_n,
      .O_psram_reset_n
  );

  localparam int unsigned CLOCK_FREQUENCY_HZ = 30_000_000;
  // note: = br_clk_out = memory_clk / 2 = 60 / 2 = 30 MHz

  // ----------------------------------------------------------
  // -- ramio
  // ----------------------------------------------------------
  logic ramio_enable;
  logic [2:0] ramio_read_type;
  logic [1:0] ramio_write_type;
  logic [31:0] ramio_address;
  logic [31:0] ramio_data_in;
  logic [31:0] ramio_data_out;
  logic ramio_data_out_ready;
  logic ramio_busy;

  ramio #(
      .RamAddressBitWidth(configuration::RAM_ADDRESS_BITWIDTH),
      .RamAddressingMode(0),  // addressing 8 bit words
      .CacheLineIndexBitWidth(configuration::CACHE_LINE_INDEX_BITWIDTH),
      .ClockFrequencyHz(CLOCK_FREQUENCY_HZ),
      .BaudRate(configuration::UART_BAUD_RATE)
  ) ramio (
      .rst_n(rst_n && rpll_lock && br_init_calib),
      .clk  (br_clk_out),

      // interface
      .enable(ramio_enable),
      .read_type(ramio_read_type),
      .write_type(ramio_write_type),
      .address(ramio_address),
      .data_in(ramio_data_in),
      .data_out(ramio_data_out),
      .data_out_ready(ramio_data_out_ready),
      .busy(ramio_busy),

      .led(led[4:1]),

      .uart_tx,
      .uart_rx,

      // burst RAM wiring; prefix 'br_'
      .br_cmd,  // 0: read, 1: write
      .br_cmd_en,  // 1: cmd and addr is valid
      .br_addr,  // see 'RamAddressingMode'
      .br_wr_data,  // data to write
      .br_data_mask,  // always 0, meaning write all bytes
      .br_rd_data,  // data out
      .br_rd_data_valid  // 'br_rd_data' is valid
  );

  // ----------------------------------------------------------
  // -- core
  // ----------------------------------------------------------

  core #(
      .StartupWaitCycles (configuration::STARTUP_WAIT_CYCLES),
      .FlashTransferBytes(configuration::FLASH_TRANSFER_BYTES)
  ) core (
      .rst_n(rst_n && rpll_lock && br_init_calib),
      .clk  (br_clk_out),
      .led  (led[0]),

      .ramio_enable,
      .ramio_read_type,
      .ramio_write_type,
      .ramio_address,
      .ramio_data_in,
      .ramio_data_out,
      .ramio_data_out_ready,
      .ramio_busy,

      .flash_clk,
      .flash_miso,
      .flash_mosi,
      .flash_cs
  );

  assign led[5] = ~ramio_busy;

endmodule

`default_nettype wire
