//
// an emulator of a RAM that does burst reads and writes used in simulations
//  mock IP component
//
`timescale 100ps / 100ps
//
`default_nettype none
// `define DBG
// `define INFO

module burst_ram #(
    parameter string DataFilePath = "",  // initial RAM content
    parameter int unsigned AddressBitWidth = 4,  // 2 ^ 4 * 8 B entries
    parameter int unsigned DataBitWidth = 64,  // must be divisible by 8
    parameter int unsigned BurstDataCount = 4,  // number of RAM data sizes transfered per burst
    parameter int unsigned CyclesBeforeInitiated = 10,  // emulates initiation delay
    parameter int unsigned CyclesBeforeDataValid = 6  // emulates read delay
) (
    input wire rst_n,
    input wire clk,

    input wire cmd,  // 0: read, 1: write
    input wire cmd_en,  // 1: cmd and addr is valid
    input wire [AddressBitWidth-1:0] addr,  // 8 bytes word
    input wire [DataBitWidth-1:0] wr_data,  // data to write
    input wire [DataBitWidth/8-1:0] data_mask,  // not implemented (same as 0 in IP component)
    output logic [DataBitWidth-1:0] rd_data,  // read data
    output logic rd_data_valid,  // rd_data is valid
    output logic init_calib,
    output logic busy
);

  localparam int unsigned DEPTH = 2 ** AddressBitWidth;
  localparam int unsigned CMD_READ = 0;
  localparam int unsigned CMD_WRITE = 1;

  logic [$clog2(CyclesBeforeInitiated):0] init_calib_delay_counter;
  // note: not -1 because it comparison is against CyclesBeforeInitiated

  logic [DataBitWidth-1:0] data[DEPTH];

  logic [$clog2(BurstDataCount)-1:0] burst_counter;

  logic [$clog2(CyclesBeforeDataValid):0] read_delay_counter;
  // note: not -1 because it is comparison with CyclesBeforeDataValid

  logic [AddressBitWidth-1:0] addr_counter;

  typedef enum {
    Initiate,
    Idle,
    ReadDelay,
    ReadBurst,
    WriteBurst
  } state_e;

  state_e state;

  initial begin

`ifdef INFO
    $display("----------------------------------------");
    $display("  BurstRAM");
    $display("----------------------------------------");
    $display("         size: %0d B", DEPTH * DataBitWidth / 8);
    $display("        depth: %0d", DEPTH);
    $display("    data size: %0d bits", DataBitWidth);
    $display(" read latency: %0d cycles", CyclesBeforeDataValid);
    $display("----------------------------------------");
`endif

    if (DataFilePath != "") begin
      $readmemh(DataFilePath, data);
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rd_data_valid <= 0;
      rd_data <= 0;
      busy <= 1;
      init_calib <= 0;
      init_calib_delay_counter <= 0;
      state <= Initiate;
    end else begin
      unique case (state)

        Initiate: begin
          if (init_calib_delay_counter == CyclesBeforeInitiated) begin
            busy <= 0;
            init_calib <= 1;
            state <= Idle;
          end
          init_calib_delay_counter <= init_calib_delay_counter + 1;
        end

        Idle: begin
          if (cmd_en) begin
            busy <= 1;
            burst_counter <= 0;
            unique case (cmd)
              CMD_READ: begin
                read_delay_counter <= 0;
                addr_counter <= addr;
                state <= ReadDelay;
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
                state <= WriteBurst;
              end
            endcase
          end
        end

        ReadDelay: begin
          if (read_delay_counter == CyclesBeforeDataValid - 1) begin
            // note: not -1 because state would switch one cycle early
            rd_data_valid <= 1;
            rd_data <= data[addr_counter];
            addr_counter <= addr_counter + 1;
            state <= ReadBurst;
          end
          read_delay_counter <= read_delay_counter + 1;
        end

        ReadBurst: begin
          burst_counter <= burst_counter + 1;
          addr_counter  <= addr_counter + 1;
          if (burst_counter == BurstDataCount - 1) begin
            // note: -1 because of non-blocking assignments
            rd_data_valid <= 0;
            set_new_state_after_command_done;
          end else begin
            rd_data <= data[addr_counter];
          end
        end

        WriteBurst: begin
          burst_counter <= burst_counter + 1;
          addr_counter  <= addr_counter + 1;
          if (burst_counter == BurstDataCount - 1) begin
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

  task automatic set_new_state_after_command_done;
    begin
      busy  <= 0;
      state <= Idle;
      if (cmd_en) begin
        busy <= 1;
        burst_counter <= 0;
        unique case (cmd)

          CMD_READ: begin
            read_delay_counter <= 0;
            addr_counter <= addr;
            state <= ReadDelay;
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
            state <= WriteBurst;
          end

          default: ;
        endcase
      end
    end
  endtask

endmodule

`undef DBG
`undef INFO
`default_nettype wire
