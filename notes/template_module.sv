//
// One line description of the module
//
`timescale 1ns / 1ps
//
`default_nettype none
//`define DBG
//`define INFO

module my_module #(
    parameter int unsigned Width  = 80,
    parameter int unsigned Height = 24
) (
    input  wire              clk_i,
    input  wire              rst_ni,
    input  wire              req_valid_i,
    input  wire  [Width-1:0] req_data_i,
    output logic             req_ready_o
);

  localparam integer unsigned [7:0] MASK_IDLE = 8'hff;

  typedef enum {
    Idle,
    Read
  } state_e;

  state_e state;
  state_e next_state;

  logic [Width-1:0] req_data_masked;

  always_comb begin
    next_state = state;
    case (state)
      Idle: begin
        req_data_masked = req_data_i & MASK_IDLE;
        next_state = Read;
      end

      // ...

    endcase
  end

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      // ...
    end else begin
      // ...
    end
  end

  submodule u_submodule (
      .clk_i,
      .rst_ni,
      .req_valid_i,
      .req_data_i (req_data_masked),
      .req_ready_o(req_ready),
  );

endmodule

`undef DBG
`undef INFO
`default_nettype wire
