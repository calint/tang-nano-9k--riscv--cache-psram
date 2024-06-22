//
// RISC-V rv32i reduced core
//
`timescale 100ps / 100ps
//
`default_nettype none
// `define DBG
// `define INFO

module core #(
    parameter int unsigned StartupWaitCycles  = 1_000_000,
    parameter int unsigned FlashTransferBytes = 32'h0010_0000
) (
    input wire rst_n,
    input wire clk,

    output logic led,

    output logic ramio_enable,
    // enables RAMIO

    output logic [1:0] ramio_write_type,
    // b00 not a write; b01: byte, b10: half word, b11: word

    output logic [2:0] ramio_read_type,
    // b000 not a read; bit[2] flags sign extended or not, b01: byte, b10: half word, b11: word

    output logic [31:0] ramio_address,
    // address in bytes

    output logic [31:0] ramio_data_in,
    // sign extended byte, half word, word

    input wire [31:0] ramio_data_out,
    // data at 'address' according to 'read_type'

    input wire ramio_data_out_ready,

    input wire ramio_busy,

    // flash
    output logic flash_clk,
    input  wire  flash_miso,
    output logic flash_mosi,
    output logic flash_cs
);

  // used while reading flash
  logic [23:0] flash_data_to_send;
  logic [4:0] flash_bits_to_send;
  logic [31:0] flash_counter;
  logic [7:0] flash_current_byte_out;
  logic [7:0] flash_current_byte_num;
  logic [7:0] flash_data_in[4];

  // used while reading flash to increment 'cache_address'
  logic [31:0] ramio_address_next;

  typedef enum {
    BootInit,
    BootLoadCommandToSend,
    BootSend,
    BootLoadAddressToSend,
    BootReadData,
    BootStartWrite,
    BootWrite,
    CpuFetch,
    CpuExecute,
    CpuStore,
    CpuLoad,
    CpuLoadDone
  } state_e;

  state_e state;
  state_e return_state;

  // CPU state
  logic [31:0] pc;  // program counter
  logic [31:0] ir;  // instruction logicister
  logic [4:0] rs1;  // source register 1
  logic [4:0] rs2;  // source register 2
  logic [4:0] rd;  // destination register
  logic [6:0] opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;
  // immediate encodings
  wire [31:0] U_imm20 = {ir[31:12], {12{1'b0}}};
  wire signed [31:0] I_imm12 = {{20{ir[31]}}, ir[31:20]};
  wire signed [31:0] S_imm12 = {{20{ir[31]}}, ir[31:25], ir[11:7]};
  wire signed [31:0] B_imm12 = {{20{ir[31]}}, ir[7], ir[30:25], ir[11:8], 1'b0};
  wire signed [31:0] J_imm20 = {{12{ir[31]}}, ir[19:12], ir[20], ir[30:21], 1'b0};
  // registers output data
  logic signed [31:0] rs1_data_out;
  logic signed [31:0] rs2_data_out;
  // register write back
  logic [31:0] rd_data_in;
  logic rd_write_enable;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ramio_enable <= 0;
      ramio_read_type <= 0;
      ramio_write_type <= 0;
      ramio_address <= 0;
      ramio_address_next <= 0;
      ramio_data_in <= 0;

      flash_counter <= 0;
      flash_clk <= 0;
      flash_mosi <= 0;
      flash_cs <= 1;

      pc <= 0;

      led <= 1;

      state <= BootInit;

    end else begin
`ifdef DBG
      $display("state: %0d", state);
`endif
      unique case (state)

        BootInit: begin
          flash_counter <= flash_counter + 1;
          if (flash_counter >= StartupWaitCycles) begin
            flash_counter <= 0;
            state <= BootLoadCommandToSend;
          end
        end

        BootLoadCommandToSend: begin
          flash_cs <= 0;
          flash_data_to_send[23-:8] <= 3;  // command 3: read
          flash_bits_to_send <= 8;
          state <= BootSend;
          return_state <= BootLoadAddressToSend;
        end

        BootLoadAddressToSend: begin
          flash_data_to_send <= 0;  // address 0x0
          flash_bits_to_send <= 24;
          flash_current_byte_num <= 0;
          state <= BootSend;
          return_state <= BootReadData;
        end

        BootSend: begin
          if (flash_counter == 0) begin
            // at clock to low
            flash_clk <= 0;
            flash_mosi <= flash_data_to_send[23];
            flash_data_to_send <= {flash_data_to_send[22:0], 1'b0};
            flash_bits_to_send <= flash_bits_to_send - 1'b1;
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

        BootReadData: begin
          if (!flash_counter[0]) begin
            flash_clk <= 0;
            flash_counter <= flash_counter + 1;
            if (flash_counter[3:0] == 0 && flash_counter > 0) begin
              // every 16 clock ticks (8 bit * 2)
              flash_data_in[flash_current_byte_num] <= flash_current_byte_out;
              flash_current_byte_num <= flash_current_byte_num + 1'b1;
              if (flash_current_byte_num == 3) begin
                state <= BootStartWrite;
              end
            end
          end else begin
            flash_clk <= 1;
            flash_current_byte_out <= {flash_current_byte_out[6:0], flash_miso};
            flash_counter <= flash_counter + 1;
          end
        end

        BootStartWrite: begin
          if (!ramio_busy) begin
            ramio_enable <= 1;
            ramio_read_type <= 0;
            ramio_write_type <= 2'b11;
            ramio_address <= ramio_address_next;
            ramio_address_next <= ramio_address_next + 4;
            ramio_data_in <= {
              flash_data_in[3], flash_data_in[2], flash_data_in[1], flash_data_in[0]
            };
            state <= BootWrite;
          end
        end

        BootWrite: begin
          if (!ramio_busy) begin
            ramio_enable <= 0;
            flash_current_byte_num <= 0;
            if (ramio_address_next < FlashTransferBytes) begin
              state <= BootReadData;
            end else begin
              flash_cs <= 1;

              // boot address
              ramio_enable <= 1;
              ramio_read_type <= 3'b111;
              ramio_write_type <= 0;
              ramio_address <= 0;

              pc <= 0;

              state <= CpuFetch;
            end
          end
        end

        CpuFetch: begin
          // disable register write in case it was writing during this cycle
          rd_write_enable <= 0;

          if (ramio_data_out_ready) begin
`ifdef DBG
            $display("fetched: %h", ramio_data_out);
`endif
            // copy instruction parts from RAM output
            ir <= ramio_data_out;
            rs1 <= ramio_data_out[19:15];
            rs2 <= ramio_data_out[24:20];
            rd <= ramio_data_out[11:7];
            opcode <= ramio_data_out[6:0];
            funct3 <= ramio_data_out[14:12];
            funct7 <= ramio_data_out[31:25];

            state <= CpuExecute;
          end
        end

        CpuExecute: begin
          // default next state is FETCH next instruction
          // initially configure 'ramio' for that
          ramio_enable <= 1;
          ramio_read_type <= 3'b111;
          ramio_write_type <= 0;
          ramio_address <= pc + 4;
          pc <= pc + 4;
          state <= CpuFetch;

          // execute instruction (part 1)
          unique case (opcode)
            7'b0110111: begin  // LUI
              rd_data_in <= U_imm20;
              rd_write_enable <= 1;
            end
            7'b0010011: begin  // logical ops immediate
              rd_write_enable <= 1;
              unique case (funct3)
                3'b000: begin  // ADDI
                  rd_data_in <= rs1_data_out + I_imm12;
                end
                3'b010: begin  // SLTI
                  rd_data_in <= rs1_data_out < I_imm12;
                end
                3'b011: begin  // SLTIU
                  rd_data_in <= unsigned'(rs1_data_out) < unsigned'(I_imm12);
                end
                3'b100: begin  // XORI
                  rd_data_in <= rs1_data_out ^ I_imm12;
                end
                3'b110: begin  // ORI
                  rd_data_in <= rs1_data_out | I_imm12;
                end
                3'b111: begin  // ANDI
                  rd_data_in <= rs1_data_out & I_imm12;
                end
                3'b001: begin  // SLLI
                  rd_data_in <= rs1_data_out << rs2;
                end
                3'b101: begin  // SRLI and SRAI
                  rd_data_in <= ir[30] ? rs1_data_out >>> rs2 : rs1_data_out >> rs2;
                end
                default: ;
              endcase  // case (funct3)
            end
            7'b0110011: begin  // logical ops
              rd_write_enable <= 1;
              unique case (funct3)
                3'b000: begin  // ADD and SUB
                  rd_data_in <= ir[30] ? rs1_data_out - rs2_data_out : rs1_data_out + rs2_data_out;
                end
                3'b001: begin  // SLL
                  rd_data_in <= rs1_data_out << rs2_data_out[4:0];
                end
                3'b010: begin  // SLT
                  rd_data_in <= rs1_data_out < rs2_data_out;
                end
                3'b011: begin  // SLTU
                  rd_data_in <= unsigned'(rs1_data_out) < unsigned'(rs2_data_out);
                end
                3'b100: begin  // XOR
                  rd_data_in <= rs1_data_out ^ rs2_data_out;
                end
                3'b101: begin  // SRL and SRA
                  rd_data_in <= ir[30] ? rs1_data_out >>> rs2_data_out[4:0] : rs1_data_out >> rs2_data_out[4:0];
                end
                3'b110: begin  // OR
                  rd_data_in <= rs1_data_out | rs2_data_out;
                end
                3'b111: begin  // AND
                  rd_data_in <= rs1_data_out & rs2_data_out;
                end
                default: ;
              endcase  // case (funct3)
            end
            7'b0100011: begin  // store
              ramio_read_type <= 0;
              ramio_address   <= rs1_data_out + S_imm12;
              ramio_data_in   <= rs2_data_out;
              unique case (funct3)
                3'b000: begin  // SB
                  ramio_write_type <= 2'b01;  // write byte
                end
                3'b001: begin  // SH
                  ramio_write_type <= 2'b10;  // write half word
                end
                3'b010: begin  // SW
                  ramio_write_type <= 2'b11;  // write word
                end
                default: ;
              endcase  // case (funct3)
              state <= CpuStore;
            end
            7'b0000011: begin  // load
              ramio_write_type <= 0;
              ramio_address <= rs1_data_out + I_imm12;
              unique case (funct3)
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
                default: ;
              endcase  // case (funct3)
              state <= CpuLoad;
            end
            7'b0010111: begin  // AUIPC
              rd_data_in <= pc + U_imm20;
              rd_write_enable <= 1;
            end
            7'b1101111: begin  // JAL
              rd_data_in <= pc + 4;
              rd_write_enable <= 1;
              ramio_address <= pc + J_imm20;
              pc <= pc + J_imm20;
            end
            7'b1100111: begin  // JALR
              rd_data_in <= pc + 4;
              rd_write_enable <= 1;
              ramio_address <= rs1_data_out + I_imm12;
              pc <= rs1_data_out + I_imm12;
            end
            7'b1100011: begin  // branches
              unique case (funct3)
                3'b000: begin  // BEQ
                  if (rs1_data_out == rs2_data_out) begin
                    ramio_address <= pc + B_imm12;
                    pc <= pc + B_imm12;
                  end
                end
                3'b001: begin  // BNE
                  if (rs1_data_out != rs2_data_out) begin
                    ramio_address <= pc + B_imm12;
                    pc <= pc + B_imm12;
                  end
                end
                3'b100: begin  // BLT
                  if (rs1_data_out < rs2_data_out) begin
                    ramio_address <= pc + B_imm12;
                    pc <= pc + B_imm12;
                  end
                end
                3'b101: begin  // BGE
                  if (rs1_data_out >= rs2_data_out) begin
                    ramio_address <= pc + B_imm12;
                    pc <= pc + B_imm12;
                  end
                end
                3'b110: begin  // BLTU
                  if (unsigned'(rs1_data_out) < unsigned'(rs2_data_out)) begin
                    ramio_address <= pc + B_imm12;
                    pc <= pc + B_imm12;
                  end
                end
                3'b111: begin  // BGEU
                  if (unsigned'(rs1_data_out) >= unsigned'(rs2_data_out)) begin
                    ramio_address <= pc + B_imm12;
                    pc <= pc + B_imm12;
                  end
                end
                default: ;
              endcase  // case (funct3)
            end
            default: ;
          endcase  // case (opcode)
        end

        CpuStore: begin
          if (!ramio_busy) begin
            // read next instruction
            ramio_enable <= 1;
            ramio_read_type <= 3'b111;
            ramio_write_type <= 0;
            ramio_address <= pc;
            state <= CpuFetch;
          end
        end

        CpuLoad: begin
          if (ramio_data_out_ready) begin
            // write to register
            rd_write_enable <= 1;
            rd_data_in <= ramio_data_out;
`ifdef DBG
            $display("write register[%0d] = 0x%h", rd, ramio_data_out);
`endif
            state <= CpuLoadDone;
          end
        end

        CpuLoadDone: begin
          // register written
          rd_write_enable <= 0;

          // next instruction
          ramio_enable <= 1;
          ramio_read_type <= 3'b111;
          ramio_write_type <= 0;
          ramio_address <= pc;
          state <= CpuFetch;
        end

        default: ;

      endcase
    end
  end

  registers registers (
      .clk,
      .rs1,
      .rs1_data_out,
      .rs2,
      .rs2_data_out,
      .rd,
      .rd_write_enable,
      .rd_data_in
  );

endmodule

`undef DBG
`undef INFO
`default_nettype wire
