//
// an emulator of a RAM that does burst reads and writes used in simulations
//  mock IP component
//
// reviewed 2024-06-26
//
`timescale 100ps / 100ps
//
`default_nettype none
// `define DBG
// `define INFO

module burst_ram #(
    parameter string DataFilePath = "",
    // initial RAM content; ascii hex, data width

    parameter int unsigned DataBitWidth = 64,
    // must be divisible by 8

    parameter int unsigned AddressBitWidth = 4,
    // 2 ^ 4 * 8 B entries

    parameter int unsigned BurstDataCount = 4,
    // number of RAM data sizes transferred per burst

    parameter int unsigned CyclesBeforeInitiated = 10,
    // emulates initiation delay

    parameter int unsigned CyclesBeforeDataValid = 6
    // emulates read delay
) (
    input wire rst_n,
    input wire clk,

    input wire cmd,
    // 0: read, 1: write

    input wire cmd_en,
    // 1: cmd and addr is valid

    input wire [AddressBitWidth-1:0] addr,
    // in default configuration 8 bytes word

    input wire [DataBitWidth-1:0] wr_data,
    // data to write

    input wire [DataBitWidth/8-1:0] data_mask,
    // not implemented (same as 0 in IP component)

    output logic [DataBitWidth-1:0] rd_data,
    // read data

    output logic rd_data_valid,
    // rd_data is valid

    output logic init_calib,
    // high when RAM is ready for use

    output logic busy
);

  localparam int unsigned DEPTH = 2 ** AddressBitWidth;
  localparam int unsigned CMD_READ = 0;
  localparam int unsigned CMD_WRITE = 1;

  logic [DataBitWidth-1:0] data[DEPTH];

  logic [$clog2(CyclesBeforeInitiated):0] init_calib_delay_counter;
  // note: not -1 because comparison is against CyclesBeforeInitiated

  logic [$clog2(BurstDataCount)-1:0] burst_counter;

  logic [$clog2(CyclesBeforeDataValid)-1:0] read_delay_counter;

  logic [AddressBitWidth-1:0] addr_iter;
  // used in burst read / write

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
    $display("  burst_ram");
    $display("----------------------------------------");
    $display("         size: %0d B", DEPTH * DataBitWidth / 8);
    $display("        depth: %0d", DEPTH);
    $display("    data size: %0d bits", DataBitWidth);
    $display(" read latency: %0d cycles", CyclesBeforeDataValid);
    $display("  burst count: %0d", BurstDataCount);
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
          init_calib_delay_counter <= init_calib_delay_counter + 1'b1;
        end

        Idle: begin
          idle_task();
        end

        ReadDelay: begin
          read_delay_counter <= read_delay_counter + 1'b1;
          if (read_delay_counter == CyclesBeforeDataValid - 1) begin
            rd_data_valid <= 1;
            rd_data <= data[addr_iter];
            addr_iter <= addr_iter + 1'b1;
            state <= ReadBurst;
          end
        end

        ReadBurst: begin
          burst_counter <= burst_counter + 1'b1;
          addr_iter <= addr_iter + 1'b1;
          if (burst_counter == BurstDataCount - 1) begin
            rd_data_valid <= 0;
            state <= Idle;
            idle_task();
          end else begin
            rd_data <= data[addr_iter];
          end
        end

        WriteBurst: begin
          burst_counter <= burst_counter + 1'b1;
          addr_iter <= addr_iter + 1'b1;
          if (burst_counter == BurstDataCount - 1) begin
            state <= Idle;
            idle_task();
          end else begin
            data[addr_iter] <= wr_data;
`ifdef DBG
            $display("burst_ram[0x%h]=0x%h", addr_iter, wr_data);
`endif
          end
        end

        default: ;
      endcase
    end
  end

  task automatic idle_task();
    begin
      busy <= 0;
      if (cmd_en) begin
        busy <= 1;
        burst_counter <= 0;
        unique case (cmd)

          CMD_READ: begin
            read_delay_counter <= 0;
            addr_iter <= addr;
            state <= ReadDelay;
`ifdef DBG
            $display("burst_ram memory dump:");
            $display("---------------------");
            for (int i = 0; i < DEPTH; i++) begin
              $display("%0d: %h", i, data[i]);
            end
            $display("---------------------");
`endif
          end

          CMD_WRITE: begin
            data[addr] <= wr_data;
            addr_iter <= addr + 1'b1;
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
