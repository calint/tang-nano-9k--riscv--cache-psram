//
// ramio + sdcard
//
`timescale 1ns / 1ps
//
`default_nettype none

module testbench;
  localparam int unsigned RAM_ADDRESS_BIT_WIDTH = 4;  // 2 ^ 4 * 8 B = 128 B

  localparam int unsigned SD_CARD_BUSY_ADDRESS = 32'hffff_fff0;
  localparam int unsigned SD_CARD_READ_SECTOR_ADDRESS = 32'hffff_ffec;
  localparam int unsigned SD_CARD_NEXT_BYTE_ADDRESS = 32'hffff_ffe8;

  logic rst_n;
  logic clk = 1;
  localparam int unsigned clk_tk = 10;
  always #(clk_tk / 2) clk = ~clk;

  //------------------------------------------------------------------------
  // sd_fake
  //------------------------------------------------------------------------

  // wires between 'sd_fake' and 'sdcard'
  wire         sd_fake_sdclk;
  wire         sd_fake_sdcmd;
  wire  [ 3:0] sd_fake_sddat;

  wire         sd_fake_show_sdcmd_en;
  wire  [ 5:0] sd_fake_show_sdcmd_cmd;
  wire  [31:0] sd_fake_show_sdcmd_arg;

  wire         sd_fake_rom_req;
  wire  [39:0] sd_fake_rom_addr;
  logic [15:0] sd_fake_rom_data;

  sd_fake sd_fake (
      .rstn_async      (rst_n),
      .sdclk           (sd_fake_sdclk),
      .sdcmd           (sd_fake_sdcmd),
      .sddat           (sd_fake_sddat),
      .rdreq           (sd_fake_rom_req),
      .rdaddr          (sd_fake_rom_addr),
      .rddata          (sd_fake_rom_data),
      .show_status_bits(),
      .show_sdcmd_en   (sd_fake_show_sdcmd_en),
      .show_sdcmd_cmd  (sd_fake_show_sdcmd_cmd),
      .show_sdcmd_arg  (sd_fake_show_sdcmd_arg)
  );

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
      .BaudRate(20_250_000),
      .SDCardSimulate(1),
      .SDCardClockDivider(1)
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
      .br_rd_data_valid,  // rd_data is valid

      // SD card wiring
      .sd_clk (sd_fake_sdclk),
      .sd_mosi(sd_fake_sdcmd),
      .sd_miso(sd_fake_sddat[0])
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

    while (!br_init_calib) #clk_tk;

    // wait for SD card to initialize
    enable <= 1;
    address <= SD_CARD_BUSY_ADDRESS;
    write_type <= 0;
    read_type <= 3'b111;
    #clk_tk;

    assert (data_out_ready == 1)
    else $fatal;

    while (data_out == 1) #clk_tk;

    // issue read sector command
    enable <= 1;
    address <= SD_CARD_READ_SECTOR_ADDRESS;
    write_type <= 2'b11;
    read_type <= 3'b000;
    data_in <= 32'h4000;
    #clk_tk;

    assert (data_out_ready == 1)
    else $fatal;

    // wait for busy
    enable <= 1;
    address <= SD_CARD_BUSY_ADDRESS;
    write_type <= 0;
    read_type <= 3'b111;
    #clk_tk;

    assert (data_out_ready == 1)
    else $fatal;

    while (data_out == 1) #clk_tk;

    // read first byte (0) from sector
    enable <= 1;
    address <= SD_CARD_NEXT_BYTE_ADDRESS;
    write_type <= 0;
    read_type <= 3'b111;
    #clk_tk;

    assert (data_out_ready == 1)
    else $fatal;

    assert (data_out == 8'h42)
    else $fatal;

    // read next byte (1) from sector
    enable <= 1;
    address <= SD_CARD_NEXT_BYTE_ADDRESS;
    write_type <= 0;
    read_type <= 3'b111;
    #clk_tk;

    assert (data_out_ready == 1)
    else $fatal;

    assert (data_out == 8'h20)
    else $fatal;

    // read next byte (2) from sector
    enable <= 1;
    address <= SD_CARD_NEXT_BYTE_ADDRESS;
    write_type <= 0;
    read_type <= 3'b111;
    #clk_tk;

    assert (data_out_ready == 1)
    else $fatal;

    // read next byte (3) from sector
    enable <= 1;
    address <= SD_CARD_NEXT_BYTE_ADDRESS;
    write_type <= 0;
    read_type <= 3'b111;
    #clk_tk;

    assert (data_out_ready == 1)
    else $fatal;

    // read next byte (4) from sector
    enable <= 1;
    address <= SD_CARD_NEXT_BYTE_ADDRESS;
    write_type <= 0;
    read_type <= 3'b111;
    #clk_tk;

    assert (data_out_ready == 1)
    else $fatal;

    assert (data_out == 8'h00)
    else $fatal;

    // read next byte (5) from sector
    enable <= 1;
    address <= SD_CARD_NEXT_BYTE_ADDRESS;
    write_type <= 0;
    read_type <= 3'b111;
    #clk_tk;

    assert (data_out_ready == 1)
    else $fatal;

    assert (data_out == 8'h6e)
    else $fatal;

    // issue read sector command
    enable <= 1;
    address <= SD_CARD_READ_SECTOR_ADDRESS;
    write_type <= 2'b11;
    read_type <= 3'b000;
    data_in <= 32'h4040;
    #clk_tk;

    assert (data_out_ready == 1)
    else $fatal;

    // wait for busy
    enable <= 1;
    address <= SD_CARD_BUSY_ADDRESS;
    write_type <= 0;
    read_type <= 3'b111;
    #clk_tk;

    assert (data_out_ready == 1)
    else $fatal;

    while (data_out == 1) #clk_tk;

    // read first byte (0) from sector
    enable <= 1;
    address <= SD_CARD_NEXT_BYTE_ADDRESS;
    write_type <= 0;
    read_type <= 3'b111;
    #clk_tk;

    assert (data_out_ready == 1)
    else $fatal;

    assert (data_out == 8'h2e)
    else $fatal;

    // read next byte (1) from sector
    enable <= 1;
    address <= SD_CARD_NEXT_BYTE_ADDRESS;
    write_type <= 0;
    read_type <= 3'b111;
    #clk_tk;

    assert (data_out_ready == 1)
    else $fatal;

    assert (data_out == 8'h20)
    else $fatal;

    $display("");
    $display("PASSED");
    $display("");
    $finish;
  end

  //--------------------------------------------------------------------------------------------------------
  // A ROM, contains a complete FAT32 partition data mirror
  //--------------------------------------------------------------------------------------------------------
  always @(posedge sd_fake_sdclk)
    if (sd_fake_rom_req)
      case (sd_fake_rom_addr)
        40'h00000000df: sd_fake_rom_data <= 16'h8200;
        40'h00000000e0: sd_fake_rom_data <= 16'h0003;
        40'h00000000e1: sd_fake_rom_data <= 16'hd50b;
        40'h00000000e2: sd_fake_rom_data <= 16'hade8;
        40'h00000000e3: sd_fake_rom_data <= 16'h2000;
        40'h00000000e5: sd_fake_rom_data <= 16'hc000;
        40'h00000000e6: sd_fake_rom_data <= 16'h00e6;
        40'h00000000ff: sd_fake_rom_data <= 16'haa55;
        40'h0000200000: sd_fake_rom_data <= 16'h00eb;
        40'h0000200001: sd_fake_rom_data <= 16'h2090;
        40'h0000200002: sd_fake_rom_data <= 16'h2020;
        40'h0000200003: sd_fake_rom_data <= 16'h2020;
        40'h0000200004: sd_fake_rom_data <= 16'h2020;
        40'h0000200005: sd_fake_rom_data <= 16'h0020;
        40'h0000200006: sd_fake_rom_data <= 16'h4002;
        40'h0000200007: sd_fake_rom_data <= 16'h1194;
        40'h0000200008: sd_fake_rom_data <= 16'h0002;
        40'h000020000a: sd_fake_rom_data <= 16'hf800;
        40'h000020000c: sd_fake_rom_data <= 16'h003f;
        40'h000020000d: sd_fake_rom_data <= 16'h00ff;
        40'h000020000e: sd_fake_rom_data <= 16'h2000;
        40'h0000200010: sd_fake_rom_data <= 16'hc000;
        40'h0000200011: sd_fake_rom_data <= 16'h00e6;
        40'h0000200012: sd_fake_rom_data <= 16'h0736;
        40'h0000200016: sd_fake_rom_data <= 16'h0002;
        40'h0000200018: sd_fake_rom_data <= 16'h0001;
        40'h0000200019: sd_fake_rom_data <= 16'h0006;
        40'h0000200020: sd_fake_rom_data <= 16'h0080;
        40'h0000200021: sd_fake_rom_data <= 16'h5929;
        40'h0000200022: sd_fake_rom_data <= 16'he22a;
        40'h0000200023: sd_fake_rom_data <= 16'h4e19;
        40'h0000200024: sd_fake_rom_data <= 16'h204f;
        40'h0000200025: sd_fake_rom_data <= 16'h414e;
        40'h0000200026: sd_fake_rom_data <= 16'h454d;
        40'h0000200027: sd_fake_rom_data <= 16'h2020;
        40'h0000200028: sd_fake_rom_data <= 16'h2020;
        40'h0000200029: sd_fake_rom_data <= 16'h4146;
        40'h000020002a: sd_fake_rom_data <= 16'h3354;
        40'h000020002b: sd_fake_rom_data <= 16'h2032;
        40'h000020002c: sd_fake_rom_data <= 16'h2020;
        40'h00002000ff: sd_fake_rom_data <= 16'haa55;
        40'h0000200100: sd_fake_rom_data <= 16'h5252;
        40'h0000200101: sd_fake_rom_data <= 16'h4161;
        40'h00002001f2: sd_fake_rom_data <= 16'h7272;
        40'h00002001f3: sd_fake_rom_data <= 16'h6141;
        40'h00002001f4: sd_fake_rom_data <= 16'h9a7b;
        40'h00002001f5: sd_fake_rom_data <= 16'h0003;
        40'h00002001f6: sd_fake_rom_data <= 16'h0007;
        40'h00002001ff: sd_fake_rom_data <= 16'haa55;
        40'h00002002ff: sd_fake_rom_data <= 16'haa55;
        40'h0000200600: sd_fake_rom_data <= 16'h00eb;
        40'h0000200601: sd_fake_rom_data <= 16'h2090;
        40'h0000200602: sd_fake_rom_data <= 16'h2020;
        40'h0000200603: sd_fake_rom_data <= 16'h2020;
        40'h0000200604: sd_fake_rom_data <= 16'h2020;
        40'h0000200605: sd_fake_rom_data <= 16'h0020;
        40'h0000200606: sd_fake_rom_data <= 16'h4002;
        40'h0000200607: sd_fake_rom_data <= 16'h1194;
        40'h0000200608: sd_fake_rom_data <= 16'h0002;
        40'h000020060a: sd_fake_rom_data <= 16'hf800;
        40'h000020060c: sd_fake_rom_data <= 16'h003f;
        40'h000020060d: sd_fake_rom_data <= 16'h00ff;
        40'h000020060e: sd_fake_rom_data <= 16'h2000;
        40'h0000200610: sd_fake_rom_data <= 16'hc000;
        40'h0000200611: sd_fake_rom_data <= 16'h00e6;
        40'h0000200612: sd_fake_rom_data <= 16'h0736;
        40'h0000200616: sd_fake_rom_data <= 16'h0002;
        40'h0000200618: sd_fake_rom_data <= 16'h0001;
        40'h0000200619: sd_fake_rom_data <= 16'h0006;
        40'h0000200620: sd_fake_rom_data <= 16'h0080;
        40'h0000200621: sd_fake_rom_data <= 16'h5929;
        40'h0000200622: sd_fake_rom_data <= 16'he22a;
        40'h0000200623: sd_fake_rom_data <= 16'h4e19;
        40'h0000200624: sd_fake_rom_data <= 16'h204f;
        40'h0000200625: sd_fake_rom_data <= 16'h414e;
        40'h0000200626: sd_fake_rom_data <= 16'h454d;
        40'h0000200627: sd_fake_rom_data <= 16'h2020;
        40'h0000200628: sd_fake_rom_data <= 16'h2020;
        40'h0000200629: sd_fake_rom_data <= 16'h4146;
        40'h000020062a: sd_fake_rom_data <= 16'h3354;
        40'h000020062b: sd_fake_rom_data <= 16'h2032;
        40'h000020062c: sd_fake_rom_data <= 16'h2020;
        40'h00002006ff: sd_fake_rom_data <= 16'haa55;
        40'h0000200700: sd_fake_rom_data <= 16'h5252;
        40'h0000200701: sd_fake_rom_data <= 16'h4161;
        40'h00002007f2: sd_fake_rom_data <= 16'h7272;
        40'h00002007f3: sd_fake_rom_data <= 16'h6141;
        40'h00002007f4: sd_fake_rom_data <= 16'hffff;
        40'h00002007f5: sd_fake_rom_data <= 16'hffff;
        40'h00002007f6: sd_fake_rom_data <= 16'hffff;
        40'h00002007f7: sd_fake_rom_data <= 16'hffff;
        40'h00002007ff: sd_fake_rom_data <= 16'haa55;
        40'h00002008ff: sd_fake_rom_data <= 16'haa55;
        40'h0000319400: sd_fake_rom_data <= 16'hfff8;
        40'h0000319401: sd_fake_rom_data <= 16'h0fff;
        40'h0000319402: sd_fake_rom_data <= 16'hffff;
        40'h0000319403: sd_fake_rom_data <= 16'hffff;
        40'h0000319404: sd_fake_rom_data <= 16'hffff;
        40'h0000319405: sd_fake_rom_data <= 16'h0fff;
        40'h0000319406: sd_fake_rom_data <= 16'hffff;
        40'h0000319407: sd_fake_rom_data <= 16'h0fff;
        40'h0000319408: sd_fake_rom_data <= 16'hffff;
        40'h0000319409: sd_fake_rom_data <= 16'h0fff;
        40'h000031940a: sd_fake_rom_data <= 16'hffff;
        40'h000031940b: sd_fake_rom_data <= 16'h0fff;
        40'h000031940c: sd_fake_rom_data <= 16'hffff;
        40'h000031940d: sd_fake_rom_data <= 16'h0fff;
        40'h000038ca00: sd_fake_rom_data <= 16'hfff8;
        40'h000038ca01: sd_fake_rom_data <= 16'h0fff;
        40'h000038ca02: sd_fake_rom_data <= 16'hffff;
        40'h000038ca03: sd_fake_rom_data <= 16'hffff;
        40'h000038ca04: sd_fake_rom_data <= 16'hffff;
        40'h000038ca05: sd_fake_rom_data <= 16'h0fff;
        40'h000038ca06: sd_fake_rom_data <= 16'hffff;
        40'h000038ca07: sd_fake_rom_data <= 16'h0fff;
        40'h000038ca08: sd_fake_rom_data <= 16'hffff;
        40'h000038ca09: sd_fake_rom_data <= 16'h0fff;
        40'h000038ca0a: sd_fake_rom_data <= 16'hffff;
        40'h000038ca0b: sd_fake_rom_data <= 16'h0fff;
        40'h000038ca0c: sd_fake_rom_data <= 16'hffff;
        40'h000038ca0d: sd_fake_rom_data <= 16'h0fff;
        40'h0000400000: sd_fake_rom_data <= 16'h2042;
        40'h0000400001: sd_fake_rom_data <= 16'h4900;
        40'h0000400002: sd_fake_rom_data <= 16'h6e00;
        40'h0000400003: sd_fake_rom_data <= 16'h6600;
        40'h0000400004: sd_fake_rom_data <= 16'h6f00;
        40'h0000400005: sd_fake_rom_data <= 16'h0f00;
        40'h0000400006: sd_fake_rom_data <= 16'h7200;
        40'h0000400007: sd_fake_rom_data <= 16'h0072;
        40'h0000400008: sd_fake_rom_data <= 16'h006d;
        40'h0000400009: sd_fake_rom_data <= 16'h0061;
        40'h000040000a: sd_fake_rom_data <= 16'h0074;
        40'h000040000b: sd_fake_rom_data <= 16'h0069;
        40'h000040000c: sd_fake_rom_data <= 16'h006f;
        40'h000040000e: sd_fake_rom_data <= 16'h006e;
        40'h0000400010: sd_fake_rom_data <= 16'h5301;
        40'h0000400011: sd_fake_rom_data <= 16'h7900;
        40'h0000400012: sd_fake_rom_data <= 16'h7300;
        40'h0000400013: sd_fake_rom_data <= 16'h7400;
        40'h0000400014: sd_fake_rom_data <= 16'h6500;
        40'h0000400015: sd_fake_rom_data <= 16'h0f00;
        40'h0000400016: sd_fake_rom_data <= 16'h7200;
        40'h0000400017: sd_fake_rom_data <= 16'h006d;
        40'h0000400018: sd_fake_rom_data <= 16'h0020;
        40'h0000400019: sd_fake_rom_data <= 16'h0056;
        40'h000040001a: sd_fake_rom_data <= 16'h006f;
        40'h000040001b: sd_fake_rom_data <= 16'h006c;
        40'h000040001c: sd_fake_rom_data <= 16'h0075;
        40'h000040001e: sd_fake_rom_data <= 16'h006d;
        40'h000040001f: sd_fake_rom_data <= 16'h0065;
        40'h0000400020: sd_fake_rom_data <= 16'h5953;
        40'h0000400021: sd_fake_rom_data <= 16'h5453;
        40'h0000400022: sd_fake_rom_data <= 16'h4d45;
        40'h0000400023: sd_fake_rom_data <= 16'h317e;
        40'h0000400024: sd_fake_rom_data <= 16'h2020;
        40'h0000400025: sd_fake_rom_data <= 16'h1620;
        40'h0000400026: sd_fake_rom_data <= 16'h9200;
        40'h0000400027: sd_fake_rom_data <= 16'h91a7;
        40'h0000400028: sd_fake_rom_data <= 16'h4f2a;
        40'h0000400029: sd_fake_rom_data <= 16'h4f2a;
        40'h000040002b: sd_fake_rom_data <= 16'h91a8;
        40'h000040002c: sd_fake_rom_data <= 16'h4f2a;
        40'h000040002d: sd_fake_rom_data <= 16'h0003;
        40'h0000400030: sd_fake_rom_data <= 16'h5845;
        40'h0000400031: sd_fake_rom_data <= 16'h4d41;
        40'h0000400032: sd_fake_rom_data <= 16'h4c50;
        40'h0000400033: sd_fake_rom_data <= 16'h2045;
        40'h0000400034: sd_fake_rom_data <= 16'h5854;
        40'h0000400035: sd_fake_rom_data <= 16'h2054;
        40'h0000400036: sd_fake_rom_data <= 16'h9418;
        40'h0000400037: sd_fake_rom_data <= 16'h91c7;
        40'h0000400038: sd_fake_rom_data <= 16'h4f2a;
        40'h0000400039: sd_fake_rom_data <= 16'h4f2a;
        40'h000040003b: sd_fake_rom_data <= 16'h91ba;
        40'h000040003c: sd_fake_rom_data <= 16'h4f2a;
        40'h000040003d: sd_fake_rom_data <= 16'h0006;
        40'h000040003e: sd_fake_rom_data <= 16'h0019;
        40'h0000404000: sd_fake_rom_data <= 16'h202e;
        40'h0000404001: sd_fake_rom_data <= 16'h2020;
        40'h0000404002: sd_fake_rom_data <= 16'h2020;
        40'h0000404003: sd_fake_rom_data <= 16'h2020;
        40'h0000404004: sd_fake_rom_data <= 16'h2020;
        40'h0000404005: sd_fake_rom_data <= 16'h1020;
        40'h0000404006: sd_fake_rom_data <= 16'h9200;
        40'h0000404007: sd_fake_rom_data <= 16'h91a7;
        40'h0000404008: sd_fake_rom_data <= 16'h4f2a;
        40'h0000404009: sd_fake_rom_data <= 16'h4f2a;
        40'h000040400b: sd_fake_rom_data <= 16'h91a8;
        40'h000040400c: sd_fake_rom_data <= 16'h4f2a;
        40'h000040400d: sd_fake_rom_data <= 16'h0003;
        40'h0000404010: sd_fake_rom_data <= 16'h2e2e;
        40'h0000404011: sd_fake_rom_data <= 16'h2020;
        40'h0000404012: sd_fake_rom_data <= 16'h2020;
        40'h0000404013: sd_fake_rom_data <= 16'h2020;
        40'h0000404014: sd_fake_rom_data <= 16'h2020;
        40'h0000404015: sd_fake_rom_data <= 16'h1020;
        40'h0000404016: sd_fake_rom_data <= 16'h9200;
        40'h0000404017: sd_fake_rom_data <= 16'h91a7;
        40'h0000404018: sd_fake_rom_data <= 16'h4f2a;
        40'h0000404019: sd_fake_rom_data <= 16'h4f2a;
        40'h000040401b: sd_fake_rom_data <= 16'h91a8;
        40'h000040401c: sd_fake_rom_data <= 16'h4f2a;
        40'h0000404020: sd_fake_rom_data <= 16'h7442;
        40'h0000404022: sd_fake_rom_data <= 16'hff00;
        40'h0000404023: sd_fake_rom_data <= 16'hffff;
        40'h0000404024: sd_fake_rom_data <= 16'hffff;
        40'h0000404025: sd_fake_rom_data <= 16'h0fff;
        40'h0000404026: sd_fake_rom_data <= 16'hce00;
        40'h0000404027: sd_fake_rom_data <= 16'hffff;
        40'h0000404028: sd_fake_rom_data <= 16'hffff;
        40'h0000404029: sd_fake_rom_data <= 16'hffff;
        40'h000040402a: sd_fake_rom_data <= 16'hffff;
        40'h000040402b: sd_fake_rom_data <= 16'hffff;
        40'h000040402c: sd_fake_rom_data <= 16'hffff;
        40'h000040402e: sd_fake_rom_data <= 16'hffff;
        40'h000040402f: sd_fake_rom_data <= 16'hffff;
        40'h0000404030: sd_fake_rom_data <= 16'h5701;
        40'h0000404031: sd_fake_rom_data <= 16'h5000;
        40'h0000404032: sd_fake_rom_data <= 16'h5300;
        40'h0000404033: sd_fake_rom_data <= 16'h6500;
        40'h0000404034: sd_fake_rom_data <= 16'h7400;
        40'h0000404035: sd_fake_rom_data <= 16'h0f00;
        40'h0000404036: sd_fake_rom_data <= 16'hce00;
        40'h0000404037: sd_fake_rom_data <= 16'h0074;
        40'h0000404038: sd_fake_rom_data <= 16'h0069;
        40'h0000404039: sd_fake_rom_data <= 16'h006e;
        40'h000040403a: sd_fake_rom_data <= 16'h0067;
        40'h000040403b: sd_fake_rom_data <= 16'h0073;
        40'h000040403c: sd_fake_rom_data <= 16'h002e;
        40'h000040403e: sd_fake_rom_data <= 16'h0064;
        40'h000040403f: sd_fake_rom_data <= 16'h0061;
        40'h0000404040: sd_fake_rom_data <= 16'h5057;
        40'h0000404041: sd_fake_rom_data <= 16'h4553;
        40'h0000404042: sd_fake_rom_data <= 16'h5454;
        40'h0000404043: sd_fake_rom_data <= 16'h317e;
        40'h0000404044: sd_fake_rom_data <= 16'h4144;
        40'h0000404045: sd_fake_rom_data <= 16'h2054;
        40'h0000404046: sd_fake_rom_data <= 16'h9500;
        40'h0000404047: sd_fake_rom_data <= 16'h91a7;
        40'h0000404048: sd_fake_rom_data <= 16'h4f2a;
        40'h0000404049: sd_fake_rom_data <= 16'h4f2a;
        40'h000040404b: sd_fake_rom_data <= 16'h91a8;
        40'h000040404c: sd_fake_rom_data <= 16'h4f2a;
        40'h000040404d: sd_fake_rom_data <= 16'h0004;
        40'h000040404e: sd_fake_rom_data <= 16'h000c;
        40'h0000404050: sd_fake_rom_data <= 16'h4742;
        40'h0000404051: sd_fake_rom_data <= 16'h7500;
        40'h0000404052: sd_fake_rom_data <= 16'h6900;
        40'h0000404053: sd_fake_rom_data <= 16'h6400;
        40'h0000404055: sd_fake_rom_data <= 16'h0f00;
        40'h0000404056: sd_fake_rom_data <= 16'hff00;
        40'h0000404057: sd_fake_rom_data <= 16'hffff;
        40'h0000404058: sd_fake_rom_data <= 16'hffff;
        40'h0000404059: sd_fake_rom_data <= 16'hffff;
        40'h000040405a: sd_fake_rom_data <= 16'hffff;
        40'h000040405b: sd_fake_rom_data <= 16'hffff;
        40'h000040405c: sd_fake_rom_data <= 16'hffff;
        40'h000040405e: sd_fake_rom_data <= 16'hffff;
        40'h000040405f: sd_fake_rom_data <= 16'hffff;
        40'h0000404060: sd_fake_rom_data <= 16'h4901;
        40'h0000404061: sd_fake_rom_data <= 16'h6e00;
        40'h0000404062: sd_fake_rom_data <= 16'h6400;
        40'h0000404063: sd_fake_rom_data <= 16'h6500;
        40'h0000404064: sd_fake_rom_data <= 16'h7800;
        40'h0000404065: sd_fake_rom_data <= 16'h0f00;
        40'h0000404066: sd_fake_rom_data <= 16'hff00;
        40'h0000404067: sd_fake_rom_data <= 16'h0065;
        40'h0000404068: sd_fake_rom_data <= 16'h0072;
        40'h0000404069: sd_fake_rom_data <= 16'h0056;
        40'h000040406a: sd_fake_rom_data <= 16'h006f;
        40'h000040406b: sd_fake_rom_data <= 16'h006c;
        40'h000040406c: sd_fake_rom_data <= 16'h0075;
        40'h000040406e: sd_fake_rom_data <= 16'h006d;
        40'h000040406f: sd_fake_rom_data <= 16'h0065;
        40'h0000404070: sd_fake_rom_data <= 16'h4e49;
        40'h0000404071: sd_fake_rom_data <= 16'h4544;
        40'h0000404072: sd_fake_rom_data <= 16'h4558;
        40'h0000404073: sd_fake_rom_data <= 16'h317e;
        40'h0000404074: sd_fake_rom_data <= 16'h2020;
        40'h0000404075: sd_fake_rom_data <= 16'h2020;
        40'h0000404076: sd_fake_rom_data <= 16'h6600;
        40'h0000404077: sd_fake_rom_data <= 16'h91a8;
        40'h0000404078: sd_fake_rom_data <= 16'h4f2a;
        40'h0000404079: sd_fake_rom_data <= 16'h4f2a;
        40'h000040407b: sd_fake_rom_data <= 16'h91a9;
        40'h000040407c: sd_fake_rom_data <= 16'h4f2a;
        40'h000040407d: sd_fake_rom_data <= 16'h0005;
        40'h000040407e: sd_fake_rom_data <= 16'h004c;
        40'h0000408000: sd_fake_rom_data <= 16'h000c;
        40'h0000408002: sd_fake_rom_data <= 16'h19b9;
        40'h0000408003: sd_fake_rom_data <= 16'h2cb8;
        40'h0000408004: sd_fake_rom_data <= 16'ha4d9;
        40'h0000408005: sd_fake_rom_data <= 16'h8fea;
        40'h000040c000: sd_fake_rom_data <= 16'h007b;
        40'h000040c001: sd_fake_rom_data <= 16'h0038;
        40'h000040c002: sd_fake_rom_data <= 16'h0036;
        40'h000040c003: sd_fake_rom_data <= 16'h0037;
        40'h000040c004: sd_fake_rom_data <= 16'h0044;
        40'h000040c005: sd_fake_rom_data <= 16'h0033;
        40'h000040c006: sd_fake_rom_data <= 16'h0033;
        40'h000040c007: sd_fake_rom_data <= 16'h0031;
        40'h000040c008: sd_fake_rom_data <= 16'h0046;
        40'h000040c009: sd_fake_rom_data <= 16'h002d;
        40'h000040c00a: sd_fake_rom_data <= 16'h0034;
        40'h000040c00b: sd_fake_rom_data <= 16'h0031;
        40'h000040c00c: sd_fake_rom_data <= 16'h0031;
        40'h000040c00d: sd_fake_rom_data <= 16'h0036;
        40'h000040c00e: sd_fake_rom_data <= 16'h002d;
        40'h000040c00f: sd_fake_rom_data <= 16'h0034;
        40'h000040c010: sd_fake_rom_data <= 16'h0038;
        40'h000040c011: sd_fake_rom_data <= 16'h0035;
        40'h000040c012: sd_fake_rom_data <= 16'h0039;
        40'h000040c013: sd_fake_rom_data <= 16'h002d;
        40'h000040c014: sd_fake_rom_data <= 16'h0039;
        40'h000040c015: sd_fake_rom_data <= 16'h0034;
        40'h000040c016: sd_fake_rom_data <= 16'h0046;
        40'h000040c017: sd_fake_rom_data <= 16'h0031;
        40'h000040c018: sd_fake_rom_data <= 16'h002d;
        40'h000040c019: sd_fake_rom_data <= 16'h0045;
        40'h000040c01a: sd_fake_rom_data <= 16'h0036;
        40'h000040c01b: sd_fake_rom_data <= 16'h0032;
        40'h000040c01c: sd_fake_rom_data <= 16'h0037;
        40'h000040c01d: sd_fake_rom_data <= 16'h0034;
        40'h000040c01e: sd_fake_rom_data <= 16'h0046;
        40'h000040c01f: sd_fake_rom_data <= 16'h0032;
        40'h000040c020: sd_fake_rom_data <= 16'h0034;
        40'h000040c021: sd_fake_rom_data <= 16'h0030;
        40'h000040c022: sd_fake_rom_data <= 16'h0035;
        40'h000040c023: sd_fake_rom_data <= 16'h0043;
        40'h000040c024: sd_fake_rom_data <= 16'h0032;
        40'h000040c025: sd_fake_rom_data <= 16'h007d;
        40'h0000410000: sd_fake_rom_data <= 16'h6548;
        40'h0000410001: sd_fake_rom_data <= 16'h6c6c;
        40'h0000410002: sd_fake_rom_data <= 16'h206f;
        40'h0000410003: sd_fake_rom_data <= 16'h6f77;
        40'h0000410004: sd_fake_rom_data <= 16'h6c72;
        40'h0000410005: sd_fake_rom_data <= 16'h2164;
        40'h0000410006: sd_fake_rom_data <= 16'h0a0d;
        40'h0000410007: sd_fake_rom_data <= 16'h7449;
        40'h0000410008: sd_fake_rom_data <= 16'h7720;
        40'h0000410009: sd_fake_rom_data <= 16'h726f;
        40'h000041000a: sd_fake_rom_data <= 16'h736b;
        40'h000041000b: sd_fake_rom_data <= 16'h0d21;
        40'h000041000c: sd_fake_rom_data <= 16'h000a;
        default:        sd_fake_rom_data <= 16'h0000;
      endcase

endmodule

`default_nettype wire
