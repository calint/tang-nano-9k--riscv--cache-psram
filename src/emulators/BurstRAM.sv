//
// an emulator of a RAM that does burst reads and writes used in simulations
// to mock IP components
//

`timescale 100ps / 100ps
//
`default_nettype none
// `define DBG
// `define INFO

module BurstRAM #(
    parameter DATA_FILE = "",  // initial RAM content
    parameter DEPTH_BITWIDTH = 4,  // 2 ^ 4 * 8 B entries
    parameter DATA_BITWIDTH = 64,  // must be divisible by 8
    parameter BURST_COUNT = 4,  // number of RAM data sizes transfered per burst
    parameter CYCLES_BEFORE_INITIATED = 10,  // emulates initiation delay
    parameter CYCLES_BEFORE_DATA_VALID = 6  // emulates read delay
) (
    input wire clk,
    input wire rst_n,
    input wire cmd,  // 0: read, 1: write
    input wire cmd_en,  // 1: cmd and addr is valid
    input wire [DEPTH_BITWIDTH-1:0] addr,  // 8 bytes word
    input wire [DATA_BITWIDTH-1:0] wr_data,  // data to write
    input wire [DATA_BITWIDTH/8-1:0] data_mask,  // not implemented (same as 0 in IP component)
    output reg [DATA_BITWIDTH-1:0] rd_data,  // read data
    output reg rd_data_valid,  // rd_data is valid
    output reg init_calib,
    output reg busy
);

  localparam DEPTH = 2 ** DEPTH_BITWIDTH;
  localparam CMD_READ = 0;
  localparam CMD_WRITE = 1;

  reg [$clog2(CYCLES_BEFORE_INITIATED):0] init_calib_delay_counter;
  // note: not -1 because it comparison is against CYCLES_BEFORE_INITIATED

  reg [DATA_BITWIDTH-1:0] data[DEPTH-1:0];

  reg [$clog2(BURST_COUNT)-1:0] burst_counter;

  reg [$clog2(CYCLES_BEFORE_DATA_VALID):0] read_delay_counter;
  // note: not -1 because it comparison is against CYCLES_BEFORE_DATA_VALID

  reg [DEPTH-1:0] addr_counter;

  localparam STATE_INITIATE = 5'b00001;
  localparam STATE_IDLE = 5'b00010;
  localparam STATE_READ_DELAY = 5'b00100;
  localparam STATE_READ_BURST = 5'b01000;
  localparam STATE_WRITE_BURST = 5'b10000;

  reg [4:0] state;

  initial begin

`ifdef INFO
    $display("----------------------------------------");
    $display("  BurstRAM");
    $display("----------------------------------------");
    $display("         size: %0d B", DEPTH * DATA_BITWIDTH / 8);
    $display("        depth: %0d", DEPTH);
    $display("    data size: %0d bits", DATA_BITWIDTH);
    $display(" read latency: %0d cycles", CYCLES_BEFORE_DATA_VALID);
    $display("----------------------------------------");
`endif

    if (DATA_FILE != "") begin
      $readmemh(DATA_FILE, data);
    end
  end

  always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      rd_data_valid <= 0;
      rd_data <= 0;
      busy <= 1;
      init_calib <= 0;
      init_calib_delay_counter <= 0;
      state <= STATE_INITIATE;
    end else begin
      // $display("BurstRAM: clk  state: %b", state);
      case (state)

        STATE_INITIATE: begin
          if (init_calib_delay_counter == CYCLES_BEFORE_INITIATED) begin
            busy <= 0;
            init_calib <= 1;
            state <= STATE_IDLE;
          end
          init_calib_delay_counter <= init_calib_delay_counter + 1;
        end

        STATE_IDLE: begin
          if (cmd_en) begin
            busy <= 1;
            burst_counter <= 0;
            case (cmd)
              CMD_READ: begin
                read_delay_counter <= 0;
                addr_counter <= addr;
                state <= STATE_READ_DELAY;

`ifdef DBG
                $display("BurstRAM memory dump:");
                $display("---------------------");
                for (integer i = 0; i < DEPTH; i = i + 1) begin
                  $display("%0d: %h", i, data[i]);
                end
                $display("---------------------");
`endif

              end
              CMD_WRITE: begin
                data[addr] <= wr_data;

`ifdef DBG
                $display("BurstRAM[0x%h]=0x%h", addr, wr_data);
`endif

                addr_counter <= addr + 1;
                // note: +1 because first write is done in this cycle
                state <= STATE_WRITE_BURST;
              end
            endcase
          end
        end

        STATE_READ_DELAY: begin
          if (read_delay_counter == CYCLES_BEFORE_DATA_VALID - 1) begin
            // note: not -1 because state would switch one cycle early
            rd_data_valid <= 1;
            rd_data <= data[addr_counter];
            addr_counter <= addr_counter + 1;
            state <= STATE_READ_BURST;
          end
          read_delay_counter <= read_delay_counter + 1;
        end

        STATE_READ_BURST: begin
          burst_counter <= burst_counter + 1;
          addr_counter  <= addr_counter + 1;
          if (burst_counter == BURST_COUNT - 1) begin
            // note: -1 because of non-blocking assignments
            rd_data_valid <= 0;
            set_new_state_after_command_done;
          end else begin
            rd_data <= data[addr_counter];
          end
        end

        STATE_WRITE_BURST: begin
          burst_counter <= burst_counter + 1;
          addr_counter  <= addr_counter + 1;
          if (burst_counter == BURST_COUNT - 1) begin
            // note: -1 because of non-blocking assignments
            set_new_state_after_command_done;
          end else begin
            data[addr_counter] <= wr_data;

`ifdef DBG
            $display("BurstRAM[0x%h]=0x%h (2)", addr_counter, wr_data);
`endif

          end
        end

        default: ;
      endcase
    end
  end

  task set_new_state_after_command_done;
    begin
      busy  <= 0;
      state <= STATE_IDLE;
      if (cmd_en) begin
        busy <= 1;
        burst_counter <= 0;
        case (cmd)
          CMD_READ: begin
            read_delay_counter <= 0;
            addr_counter <= addr;
            state <= STATE_READ_DELAY;

`ifdef DBG
            $display("BurstRAM memory dump (2):");
            $display("---------------------");
            for (integer i = 0; i < DEPTH; i = i + 1) begin
              $display("%0d: %h", i, data[i]);
            end
            $display("---------------------");
`endif


          end
          CMD_WRITE: begin
            data[addr] <= wr_data;
            addr_counter <= addr + 1;
            // note: +1 because first write is done in this cycle
            state <= STATE_WRITE_BURST;
          end
        endcase
      end
    end
  endtask

endmodule

`undef DBG
`undef INFO
`default_nettype wire
