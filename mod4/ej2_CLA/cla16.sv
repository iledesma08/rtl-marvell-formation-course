// cla16.sv — CLA jerarquico de 16 bits: cuatro bloques cla4 encadenados.
//
// Se arma con generate-for en grupos de 4 bits. Cada bloque cla4 resuelve sus
// carries internos con lookahead (en paralelo) y entrega su carry-out, que se
// convierte en el carry-in del bloque siguiente: es el "lookahead inter-bloque
// por carry" que pide el enunciado.
//
// La clave es que el carry ya no "riplea" bit a bit como en RCA: dentro de 
// cada bloque de 4 bits se calcula en paralelo con un arbol de compuertas, 
// y entre bloques "salta" en un solo paso (~2 ns por bloque en vez de ~2 
// ns por bit). El primer bloque además tiene el lookahead interno (~8 ns), 
// por eso el total del CLA16 dio 17 ns y no 4×2
// 
// Para sumadores mas anchos se podria agregar un segundo nivel de lookahead 
// entre bloques. Por ejemplo si el sumador fuera de 64 bits, tendriamos 16 
// bloques cla4 que podemos dividir en otros 4 bloques. El delay pasaria a 
// crecer con log(N).

module cla16 (
  input  logic [15:0] a,
  input  logic [15:0] b,
  input  logic        cin,
  output logic [15:0] sum,
  output logic        cout
);

  // cblk[i] = carry de entrada del bloque i; cblk[i+1] = carry-out del bloque i.
  logic [4:0] cblk;

  assign cblk[0] = cin;

  genvar i;
  generate
    for (i = 0; i < 4; i = i + 1) begin : cla_blocks
      cla4 u_cla (
        .a   (a[i*4 +: 4]),
        .b   (b[i*4 +: 4]),
        .cin (cblk[i]),
        .sum (sum[i*4 +: 4]),
        .cout(cblk[i + 1])
      );
    end
  endgenerate

  assign cout = cblk[4];

endmodule