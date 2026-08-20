// rca4.sv — Bloque RCA estructural de 4 bits (celula del CSLA).
//
// Encadena 4 full adders (full_adder.sv del ejercicio 1) con un generate-for.
// Es el "sumador interno" que el CSLA duplica: el mismo bloque se instancia
// dos veces por etapa, una con carry-in = 0 y otra con carry-in = 1, y un mux
// decide cuál es la respuesta correcta según el carry que venga del bloque
// anterior.
//
// Aunque es un RCA (el carry "riplea" dentro del bloque), su delay es corto y
// constante: 4 bits de ripple (~10 ns con el modelo de compuertas del ej. 1)
// contra los ~32 ns que paga un RCA de 16 bits. Esa es justamente la idea del
// Carry Select: pagar dos sumadores chicos en paralelo para no pagar el ripple
// largo.

module rca4 (
  input  logic [3:0] a,
  input  logic [3:0] b,
  input  logic       cin,
  output logic [3:0] sum,
  output logic       cout
);

  logic [4:0] carry;

  assign carry[0] = cin;

  genvar i;
  generate
    for (i = 0; i < 4; i = i + 1) begin : fa_chain
      full_adder u_fa (
        .a   (a[i]),
        .b   (b[i]),
        .cin (carry[i]),
        .sum (sum[i]),
        .cout(carry[i + 1])
      );
    end
  endgenerate

  assign cout = carry[4];

endmodule