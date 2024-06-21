//
// cache interfacing with burst RAM
// see: IPUG943-1.2E Gowin PSRAM Memory Interface HS & HS 2CH IP
//
// reviewed 2024-06-07
// reviewed 2024-06-12
// reviewed 2024-06-14
`timescale 100ps / 100ps
//
`default_nettype none
// `define DBG
// `define INFO

module Cache #(
    parameter LineIndexBitWidth = 8,
    // cache lines: 2 ^ value

    parameter RamAddressBitWidth = 21,
    // bits in the address interfacing with RAM

    parameter CommandDelayIntervalCycles = 13,
    // the clock cycles delay between commands
    // see: IPUG943-1.2E Gowin PSRAM Memory Interface HS & HS 2CH IP
    //      page 10
    // note: 1 less than spec because the counter starts 1 cycle late (13)

    parameter RamAddressingMode = 0
    // note: 3: RAM has 64 bit words
    //       2: RAM has 32 bit words
    //       1: RAM has 16 bit words
    //       0: RAM has 8 bit words
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
    output logic [RamAddressBitWidth-1:0] br_addr,  // see 'RamAddressingMode'
    output logic [63:0] br_wr_data,  // data to write
    output logic [7:0] br_data_mask,  // always 0 meaning write all bytes
    input wire [63:0] br_rd_data,  // data out
    input wire br_rd_data_valid  // rd_data is valid
);

