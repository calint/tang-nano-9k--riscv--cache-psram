//
// Cache for burst RAM
// see: IPUG943-1.2E Gowin PSRAM Memory Interface HS & HS 2CH IP
//
// reviewed 2024-06-07
// reviewed 2024-06-12
// reviewed 2024-06-14
//
`timescale 1ns / 1ps
//
`default_nettype none
//`define DBG
//`define INFO

module cache #(
    parameter int unsigned LineIndexBitwidth = 8,
    // cache lines: 2 ^ value

    parameter int unsigned RamAddressBitwidth = 21,
    // bits in the address of underlying burst RAM

    parameter int unsigned CommandDelayIntervalCycles = 13,
    // the clock cycles delay between commands
    // see: IPUG943-1.2E Gowin PSRAM Memory Interface HS & HS 2CH IP
    //      page 10
    // note: 1 less than spec because the counter starts 1 cycle late (13)

    parameter int unsigned RamAddressingMode = 0
    // amount of data stored per address
    //       0: 1 B (byte addressed)
    //       1: 2 B
    //       2: 4 B
    //       3: 8 B
) (
    input wire rst_n,
    input wire clk,

    input wire enable,
    // enabled for cache to operate

    input wire [31:0] address,
    // byte addressed; must be held while 'busy' + 1 cycle

    output logic [31:0] data_out,
    output logic data_out_ready,
    input wire [31:0] data_in,

    input wire [3:0] write_enable,
    // note: write enable bytes must be held while busy + 1 cycle

    output logic busy,
    // asserted when busy reading / writing cache line

    // burst RAM wiring; prefix 'br_'
    output logic br_cmd,  // 0: read, 1: write
    output logic br_cmd_en,  // 1: cmd and addr is valid
    output logic [RamAddressBitwidth-1:0] br_addr,  // see 'RamAddressingMode'
    output logic [63:0] br_wr_data,  // data to write
    output logic [7:0] br_data_mask,  // always 0 meaning write all bytes
    input wire [63:0] br_rd_data,  // data out
    input wire br_rd_data_valid  // rd_data is valid
);

