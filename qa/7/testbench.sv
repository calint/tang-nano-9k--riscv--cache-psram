//
// core  (bug fix #1)
//
`timescale 100ps / 100ps
//
`default_nettype none

module testbench;
  logic rst_n;
  logic clk = 1;
  localparam int unsigned clk_tk = 36;
  always #(clk_tk / 2) clk = ~clk;

  localparam int unsigned RAM_ADDRESS_BIT_WIDTH = 11;  // 2^11 * 8 B = 16 KB

  logic [5:0] led;
  logic uart_tx;
  logic uart_rx;

  //------------------------------------------------------------------------
  logic br_cmd;
  logic br_cmd_en;
  logic [RAM_ADDRESS_BIT_WIDTH-1:0] br_addr;
  logic [63:0] br_wr_data;
  logic [7:0] br_data_mask;
  logic [63:0] br_rd_data;
  logic br_rd_data_valid;
  logic br_init_calib;
  logic br_busy;

  //------------------------------------------------------------------------
  burst_ram #(
      .DataFilePath(""),  // initial RAM content
      .AddressBitWidth(RAM_ADDRESS_BIT_WIDTH),  // 2 ^ x * 8 B entries
      .BurstDataCount(4),  // 4 * 64 bit data per burst
      .CyclesBeforeDataValid(6),
      .CyclesBeforeInitiated(0)
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
  logic ramio_enable;
  logic [1:0] ramio_write_type;
  logic [2:0] ramio_read_type;
  logic [31:0] ramio_address;
  logic [31:0] ramio_data_out;
  logic ramio_data_out_ready;
  logic [31:0] ramio_data_in;
  logic ramio_busy;

  ramio #(
      .RamAddressBitWidth(RAM_ADDRESS_BIT_WIDTH),
      .RamAddressingMode(3),  // 64 bit word RAM
      .CacheLineIndexBitWidth(1),
      .ClockFrequencyHz(20_250_000),
      .BaudRate(20_250_000)
  ) ramio (
      .rst_n(rst_n && br_init_calib),
      .clk,
      .enable(ramio_enable),
      .write_type(ramio_write_type),
      .read_type(ramio_read_type),
      .address(ramio_address),
      .data_in(ramio_data_in),
      .data_out(ramio_data_out),
      .data_out_ready(ramio_data_out_ready),
      .busy(ramio_busy),
      .led(led[3:0]),
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
  logic flash_clk;
  logic flash_miso;
  logic flash_mosi;
  logic flash_cs;

  flash #(
      .DataFilePath("ram.mem"),
      .AddressBitWidth(12)  // in bytes 2^12 = 4096 B
  ) flash (
      .rst_n,
      .clk (flash_clk),
      .miso(flash_miso),
      .mosi(flash_mosi),
      .cs  (flash_cs)
  );
  //------------------------------------------------------------------------
  core #(
      .StartupWaitCycles (0),
      .FlashTransferBytes(4096)
  ) core (
      .rst_n(rst_n && br_init_calib),
      .clk,
      .led  (led[4]),

      .ramio_enable,
      .ramio_write_type,
      .ramio_read_type,
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
  //------------------------------------------------------------------------
  assign led[5] = ~ramio_busy;
  //------------------------------------------------------------------------
  initial begin
    $dumpfile("log.vcd");
    $dumpvars(0, testbench);

    rst_n <= 0;
    #clk_tk;
    rst_n <= 1;
    #clk_tk;

    // wait for burst RAM to initiate
    while (br_busy) #clk_tk;

    // 0:	00010137          	lui	x2,0x10
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[2] == 32'h0001_0000)
    else $error();

    // 4:	004000ef          	jal	x1,8 <run>
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    assert (core.pc == 8)
    else $error();

    // 8:	ff010113          	addi	x2,x2,-16 # fff0 <__global_pointer$+0xd75c>
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[2] == 32'h0000_fff0)
    else $error();

    // c:	00112623          	sw	x1,12(x2) # [0xfff0+12] = x1
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;

    // 10:	00812423          	sw	x8,8(x2)  # [0xfff0+8] = x8
    while (core.state != core.CpuExecute) #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;

    // 14:	01010413          	addi	x8,x2,16  # 0xfff0 + 16
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[8] == 32'h0001_0000)
    else $error();

    // 18:	00000513          	addi	x10,x0,0
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[10] == 0)
    else $error();

    // 1c:	00000097          	auipc	x1,0x0
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[1] == 32'h0000_001c)
    else $error();

    // 20:	01c080e7          	jalr	x1,28(x1) # 38 <run+0x30>
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    assert (core.pc == 32'h0000_0038)
    else $error();

    // 38:	fd010113          	addi	x2,x2,-48 # 0xffc0
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[2] == 32'h0000_ffc0)
    else $error();

    // 3c:	02812623          	sw	x8,44(x2) #   [0xffec] = 0x1'0000
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    while (core.state != core.CpuFetch) #clk_tk;

    // 40:	03010413          	addi	x8,x2,48 # 0xffc0 + 48
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    #clk_tk;
    assert (core.registers.data[8] == 32'h0000_fff0)
    else $error();

    // 44:	fca42e23          	sw	x10,-36(x8) # [0xfff0 - 36] = [0xffcc] = 0
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;

    // 48:	fdc42783          	lw	x15,-36(x8) # x15 = [0xfff0 - 36] = [0xffcc] = 0
    while (core.state != core.CpuExecute) #clk_tk;
    #clk_tk;
    while (core.state != core.CpuExecute) #clk_tk;
    assert (core.registers.data[15] == 32'h0000_0000)
    else $error();

    $finish;

  end

endmodule

`default_nettype wire