`ifdef INFO
  initial begin
    $display("Cache");
    $display("      lines: %0d", LINE_COUNT);
    $display("    columns: %0d x 4B", 2 ** COLUMN_IX_BITWIDTH);
    $display("        tag: %0d bits", TAG_BITWIDTH);
    $display(" cache size: %0d B", LINE_COUNT * (2 ** COLUMN_IX_BITWIDTH) * 4);
  end
`endif

  localparam ZEROS_BITWIDTH = 2;  // leading zeros in the address
  localparam COLUMN_IX_BITWIDTH = 3;  // 2 ^ 3 = 8 elements per line
  localparam COLUMN_COUNT = 2 ** COLUMN_IX_BITWIDTH;
  localparam LINE_COUNT = 2 ** LineIndexBitWidth;
  localparam TAG_BITWIDTH = 32 - LineIndexBitWidth - COLUMN_IX_BITWIDTH - ZEROS_BITWIDTH;
  // note: assumes there are 2 bits free after 'TAG_BITWIDTH' for 'valid' and 'dirty' flags

  localparam LINE_VALID_BIT = TAG_BITWIDTH;
  localparam LINE_DIRTY_BIT = TAG_BITWIDTH + 1;
  localparam LINE_TO_RAM_ADDRESS_LEFT_SHIFT = COLUMN_IX_BITWIDTH + ZEROS_BITWIDTH - RamAddressingMode;

  // wires dividing the address into components
  // |tag|line| col |00| address
  //                |00| ignored (4 bytes word aligned)
  //          | col |    column_ix: index of the data in the cached line
  //     |line|          line_ix: index in array where tag and cached data is stored
  // |tag|               address_tag: upper bits followed by 'valid' and 'dirty' flag

  // extract cache line info from current address
  wire [COLUMN_IX_BITWIDTH-1:0] column_ix = address[
    COLUMN_IX_BITWIDTH+ZEROS_BITWIDTH-1
    -:COLUMN_IX_BITWIDTH
  ];
  wire [LineIndexBitWidth-1:0] line_ix =  address[
    LineIndexBitWidth+COLUMN_IX_BITWIDTH+ZEROS_BITWIDTH-1
    -:LineIndexBitWidth
  ];
  wire [TAG_BITWIDTH-1:0] address_tag = address[
    TAG_BITWIDTH+LineIndexBitWidth+COLUMN_IX_BITWIDTH+ZEROS_BITWIDTH-1
    -:TAG_BITWIDTH
  ];

  // starting address of cache line in RAM for current address
  wire [RamAddressBitWidth-1:0] burst_line_address = {
    address[31:COLUMN_IX_BITWIDTH+ZEROS_BITWIDTH], {LINE_TO_RAM_ADDRESS_LEFT_SHIFT{1'b0}}
  };

  logic burst_is_reading;  // true if in burst read operation
  logic [31:0] burst_data_in[COLUMN_COUNT];
  logic [3:0] burst_write_enable[COLUMN_COUNT];
  logic [3:0] burst_tag_write_enable;

  logic burst_is_writing;  // true if in burst write operation

  logic [31:0] cached_tag_and_flags;
  logic [3:0] tag_write_enable;  // true when cache hit; write to set line dirty
  logic [31:0] tag_data_in;  // tag and flags written when cache hit write

  assign br_data_mask = 0;  // writing whole cache lines

  BESDPB #(
      .AddressBitWidth(LineIndexBitWidth)
  ) tag (
      .clk(clk),
      .write_enable(tag_write_enable),
      .address(line_ix),
      .data_in(tag_data_in),
      .data_out(cached_tag_and_flags)
  );

  // extract portions of the combined tag, valid, dirty line info
  wire line_valid = cached_tag_and_flags[LINE_VALID_BIT];
  wire line_dirty = cached_tag_and_flags[LINE_DIRTY_BIT];
  wire [TAG_BITWIDTH-1:0] cached_tag = cached_tag_and_flags[TAG_BITWIDTH-1:0];

  // starting address in burst RAM for the cached line
  wire [RamAddressBitWidth-1:0] cached_line_address = {
    {cached_tag, line_ix}, {LINE_TO_RAM_ADDRESS_LEFT_SHIFT{1'b0}}
  };

  wire cache_line_hit = line_valid && address_tag == cached_tag;

  // counts minimum cycles between commands
  logic [5:0] command_delay_interval_counter;

  assign busy = enable && !cache_line_hit || command_delay_interval_counter != 0;

  // select data from requested column
  assign data_out = column_data_out[column_ix];
  assign data_out_ready = write_enable != '0 ? 0 : enable && cache_line_hit;

  // 8 instances of byte enabled semi dual port RAM blocks
  // if cache hit at write then connect 'data_in' to the column
  // if cache miss connect to the state machine that loads a cache line
  logic [31:0] column_data_in[COLUMN_COUNT];
  logic [3:0] column_write_enable[COLUMN_COUNT];
  logic [31:0] column_data_out[COLUMN_COUNT];

  generate
    for (genvar i = 0; i < COLUMN_COUNT; i++) begin : column
      BESDPB #(
          .AddressBitWidth(LineIndexBitWidth)
      ) column (
          .clk(clk),
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
    end else if (write_enable != '0) begin
`ifdef DBG
      $display("@(*) write 0x%h = 0x%h  mask: %b  line: %0d  column: %0d", address, data_in,
               write_enable, line_ix, column_ix);
`endif
      if (cache_line_hit) begin
`ifdef DBG
        $display("@(*) cache hit, set dirty flag");
`endif
        // enable write tag with dirty bit set
        tag_write_enable = 4'b1111;
        tag_data_in = {1'b1, 1'b1, address_tag};
        // note: { dirty, valid, tag }

        // connect 'column_data_in' to the input and set 'column_write_enable'
        //  for the addressed column in the cache line
        column_write_enable[column_ix] = write_enable;
        column_data_in[column_ix] = data_in;
      end else begin  // not (cache_line_hit)
`ifdef DBG
        $display("@(*) cache miss");
`endif
      end
    end else begin
`ifdef DBG
      $display("@(*) read 0x%h  data out: 0x%h  line: %0d  column: %0d  data ready: %0d", address,
               data_out, line_ix, column_ix, data_out_ready);
`endif
    end
  end

  typedef enum {
    Idle,
    ReadWaitForDataReady,
    Read1,
    Read2,
    Read3,
    ReadUpdateTag,
    ReadFinish,
    Write1,
    Write2,
    Write3,
    WriteFinish
  } state_e;

  state_e state;

  always_ff @(posedge clk or negedge rst_n) begin
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
      $display("@(c) state: %0d", state);
`endif
      // count down command interval
      if (command_delay_interval_counter != 0) begin
`ifdef DBG
        $display("@(c) command delay interval counter: %0d", command_delay_interval_counter);
`endif
        command_delay_interval_counter <= command_delay_interval_counter - 1'b1;
      end

      unique case (state)

        Idle: begin
          if (enable && !cache_line_hit && command_delay_interval_counter == 0) begin
            // cache miss, start reading the addressed cache line
`ifdef DBG
            $display("@(c) cache miss address 0x%h  line: %0d  write enable: %b", address, line_ix,
                     write_enable);
`endif
            if (line_dirty) begin
`ifdef DBG
              $display("@(c) line %0d dirty, evict to RAM address 0x%h", line_ix,
                       cached_line_address);
              $display("@(c) write line (1): 0x%h%h", column_data_out[0], column_data_out[1]);
`endif
              br_cmd <= 1;  // command write
              br_addr <= cached_line_address;
              br_wr_data[31:0] <= column_data_out[0];
              br_wr_data[63:32] <= column_data_out[1];
              br_cmd_en <= 1;
              command_delay_interval_counter <= CommandDelayIntervalCycles;
              burst_is_writing <= 1;
              state <= Write1;
            end else begin  // not (write_enable && line_dirty)
`ifdef DBG
              if (write_enable && !line_dirty) begin
                $display("@(c) line %0d not dirty", line_ix);
              end
              $display("@(c) read line from RAM address 0x%h", burst_line_address);
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
            $display("@(c) read line (1): 0x%h", br_rd_data);
`endif
            burst_write_enable[0] <= 4'b1111;
            burst_data_in[0] <= br_rd_data[31:0];
            burst_write_enable[1] <= 4'b1111;
            burst_data_in[1] <= br_rd_data[63:32];
            state <= Read1;
          end else begin  // not (br_rd_data_valid)
`ifdef DBG
            $display("@(c) waiting for data valid from RAM");
`endif
          end
        end

        Read1: begin
          // second data has arrived
`ifdef DBG
          $display("@(c) read line (2): 0x%h", br_rd_data);
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
          $display("@(c) read line (3): 0x%h", br_rd_data);
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
          $display("@(c) read line (4): 0x%h", br_rd_data);
`endif
          burst_write_enable[4] <= 0;
          burst_write_enable[5] <= 0;
          burst_write_enable[6] <= 4'b1111;
          burst_data_in[6] <= br_rd_data[31:0];
          burst_write_enable[7] <= 4'b1111;
          burst_data_in[7] <= br_rd_data[63:32];
          state <= ReadUpdateTag;
        end

        ReadUpdateTag: begin
          // note: reading line can be initiated after a cache eviction
          //       'burst_write_enable[6]' and 7 are then high, set to low
          burst_write_enable[6] <= 0;
          burst_write_enable[7] <= 0;
          burst_tag_write_enable <= 4'b1111;
          state <= ReadFinish;
        end

        ReadFinish: begin
          // note: tag has been written after read data has settled
          burst_is_reading <= 0;
          burst_tag_write_enable <= 0;
          state <= Idle;
        end

        Write1: begin
`ifdef DBG
          $display("@(c) write line (2): 0x%h%h", column_data_out[2], column_data_out[3]);
`endif
          br_cmd_en <= 0;  // hold command enable only one cycle
          br_wr_data[31:0] <= column_data_out[2];
          br_wr_data[63:32] <= column_data_out[3];
          state <= Write2;
        end

        Write2: begin
`ifdef DBG
          $display("@(c) write line (3): 0x%h%h", column_data_out[4], column_data_out[5]);
`endif
          br_wr_data[31:0] <= column_data_out[4];
          br_wr_data[63:32] <= column_data_out[5];
          state <= Write3;
        end

        Write3: begin
`ifdef DBG
          $display("@(c) write line (4): 0x%h%h", column_data_out[6], column_data_out[7]);
`endif
          br_wr_data[31:0] <= column_data_out[6];
          br_wr_data[63:32] <= column_data_out[7];
          state <= WriteFinish;
        end

        WriteFinish: begin
          // check if need to wait for command interval delay
          if (command_delay_interval_counter == 0) begin
`ifdef DBG
            $display("@(c) read line after eviction from RAM address 0x%h", burst_line_address);
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
            $display("@(c) waiting for command delay counter %0d", command_delay_interval_counter);
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
