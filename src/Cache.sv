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
    // cache lines: 2 ^ value
    parameter LINE_IX_BITWIDTH = 8,

    // bits in the address interfacing with RAM
    parameter RAM_DEPTH_BITWIDTH = 21,

    // the clock cycles delay between commands
    // see: IPUG943-1.2E Gowin PSRAM Memory Interface HS & HS 2CH IP
    //      page 10
    parameter COMMAND_DELAY_INTERVAL = 13,
    // note: 1 less than spec because the counter starts 1 cycle late (13)

    parameter RAM_ADDRESSING_MODE = 0
    // note: 3: RAM has 64 bit words
    //       2: RAM has 32 bit words
    //       1: RAM has 16 bit words
    //       0: RAM has 8 bit words
) (
    input wire clk,
    input wire rst_n,

    // enabled for cache to operate
    input wire enable,

    // byte addressed; must be held while 'busy' + 1 cycle
    input wire [31:0] address,

    output reg [31:0] data_out,
    output reg data_out_ready,
    input wire [31:0] data_in,

    // write enable bytes must be held while busy + 1 cycle
    input wire [3:0] write_enable,

    // asserted when busy reading / writing cache line
    output wire busy,

    // burst RAM wiring; prefix 'br_'
    output reg br_cmd,  // 0: read, 1: write
    output reg br_cmd_en,  // 1: cmd and addr is valid
    output reg [RAM_DEPTH_BITWIDTH-1:0] br_addr,  // see 'RAM_ADDRESSING_MODE'
    output reg [63:0] br_wr_data,  // data to write
    output wire [7:0] br_data_mask,  // always 0 meaning write all bytes
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
  localparam LINE_COUNT = 2 ** LINE_IX_BITWIDTH;
  localparam TAG_BITWIDTH = 32 - LINE_IX_BITWIDTH - COLUMN_IX_BITWIDTH - ZEROS_BITWIDTH;
  // note: assumes there are 2 bits free after 'TAG_BITWIDTH' for 'valid' and 'dirty' flags

  localparam LINE_VALID_BIT = TAG_BITWIDTH;
  localparam LINE_DIRTY_BIT = TAG_BITWIDTH + 1;
  localparam LINE_TO_RAM_ADDRESS_LEFT_SHIFT = COLUMN_IX_BITWIDTH + ZEROS_BITWIDTH - RAM_ADDRESSING_MODE;

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
  wire [LINE_IX_BITWIDTH-1:0] line_ix =  address[
    LINE_IX_BITWIDTH+COLUMN_IX_BITWIDTH+ZEROS_BITWIDTH-1
    -:LINE_IX_BITWIDTH
  ];
  wire [TAG_BITWIDTH-1:0] address_tag = address[
    TAG_BITWIDTH+LINE_IX_BITWIDTH+COLUMN_IX_BITWIDTH+ZEROS_BITWIDTH-1
    -:TAG_BITWIDTH
  ];

  // starting address of cache line in RAM for current address
  wire [RAM_DEPTH_BITWIDTH-1:0] burst_line_address = {
    address[31:COLUMN_IX_BITWIDTH+ZEROS_BITWIDTH], {LINE_TO_RAM_ADDRESS_LEFT_SHIFT{1'b0}}
  };

  reg burst_is_reading;  // true if in burst read operation
  reg [31:0] burst_data_in[COLUMN_COUNT];
  reg [3:0] burst_write_enable[COLUMN_COUNT];
  reg [3:0] burst_tag_write_enable;

  reg burst_is_writing;  // true if in burst write operation

  wire [31:0] cached_tag_and_flags;
  reg [3:0] tag_write_enable;  // true when cache hit; write to set line dirty
  reg [31:0] tag_data_in;  // tag and flags written when cache hit write

  assign br_data_mask = 0;  // writing whole cache lines

  BESDPB #(
      .ADDRESS_BITWIDTH(LINE_IX_BITWIDTH)
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
  wire [RAM_DEPTH_BITWIDTH-1:0] cached_line_address = {
    {cached_tag, line_ix}, {LINE_TO_RAM_ADDRESS_LEFT_SHIFT{1'b0}}
  };

  wire cache_line_hit = line_valid && address_tag == cached_tag;

  // counts minimum cycles between commands
  reg [5:0] command_delay_interval_counter;

  assign busy = enable && !cache_line_hit || command_delay_interval_counter != 0;

  // select data from requested column
  assign data_out = column_data_out[column_ix];
  assign data_out_ready = write_enable ? 0 : enable && cache_line_hit;

  // 8 instances of byte enabled semi dual port RAM blocks
  // if cache hit at write then connect 'data_in' to the column
  // if cache miss connect to the state machine that loads a cache line
  reg [31:0] column_data_in[COLUMN_COUNT];
  reg [3:0] column_write_enable[COLUMN_COUNT];
  wire [31:0] column_data_out[COLUMN_COUNT];

  generate
    for (genvar i = 0; i < COLUMN_COUNT; i++) begin : column
      BESDPB #(
          .ADDRESS_BITWIDTH(LINE_IX_BITWIDTH)
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
    end else if (write_enable) begin
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

  reg [10:0] state;
  localparam STATE_IDLE = 11'b000_0000_0001;
  localparam STATE_READ_WAIT_FOR_DATA_READY = 11'b000_0000_0010;
  localparam STATE_READ_1 = 11'b000_0000_0100;
  localparam STATE_READ_2 = 11'b000_0000_1000;
  localparam STATE_READ_3 = 11'b000_0001_0000;
  localparam STATE_READ_UPDATE_TAG = 11'b000_0010_0000;
  localparam STATE_READ_FINISH = 11'b000_0100_0000;
  localparam STATE_WRITE_1 = 11'b000_1000_0000;
  localparam STATE_WRITE_2 = 11'b001_0000_0000;
  localparam STATE_WRITE_3 = 11'b010_0000_0000;
  localparam STATE_WRITE_FINISH = 11'b100_0000_0000;

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      burst_tag_write_enable <= 0;
      for (int i = 0; i < COLUMN_COUNT; i++) begin
        burst_write_enable[i] <= 0;
      end
      burst_is_reading <= 0;
      burst_is_writing <= 0;
      command_delay_interval_counter <= 0;
      state <= STATE_IDLE;
    end else begin
`ifdef DBG
      $display("@(c) state: %0d", state);
`endif
      // count down command interval
      if (command_delay_interval_counter != 0) begin
`ifdef DBG
        $display("@(c) command delay interval counter: %0d", command_delay_interval_counter);
`endif
        command_delay_interval_counter <= command_delay_interval_counter - 1;
      end

      case (state)

        STATE_IDLE: begin
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
              command_delay_interval_counter <= COMMAND_DELAY_INTERVAL;
              burst_is_writing <= 1;
              state <= STATE_WRITE_1;
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
              command_delay_interval_counter <= COMMAND_DELAY_INTERVAL;
              burst_is_reading <= 1;
              state <= STATE_READ_WAIT_FOR_DATA_READY;
            end
          end
        end

        STATE_READ_WAIT_FOR_DATA_READY: begin
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
            state <= STATE_READ_1;
          end else begin  // not (br_rd_data_valid)
`ifdef DBG
            $display("@(c) waiting for data valid from RAM");
`endif
          end
        end

        STATE_READ_1: begin
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
          state <= STATE_READ_2;
        end

        STATE_READ_2: begin
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
          state <= STATE_READ_3;
        end

        STATE_READ_3: begin
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
          state <= STATE_READ_UPDATE_TAG;
        end

        STATE_READ_UPDATE_TAG: begin
          // note: reading line can be initiated after a cache eviction
          //       'burst_write_enable[6]' and 7 are then high, set to low
          burst_write_enable[6] <= 0;
          burst_write_enable[7] <= 0;
          burst_tag_write_enable <= 4'b1111;
          state <= STATE_READ_FINISH;
        end

        STATE_READ_FINISH: begin
          // note: tag has been written after read data has settled
          burst_is_reading <= 0;
          burst_tag_write_enable <= 0;
          state <= STATE_IDLE;
        end

        STATE_WRITE_1: begin
`ifdef DBG
          $display("@(c) write line (2): 0x%h%h", column_data_out[2], column_data_out[3]);
`endif
          br_cmd_en <= 0;  // hold command enable only one cycle
          br_wr_data[31:0] <= column_data_out[2];
          br_wr_data[63:32] <= column_data_out[3];
          state <= STATE_WRITE_2;
        end

        STATE_WRITE_2: begin
`ifdef DBG
          $display("@(c) write line (3): 0x%h%h", column_data_out[4], column_data_out[5]);
`endif
          br_wr_data[31:0] <= column_data_out[4];
          br_wr_data[63:32] <= column_data_out[5];
          state <= STATE_WRITE_3;
        end

        STATE_WRITE_3: begin
`ifdef DBG
          $display("@(c) write line (4): 0x%h%h", column_data_out[6], column_data_out[7]);
`endif
          br_wr_data[31:0] <= column_data_out[6];
          br_wr_data[63:32] <= column_data_out[7];
          state <= STATE_WRITE_FINISH;
        end

        STATE_WRITE_FINISH: begin
          // check if need to wait for command interval delay
          if (command_delay_interval_counter == 0) begin
`ifdef DBG
            $display("@(c) read line after eviction from RAM address 0x%h", burst_line_address);
`endif
            // start reading the cache line
            br_cmd <= 0;  // command read
            br_addr <= burst_line_address;
            br_cmd_en <= 1;
            command_delay_interval_counter <= COMMAND_DELAY_INTERVAL;
            burst_is_writing <= 0;
            burst_is_reading <= 1;
            state <= STATE_READ_WAIT_FOR_DATA_READY;
          end else begin
`ifdef DBG
            $display("@(c) waiting for command delay counter %0d", command_delay_interval_counter);
`endif
          end
        end

      endcase
    end
  end

endmodule

`undef DBG
`undef INFO
`default_nettype wire