`ifdef INFO
  initial begin
    $display("Cache");
    $display("      lines: %0d", LINE_COUNT);
    $display("    columns: %0d x 4 B", 2 ** COLUMN_IX_BITWIDTH);
    $display("        tag: %0d bits", TAG_BITWIDTH);
    $display(" cache size: %0d B", LINE_COUNT * (2 ** COLUMN_IX_BITWIDTH) * 4);
  end
`endif

  localparam int unsigned ZEROS_BITWIDTH = 2;  // leading zeros in the address
  localparam int unsigned COLUMN_IX_BITWIDTH = 3;  // 2 ^ 3 = 8 elements per line
  localparam int unsigned COLUMN_COUNT = 2 ** COLUMN_IX_BITWIDTH;
  localparam int unsigned LINE_COUNT = 2 ** LineIndexBitwidth;
  localparam int unsigned TAG_BITWIDTH = 
    RamAddressBitwidth + RamAddressingMode - LineIndexBitwidth - COLUMN_IX_BITWIDTH - ZEROS_BITWIDTH;
  // note: assumes there are 2 bits free after 'TAG_BITWIDTH' for 'valid' and 'dirty' flags in storage

  localparam int unsigned LINE_VALID_BIT = TAG_BITWIDTH;
  localparam int unsigned LINE_DIRTY_BIT = TAG_BITWIDTH + 1;
  localparam int unsigned LINE_TO_RAM_ADDRESS_LEFT_SHIFT = COLUMN_IX_BITWIDTH + ZEROS_BITWIDTH - RamAddressingMode;

  // wires dividing the address into components
  // |tag|line| col |00| address
  //                |00| ignored (4-bytes word aligned)
  //          | col |    column_ix: index of the data in the cached line
  //     |line|          line_ix: index in array where tag and cached data is stored
  // |tag|               address_tag: upper bits followed by 'valid' and 'dirty' flag

  // extract cache line info from current address
  wire [COLUMN_IX_BITWIDTH-1:0] column_ix = address[
    COLUMN_IX_BITWIDTH+ZEROS_BITWIDTH-1
    -:COLUMN_IX_BITWIDTH
  ];
  wire [LineIndexBitwidth-1:0] line_ix =  address[
    LineIndexBitwidth+COLUMN_IX_BITWIDTH+ZEROS_BITWIDTH-1
    -:LineIndexBitwidth
  ];
  wire [TAG_BITWIDTH-1:0] address_tag = address[
    TAG_BITWIDTH+LineIndexBitwidth+COLUMN_IX_BITWIDTH+ZEROS_BITWIDTH-1
    -:TAG_BITWIDTH
  ];

  // starting address of cache line in RAM for current address
  wire [RamAddressBitwidth-1:0] burst_line_address = {
    address[TAG_BITWIDTH+LineIndexBitwidth+COLUMN_IX_BITWIDTH+ZEROS_BITWIDTH-1:COLUMN_IX_BITWIDTH+ZEROS_BITWIDTH],
    {LINE_TO_RAM_ADDRESS_LEFT_SHIFT{1'b0}}
  };

  logic burst_is_reading;  // true if in burst read operation
  logic [31:0] burst_data_in[COLUMN_COUNT];
  logic [3:0] burst_write_enable[COLUMN_COUNT];
  logic burst_tag_write_enable;

  logic burst_is_writing;  // true if in burst write operation

  wire [31:0] cached_tag_and_flags;
  logic tag_write_enable;  // true when cache hit; write to set line dirty
  logic [31:0] tag_data_in;  // tag and flags written when cache hit write

  assign br_data_mask = 0;  // writing whole cache lines

  bram #(
      .AddressBitwidth(LineIndexBitwidth)
  ) tag (
      .clk,
      .write_enable({4{tag_write_enable}}),
      .address(line_ix),
      .data_in(tag_data_in),
      .data_out(cached_tag_and_flags)
  );

  // extract portions of the combined tag, valid, dirty line info
  wire line_valid = cached_tag_and_flags[LINE_VALID_BIT];
  wire line_dirty = cached_tag_and_flags[LINE_DIRTY_BIT];
  wire [TAG_BITWIDTH-1:0] cached_tag = cached_tag_and_flags[TAG_BITWIDTH-1:0];

  // starting address in burst RAM for the cached line
  wire [RamAddressBitwidth-1:0] cached_line_address = {
    {cached_tag, line_ix}, {LINE_TO_RAM_ADDRESS_LEFT_SHIFT{1'b0}}
  };

  wire cache_line_hit = line_valid && address_tag == cached_tag;

  // counts minimum cycles between commands
  logic [5:0] command_delay_interval_counter;

  assign busy = enable && !cache_line_hit || command_delay_interval_counter != 0;

  // select data from requested column
  assign data_out = column_data_out[column_ix];
  assign data_out_ready = write_enable != 0 ? 0 : enable && cache_line_hit;

  // 8 instances of byte enabled semi dual port RAM blocks
  // if cache hit at write then connect 'data_in' to the column
  // if cache miss connect to the state machine that loads a cache line
  logic [31:0] column_data_in[COLUMN_COUNT];
  logic [3:0] column_write_enable[COLUMN_COUNT];
  logic [31:0] column_data_out[COLUMN_COUNT];

  generate
    for (genvar i = 0; i < COLUMN_COUNT; i++) begin : column
      bram #(
          .AddressBitwidth(LineIndexBitwidth)
      ) column (
          .clk,
          .write_enable(column_write_enable[i]),
          .address(line_ix),
          .data_in(burst_is_reading ? burst_data_in[i] : column_data_in[i]),
          .data_out(column_data_out[i])
      );
    end
  endgenerate

  always_comb begin
    for (int i = 0; i < COLUMN_COUNT; i++) begin
      column_write_enable[i] = 0;
      column_data_in[i] = 0;
    end

    tag_write_enable = 0;
    tag_data_in = 0;

    if (burst_is_reading) begin
      // writing to the cache line in a burst read from RAM
      // select the write from burst registers
      for (int i = 0; i < COLUMN_COUNT; i++) begin
        column_write_enable[i] = burst_write_enable[i];
      end
      // write tag of the fetched cache line when burst is finished reading
      // the line
      tag_write_enable = burst_tag_write_enable;
      tag_data_in = {1'b0, 1'b1, address_tag};
      // note: {dirty, valid, upper address bits}
    end else if (burst_is_writing) begin
      //
    end else if (write_enable != 0) begin
`ifdef DBG
      $display("%m: %0t: @(*) write 0x%h = 0x%h  mask: 0b%b  line: %0d  column: %0d", $time,
               address, data_in, write_enable, line_ix, column_ix);
`endif
      if (cache_line_hit) begin
`ifdef DBG
        $display("%m: %0t: @(*) cache hit, set dirty flag", $time);
`endif
        // enable write tag with dirty bit set
        tag_write_enable = 1;
        tag_data_in = {1'b1, 1'b1, address_tag};
        // note: { dirty, valid, tag }

        // connect 'column_data_in' to the input and set 'column_write_enable'
        //  for the addressed column in the cache line
        column_write_enable[column_ix] = write_enable;
        column_data_in[column_ix] = data_in;
      end else begin  // not (cache_line_hit)
`ifdef DBG
        $display("%m: %0t: @(*) cache miss", $time);
`endif
      end
    end else begin
`ifdef DBG
      $display("%m: %0t: @(*) read 0x%h  data out: 0x%h  line: %0d  column: %0d  data ready: %0d",
               $time, address, data_out, line_ix, column_ix, data_out_ready);
`endif
    end
  end

  typedef enum {
    Idle,
    ReadWaitForDataReady,
    Read1,
    Read2,
    Read3,
    ReadFinish,
    Write1,
    Write2,
    Write3,
    WriteFinish
  } state_e;

  state_e state;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      burst_tag_write_enable <= 0;
      for (int i = 0; i < COLUMN_COUNT; i++) begin
        burst_write_enable[i] <= 0;
      end
      burst_is_reading <= 0;
      burst_is_writing <= 0;
      command_delay_interval_counter <= 0;
      state <= Idle;
    end else begin
`ifdef DBG
      $display("%m: %0t: state: %0d", $time, state);
`endif
      // count down command interval
      if (command_delay_interval_counter != 0) begin
`ifdef DBG
        $display("%m: %0t: command delay interval counter: %0d", $time,
                 command_delay_interval_counter);
`endif
        command_delay_interval_counter <= command_delay_interval_counter - 1'b1;
      end

      unique case (state)

        Idle: begin
          if (enable && !cache_line_hit && command_delay_interval_counter == 0) begin
            // cache miss, start reading the addressed cache line
`ifdef DBG
            $display("%m: %0t: cache miss address 0x%h  line: %0d  write enable: 0b%b", $time,
                     address, line_ix, write_enable);
`endif
            if (line_dirty) begin
`ifdef DBG
              $display("%m: %0t: line %0d dirty, evict to RAM address 0x%h", $time, line_ix,
                       cached_line_address);
              $display("%m: %0t: write line (1): 0x%h%h", $time, column_data_out[0], $time,
                       column_data_out[1]);
`endif
              br_cmd <= 1;  // command write
              br_addr <= cached_line_address;
              br_wr_data[31:0] <= column_data_out[0];
              br_wr_data[63:32] <= column_data_out[1];
              br_cmd_en <= 1;
              command_delay_interval_counter <= CommandDelayIntervalCycles;
              burst_is_writing <= 1;
              state <= Write1;
            end else begin  // not (line_dirty)
`ifdef DBG
              $display("%m: %0t: line %0d not dirty", $time, line_ix);
              $display("%m: %0t: read line %0d from RAM address 0x%h", $time, line_ix,
                       burst_line_address);
`endif
              br_cmd <= 0;  // command read
              br_addr <= burst_line_address;
              br_cmd_en <= 1;
              command_delay_interval_counter <= CommandDelayIntervalCycles;
              burst_is_reading <= 1;
              state <= ReadWaitForDataReady;
            end
          end
        end

        ReadWaitForDataReady: begin
          br_cmd_en <= 0;
          if (br_rd_data_valid) begin
            // first data has arrived
`ifdef DBG
            $display("%m: %0t: read line (1): 0x%h", $time, br_rd_data);
`endif
            burst_write_enable[0] <= 4'b1111;
            burst_data_in[0] <= br_rd_data[31:0];
            burst_write_enable[1] <= 4'b1111;
            burst_data_in[1] <= br_rd_data[63:32];
            state <= Read1;
          end else begin  // not (br_rd_data_valid)
`ifdef DBG
            $display("%m: %0t: waiting for data valid from RAM", $time);
`endif
          end
        end

        Read1: begin
          // second data has arrived
`ifdef DBG
          $display("%m: %0t: read line (2): 0x%h", $time, br_rd_data);
`endif
          burst_write_enable[0] <= 0;
          burst_write_enable[1] <= 0;
          burst_write_enable[2] <= 4'b1111;
          burst_data_in[2] <= br_rd_data[31:0];
          burst_write_enable[3] <= 4'b1111;
          burst_data_in[3] <= br_rd_data[63:32];
          state <= Read2;
        end

        Read2: begin
          // third data has arrived
`ifdef DBG
          $display("%m: %0t: read line (3): 0x%h", $time, br_rd_data);
`endif
          burst_write_enable[2] <= 0;
          burst_write_enable[3] <= 0;
          burst_write_enable[4] <= 4'b1111;
          burst_data_in[4] <= br_rd_data[31:0];
          burst_write_enable[5] <= 4'b1111;
          burst_data_in[5] <= br_rd_data[63:32];
          state <= Read3;
        end

        Read3: begin
          // last data has arrived
`ifdef DBG
          $display("%m: %0t: read line (4): 0x%h", $time, br_rd_data);
`endif
          burst_write_enable[4] <= 0;
          burst_write_enable[5] <= 0;
          burst_write_enable[6] <= 4'b1111;
          burst_data_in[6] <= br_rd_data[31:0];
          burst_write_enable[7] <= 4'b1111;
          burst_data_in[7] <= br_rd_data[63:32];
          burst_tag_write_enable <= 1;
          state <= ReadFinish;
        end

        ReadFinish: begin
          burst_write_enable[6] <= 0;
          burst_write_enable[7] <= 0;
          // note: tag has been written after read data has settled
          burst_is_reading <= 0;
          burst_tag_write_enable <= 0;
          state <= Idle;
        end

        Write1: begin
`ifdef DBG
          $display("%m: %0t: write line (2): 0x%h%h", $time, column_data_out[2],
                   column_data_out[3]);
`endif
          br_cmd_en <= 0;  // hold command enable only one cycle
          br_wr_data[31:0] <= column_data_out[2];
          br_wr_data[63:32] <= column_data_out[3];
          state <= Write2;
        end

        Write2: begin
`ifdef DBG
          $display("%m: %0t: write line (3): 0x%h%h", $time, column_data_out[4],
                   column_data_out[5]);
`endif
          br_wr_data[31:0] <= column_data_out[4];
          br_wr_data[63:32] <= column_data_out[5];
          state <= Write3;
        end

        Write3: begin
`ifdef DBG
          $display("%m: %0t: write line (4): 0x%h%h", $time, column_data_out[6],
                   column_data_out[7]);
`endif
          br_wr_data[31:0] <= column_data_out[6];
          br_wr_data[63:32] <= column_data_out[7];
          state <= WriteFinish;
        end

        WriteFinish: begin
          // check if need to wait for command interval delay
          if (command_delay_interval_counter == 0) begin
`ifdef DBG
            $display("%m: %0t: read line after eviction from RAM address 0x%h", $time,
                     burst_line_address);
`endif
            // start reading the cache line
            br_cmd <= 0;  // command read
            br_addr <= burst_line_address;
            br_cmd_en <= 1;
            command_delay_interval_counter <= CommandDelayIntervalCycles;
            burst_is_writing <= 0;
            burst_is_reading <= 1;
            state <= ReadWaitForDataReady;
          end else begin
`ifdef DBG
            $display("%m: %0t: waiting for command delay counter %0d", $time,
                     command_delay_interval_counter);
`endif
          end
        end

        default: ;

      endcase
    end
  end

endmodule

`undef DBG
`undef INFO
`default_nettype wire
