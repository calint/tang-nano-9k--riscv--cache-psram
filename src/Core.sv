//
// RISC-V rv32i reduced core
//
`timescale 100ps / 100ps
//
`default_nettype none
// `define DBG
// `define INFO

module Core #(
    parameter STARTUP_WAIT = 1_000_000,
    parameter FLASH_TRANSFER_BYTES_NUM = 32'h0010_0000
) (
    input  wire clk,
    input  wire rst_n,
    output reg  led,

    // RAMIO
    output reg ramio_enable,

    // b00 not a write; b01: byte, b10: half word, b11: word
    output reg [1:0] ramio_write_type,

    // b000 not a read; bit[2] flags sign extended or not, b01: byte, b10: half word, b11: word
    output reg [2:0] ramio_read_type,

    // address in bytes
    output reg [31:0] ramio_address,

    // sign extended byte, half word, word
    output reg [31:0] ramio_data_in,

    // data at 'address' according to 'read_type'
    input wire [31:0] ramio_data_out,

    input wire ramio_data_out_ready,

    input wire ramio_busy,

    // flash
    output reg  flash_clk,
    input  wire flash_miso,
    output reg  flash_mosi,
    output reg  flash_cs
);

  // used while reading flash
  reg [23:0] flash_data_to_send;
  reg [4:0] flash_bits_to_send;
  reg [31:0] flash_counter;
  reg [7:0] flash_current_byte_out;
  reg [7:0] flash_current_byte_num;
  reg [7:0] flash_data_in[4];

  // used while reading flash to increment 'cache_address'
  reg [31:0] ramio_address_next;

  localparam STATE_BOOT_INIT_POWER = 0;
  localparam STATE_BOOT_LOAD_CMD_TO_SEND = 1;
  localparam STATE_BOOT_SEND = 2;
  localparam STATE_BOOT_LOAD_ADDRESS_TO_SEND = 3;
  localparam STATE_BOOT_READ_DATA = 4;
  localparam STATE_BOOT_START_WRITE = 5;
  localparam STATE_BOOT_WRITE = 6;
  localparam STATE_CPU_FETCH = 7;
  localparam STATE_CPU_EXECUTE = 8;
  localparam STATE_CPU_STORE = 9;
  localparam STATE_CPU_LOAD = 10;
  localparam STATE_CPU_LOAD_DONE = 11;

  reg [3:0] state = 0;
  reg [3:0] return_state = 0;

  // CPU state
  reg [31:0] pc;  // program counter
  reg [31:0] pc_next;  // next instruction
  reg [31:0] ir;  // instruction register (one cycle delay due to ram access)
  reg [4:0] rs1;  // source register 1
  reg [4:0] rs2;  // source register 2
  reg [4:0] rd;  // destination register
  reg [6:0] opcode;
  reg [2:0] funct3;
  reg [6:0] funct7;
  wire signed [31:0] I_imm12 = {{20{ir[31]}}, ir[31:20]};
  wire [31:0] U_imm20 = {ir[31:12], {12{1'b0}}};
  wire signed [31:0] S_imm12 = {{20{ir[31]}}, ir[31:25], ir[11:7]};
  wire signed [31:0] B_imm12 = {{20{ir[31]}}, ir[7], ir[30:25], ir[11:8], 1'b0};
  wire signed [31:0] J_imm20 = {{12{ir[31]}}, ir[19:12], ir[20], ir[30:21], 1'b0};

  wire signed [31:0] rs1_dat;  // register 'rs1' data
  wire signed [31:0] rs2_dat;  // register 'rs2' data
  reg [31:0] rd_wd;  // register write data
  reg rd_we;  // register write enable
  //

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      ramio_enable <= 0;
      ramio_read_type <= 0;
      ramio_write_type <= 0;
      ramio_address <= 0;
      ramio_address_next <= 0;
      ramio_data_in <= 0;
      pc <= 0;

      led <= 1;

      flash_counter <= 0;
      flash_clk <= 0;
      flash_mosi <= 0;
      flash_cs <= 1;

      state <= STATE_BOOT_INIT_POWER;

    end else begin
`ifdef DBG
      $display("state: %0d", state);
`endif
      case (state)

        STATE_BOOT_INIT_POWER: begin
          if (flash_counter >= STARTUP_WAIT) begin
            flash_counter <= 0;
            state <= STATE_BOOT_LOAD_CMD_TO_SEND;
          end else begin
            flash_counter <= flash_counter + 1;
          end
        end

        STATE_BOOT_LOAD_CMD_TO_SEND: begin
          flash_cs <= 0;
          flash_data_to_send[23-:8] <= 3;  // command 3: read
          flash_bits_to_send <= 8;
          state <= STATE_BOOT_SEND;
          return_state <= STATE_BOOT_LOAD_ADDRESS_TO_SEND;
        end

        STATE_BOOT_LOAD_ADDRESS_TO_SEND: begin
          flash_data_to_send <= 0;  // address 0x0
          flash_bits_to_send <= 24;
          flash_current_byte_num <= 0;
          state <= STATE_BOOT_SEND;
          return_state <= STATE_BOOT_READ_DATA;
        end

        STATE_BOOT_SEND: begin
          if (flash_counter == 0) begin
            // at clock to low
            flash_clk <= 0;
            flash_mosi <= flash_data_to_send[23];
            flash_data_to_send <= {flash_data_to_send[22:0], 1'b0};
            flash_bits_to_send <= flash_bits_to_send - 1;
            flash_counter <= 1;
          end else begin
            // at clock to high
            flash_counter <= 0;
            flash_clk <= 1;
            if (flash_bits_to_send == 0) begin
              state <= return_state;
            end
          end
        end

        STATE_BOOT_READ_DATA: begin
          if (!flash_counter[0]) begin
            flash_clk <= 0;
            flash_counter <= flash_counter + 1;
            if (flash_counter[3:0] == 0 && flash_counter > 0) begin
              // every 16 clock ticks (8 bit * 2)
              flash_data_in[flash_current_byte_num] <= flash_current_byte_out;
              flash_current_byte_num <= flash_current_byte_num + 1;
              if (flash_current_byte_num == 3) begin
                state <= STATE_BOOT_START_WRITE;
              end
            end
          end else begin
            flash_clk <= 1;
            flash_current_byte_out <= {flash_current_byte_out[6:0], flash_miso};
            flash_counter <= flash_counter + 1;
          end
        end

        STATE_BOOT_START_WRITE: begin
          if (!ramio_busy) begin
            ramio_enable <= 1;
            ramio_read_type <= 0;
            ramio_write_type <= 2'b11;
            ramio_address <= ramio_address_next;
            ramio_address_next <= ramio_address_next + 4;
            ramio_data_in <= {
              flash_data_in[3], flash_data_in[2], flash_data_in[1], flash_data_in[0]
            };
            state <= STATE_BOOT_WRITE;
          end
        end

        STATE_BOOT_WRITE: begin
          if (!ramio_busy) begin
            ramio_enable <= 0;
            flash_current_byte_num <= 0;
            if (ramio_address_next < FLASH_TRANSFER_BYTES_NUM) begin
              state <= STATE_BOOT_READ_DATA;
            end else begin
              flash_cs <= 1;

              // boot address
              ramio_enable <= 1;
              ramio_read_type <= 3'b111;
              ramio_write_type <= 0;
              ramio_address <= 0;

              pc <= 0;

              state <= STATE_CPU_FETCH;
            end
          end
        end

        STATE_CPU_FETCH: begin
          // if register write during this cycle, turn it off at next
          rd_we <= 0;
          if (ramio_data_out_ready) begin

`ifdef DBG
            $display("fetched: %h", ramio_data_out);
`endif

            ir <= ramio_data_out;
            rs1 <= ramio_data_out[19:15];  // source register 1
            rs2 <= ramio_data_out[24:20];  // source register 2
            rd <= ramio_data_out[11:7];  // destination register
            opcode <= ramio_data_out[6:0];
            funct3 <= ramio_data_out[14:12];
            funct7 <= ramio_data_out[31:25];
            pc_next <= pc + 4;  // assume next instruction
            state <= STATE_CPU_EXECUTE;
          end
        end

        STATE_CPU_EXECUTE: begin
          // default next state is FETCH next instruction
          ramio_enable <= 1;
          ramio_read_type <= 3'b111;
          ramio_write_type <= 0;
          ramio_address <= pc_next;
          pc <= pc_next;
          state <= STATE_CPU_FETCH;

          case (opcode)
            7'b0110111: begin  // LUI
              rd_wd <= U_imm20;
              rd_we <= 1;
            end
            7'b0010011: begin  // logical ops immediate
              rd_we <= 1;
              case (funct3)
                3'b000: begin  // ADDI
                  rd_wd <= rs1_dat + I_imm12;
                end
                3'b010: begin  // SLTI
                  rd_wd <= rs1_dat < I_imm12;
                end
                3'b011: begin  // SLTIU
                  rd_wd <= $unsigned(rs1_dat) < $unsigned(I_imm12);
                end
                3'b100: begin  // XORI
                  rd_wd <= rs1_dat ^ I_imm12;
                end
                3'b110: begin  // ORI
                  rd_wd <= rs1_dat | I_imm12;
                end
                3'b111: begin  // ANDI
                  rd_wd <= rs1_dat & I_imm12;
                end
                3'b001: begin  // SLLI
                  rd_wd <= rs1_dat << rs2;
                end
                3'b101: begin  // SRLI and SRAI
                  rd_wd <= ir[30] ? rs1_dat >>> rs2 : rs1_dat >> rs2;
                end
              endcase  // case (funct3)
            end
            7'b0110011: begin  // logical ops
              rd_we <= 1;
              case (funct3)
                3'b000: begin  // ADD and SUB
                  rd_wd <= ir[30] ? rs1_dat - rs2_dat : rs1_dat + rs2_dat;
                end
                3'b001: begin  // SLL
                  rd_wd <= rs1_dat << rs2_dat[4:0];
                end
                3'b010: begin  // SLT
                  rd_wd <= rs1_dat < rs2_dat;
                end
                3'b011: begin  // SLTU
                  rd_wd <= $unsigned(rs1_dat) < $unsigned(rs2_dat);
                end
                3'b100: begin  // XOR
                  rd_wd <= rs1_dat ^ rs2_dat;
                end
                3'b101: begin  // SRL and SRA
                  rd_wd <= ir[30] ? rs1_dat >>> rs2_dat[4:0] : rs1_dat >> rs2_dat[4:0];
                end
                3'b110: begin  // OR
                  rd_wd <= rs1_dat | rs2_dat;
                end
                3'b111: begin  // AND
                  rd_wd <= rs1_dat & rs2_dat;
                end
              endcase  // case (funct3)
            end
            7'b0100011: begin  // store
              ramio_read_type <= 0;
              ramio_address <= rs1_dat + S_imm12;
              ramio_data_in <= rs2_dat;
              state <= STATE_CPU_STORE;
              case (funct3)
                3'b000: begin  // SB
                  ramio_write_type <= 2'b01;  // write byte
                end
                3'b001: begin  // SH
                  ramio_write_type <= 2'b10;  // write half word
                end
                3'b010: begin  // SW
                  ramio_write_type <= 2'b11;  // write word
                end
              endcase  // case (funct3)
            end
            7'b0000011: begin  // load
              ramio_write_type <= 0;
              ramio_address <= rs1_dat + I_imm12;
              state <= STATE_CPU_LOAD;
              case (funct3)
                3'b000: begin  // LB
                  ramio_read_type <= 3'b101;  // read sign extended byte
                end
                3'b001: begin  // LH
                  ramio_read_type <= 3'b110;  // read sign extended half word
                end
                3'b010: begin  // LW
                  ramio_read_type <= 3'b111;  // read word (signed)
                end
                3'b100: begin  // LBU
                  ramio_read_type <= 3'b001;  // read unsigned byte
                end
                3'b101: begin  // LHU
                  ramio_read_type <= 3'b010;  // read unsigned half word
                end
              endcase  // case (funct3)
            end
            7'b0010111: begin  // AUIPC
              rd_wd <= pc + U_imm20;
              rd_we <= 1;
            end
            7'b1101111: begin  // JAL
              rd_wd <= pc + 4;
              rd_we <= 1;
              ramio_address <= pc + J_imm20;
              pc <= pc + J_imm20;
            end
            7'b1100111: begin  // JALR
              rd_wd <= pc + 4;
              rd_we <= 1;
              ramio_address <= rs1_dat + I_imm12;
              pc <= rs1_dat + I_imm12;
            end
            7'b1100011: begin  // branches
              case (funct3)
                3'b000: begin  // BEQ
                  if (rs1_dat == rs2_dat) begin
                    ramio_address <= pc + B_imm12;
                    pc <= pc + B_imm12;
                  end
                end
                3'b001: begin  // BNE
                  if (rs1_dat != rs2_dat) begin
                    ramio_address <= pc + B_imm12;
                    pc <= pc + B_imm12;
                  end
                end
                3'b100: begin  // BLT
                  if (rs1_dat < rs2_dat) begin
                    ramio_address <= pc + B_imm12;
                    pc <= pc + B_imm12;
                  end
                end
                3'b101: begin  // BGE
                  if (rs1_dat >= rs2_dat) begin
                    ramio_address <= pc + B_imm12;
                    pc <= pc + B_imm12;
                  end
                end
                3'b110: begin  // BLTU
                  if ($unsigned(rs1_dat) < $unsigned(rs2_dat)) begin
                    ramio_address <= pc + B_imm12;
                    pc <= pc + B_imm12;
                  end
                end
                3'b111: begin  // BGEU
                  if ($unsigned(rs1_dat) >= $unsigned(rs2_dat)) begin
                    ramio_address <= pc + B_imm12;
                    pc <= pc + B_imm12;
                  end
                end
              endcase  // case (funct3)
            end
          endcase  // case (opcode)
        end

        STATE_CPU_STORE: begin
          if (!ramio_busy) begin
            // next instruction
            ramio_enable <= 1;
            ramio_read_type <= 3'b111;
            ramio_write_type <= 0;
            ramio_address <= pc;
            state <= STATE_CPU_FETCH;
          end
        end

        STATE_CPU_LOAD: begin
          if (ramio_data_out_ready) begin
            // write register
            rd_we <= 1;
            rd_wd <= ramio_data_out;
`ifdef DBG
            $display("write register[%0d] = 0x%h", rd, ramio_data_out);
`endif
            state <= STATE_CPU_LOAD_DONE;
          end
        end

        STATE_CPU_LOAD_DONE: begin
          // next instruction
          rd_we <= 0;
          ramio_enable <= 1;
          ramio_read_type <= 3'b111;
          ramio_write_type <= 0;
          ramio_address <= pc;
          state <= STATE_CPU_FETCH;
        end

      endcase
    end
  end

  Registers registers (
      .clk(clk),
      .rs1(rs1),
      .rd1(rs1_dat),
      .rs2(rs2),
      .rd(rd),
      .rd2(rs2_dat),
      .rd_wd(rd_wd),
      .rd_we(rd_we)
  );

endmodule

`undef DBG
`undef INFO
`default_nettype wire
