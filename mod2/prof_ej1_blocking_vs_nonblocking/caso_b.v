// caso_b.v — versión con non-blocking (<=) — BUEN ESTILO
`timescale 1ns/1ps

module caso_b (
  input  wire        clk,
  input  wire        rst_n,
  output reg  [3:0]  a,
  output reg  [3:0]  b,
  output reg  [3:0]  c
);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a <= 4'd1;
      b <= 4'd2;
      c <= 4'd3;
    end else begin
      // Non-blocking — rotador circular
      a <= b;
      b <= c;
      c <= a;
    end
  end

endmodule
