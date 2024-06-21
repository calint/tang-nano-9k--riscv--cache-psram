module Device (
    input wire rst_n,
    input wire clk,
    input wire [31:0] address,
    output reg [31:0] data_out
);

  localparam ADDRESS_UART_IN = 4'hf;
  reg [7:0] uartrx_data_received;

  always_comb begin
    if (address == ADDRESS_UART_IN) begin
      data_out = {{24{1'b0}}, uartrx_data_received};
    end else begin
      data_out = 32'habcd_1234;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      uartrx_data_received <= 8'hab;
    end else begin
      if (address == ADDRESS_UART_IN) begin
        uartrx_data_received <= 8'h00;
      end
    end
  end
endmodule
