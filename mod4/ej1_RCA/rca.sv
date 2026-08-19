// rca.sv — Ripple Carry Adder de N bits parametrizable.
//
// Encadena N full adders estructurales usando generate-for. El carry de salida
// de cada full adder es el carry de entrada del siguiente; el ultimo sale por
// `cout`. Carry-in y carry-out son explicitos, como pide el enunciado.
//
// Path critico: el carry "riplea" por toda la cadena, desde cin hasta cout
// (y hasta el bit mas significativo de la suma). Por eso el delay crece 
// linealmente con N: cada etapa agrega ~2 ns de propagacion.

module rca #(
  parameter int N = 8
)(
  input  logic [N-1:0] a,
  input  logic [N-1:0] b,
  input  logic         cin,
  output logic [N-1:0] sum,
  output logic         cout
);

  logic [N:0] carry;

  assign carry[0] = cin;

  genvar i;
  generate
    for (i = 0; i < N; i = i + 1) begin : fa_chain
      full_adder u_fa (
        .a   (a[i]),
        .b   (b[i]),
        .cin (carry[i]),
        .sum (sum[i]),
        .cout(carry[i + 1])
      );
    end
  endgenerate

  assign cout = carry[N];

endmodule