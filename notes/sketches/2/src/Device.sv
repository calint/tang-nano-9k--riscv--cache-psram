module Device (
    input  wire  rst_n,
    input  wire  clk,
    input  wire  address,
    // output wire data_out
    output logic data_out
);

  // assign data_out = address;

  always_comb begin
    if (address) begin
      data_out = 1'b1;
    end else begin
      data_out = 1'b0;
    end
  end

endmodule
