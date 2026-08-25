// cla16.sv — CLA jerarquico de 16 bits con DOS niveles de lookahead (v2).
//
// Igual que la v1 se arma con cuatro bloques cla4_v2 de 4 bits. La diferencia
// es que aca el carry ya no "salta" de bloque a bloque esperando el cout del
// anterior: cada bloque expone su G y su P de bloque (generate/propagate del
// bloque completo), y los carries entre bloques se calculan EN PARALELO con un
// segundo nivel de lookahead, identico en estructura al lookahead interno del
// bloque de 4 bits.
//
//   C[0]          = cin
//   C[i + 1]      = G[i] | (P[i] & C[i])        -> expandido en paralelo:
//   C[1]          = G[0] | (P[0] & cin)
//   C[2]          = G[1] | (P[1]&G[0]) | (P[1]&P[0]&cin)
//   C[3]          = G[2] | (P[2]&G[1]) | (P[2]&P[1]&G[0]) | (P[2]&P[1]&P[0]&cin)
//   C[4] (=cout)  = G[3] | (P[3]&G[2]) | (P[3]&P[2]&G[1]) | (P[3]&P[2]&P[1]&G[0])
//                     | (P[3]&P[2]&P[1]&P[0]&cin)
//
// Compartimos los prefijos de producto de bloque PP1, PP2, PP3 (como en el
// lookahead interno) para no duplicar logica. Todo 100% estructural con el
// mismo modelo de compuertas (xor=2ns, and/or=1ns).
//
// Con dos niveles el delay del carry crece con log(N) y no con la cantidad de
// bloques: los carries entre bloques se resuelven en paralelo y el camino
// critico es el lookahead interno de un bloque (~8ns) mas el arbol de lookahead
// entre bloques (~2-3ns), en vez de 4 saltos secuenciales como en la v1.

module cla16_v2 (
  input  logic [15:0] a,
  input  logic [15:0] b,
  input  logic        cin,
  output logic [15:0] sum,
  output logic        cout
);

  localparam time TAND = 1ns;   // and:  1 ns
  localparam time TOR  = 1ns;   // or :  1 ns

  // G[i] / P[i]: generate y propagate del bloque i (salidas de cada cla4_v2).
  logic [3:0] G;
  logic [3:0] P;

  // C[i] = carry de entrada del bloque i; C[4] = cout, calculado por lookahead.
  logic [4:0] C;

  // Prefijos de producto compartidos entre bloques (arbol de ands de 2 entradas).
  logic PP1;                         // P[1] & P[0]
  logic PP2;                         // P[2] & P[1] & P[0]
  logic PP3;                         // P[3] & P[2] & P[1] & P[0]

  // Terminos de producto de cada carry entre bloques (ands de 2 entradas).
  logic t1_c1b;                      // P[0] & C[0]
  logic t1_c2b, t2_c2b;              // P[1]&G[0] ; PP1&C[0]
  logic t1_c3b, t2_c3b, t3_c3b;      // P[2]&G[1] ; P[2]&P[1]&G[0] ; PP2&C[0]
  logic t1_c4b, t2_c4b, t3_c4b, t4_c4b;  // P[3]&G[2] ; P[3]&P[2]&G[1] ; P[3]&P[2]&P[1]&G[0] ; PP3&C[0]

  // Arboles de or internos (2 entradas).
  logic o1_c2b;
  logic o1_c3b, o2_c3b;
  logic o1_c4b, o2_c4b, o3_c4b;

  genvar i;
  generate
    for (i = 0; i < 4; i = i + 1) begin : cla_blocks
      cla4_v2 u_cla (
        .a   (a[i*4 +: 4]),
        .b   (b[i*4 +: 4]),
        .cin (C[i]),
        .sum (sum[i*4 +: 4]),
        .cout(),
        .G   (G[i]),
        .P   (P[i])
      );
    end
  endgenerate

  // ---------------------------------------------------------------------
  // SEGUNDO nivel de lookahead: carries entre bloques en paralelo.
  // Mismo arbol que el lookahead interno del cla4, con G/P de bloque.
  // ---------------------------------------------------------------------
  assign C[0] = cin;

  // Prefijos de producto de bloque compartidos.
  and #(TAND) u_PP1 (PP1, P[1], P[0]);        // PP1 = P1 & P0
  and #(TAND) u_PP2 (PP2, P[2], PP1);         // PP2 = P2 & P1 & P0
  and #(TAND) u_PP3 (PP3, P[3], PP2);         // PP3 = P3 & P2 & P1 & P0

  // C[1] = G[0] | (P[0] & C[0])
  and #(TAND) u_t1_c1b (t1_c1b, P[0], C[0]);
  or  #(TOR)  u_c1b    (C[1], G[0], t1_c1b);

  // C[2] = G[1] | (P[1] & G[0]) | (P[1] & P[0] & C[0])
  and #(TAND) u_t1_c2b (t1_c2b, P[1], G[0]);
  and #(TAND) u_t2_c2b (t2_c2b, PP1, C[0]);
  or  #(TOR)  u_o1_c2b (o1_c2b, G[1], t1_c2b);
  or  #(TOR)  u_c2b    (C[2], o1_c2b, t2_c2b);

  // C[3] = G[2] | (P[2]&G[1]) | (P[2]&P[1]&G[0]) | (P[2]&P[1]&P[0]&C[0])
  and #(TAND) u_t1_c3b (t1_c3b, P[2], G[1]);
  and #(TAND) u_t2_c3b (t2_c3b, P[2], t1_c2b);  // P2&P1&G0 (reusa t1_c2b)
  and #(TAND) u_t3_c3b (t3_c3b, PP2, C[0]);
  or  #(TOR)  u_o1_c3b (o1_c3b, G[2], t1_c3b);
  or  #(TOR)  u_o2_c3b (o2_c3b, t2_c3b, t3_c3b);
  or  #(TOR)  u_c3b    (C[3], o1_c3b, o2_c3b);

  // C[4] = G[3] | (P[3]&G[2]) | (P[3]&P[2]&G[1])
  //        | (P[3]&P[2]&P[1]&G[0]) | (P[3]&P[2]&P[1]&P[0]&C[0])
  and #(TAND) u_t1_c4b (t1_c4b, P[3], G[2]);
  and #(TAND) u_t2_c4b (t2_c4b, P[3], t1_c3b);  // P3&P2&G1   (reusa t1_c3b)
  and #(TAND) u_t3_c4b (t3_c4b, P[3], t2_c3b);  // P3&P2&P1&G0 (reusa t2_c3b)
  and #(TAND) u_t4_c4b (t4_c4b, PP3, C[0]);
  or  #(TOR)  u_o1_c4b (o1_c4b, G[3], t1_c4b);
  or  #(TOR)  u_o2_c4b (o2_c4b, t2_c4b, t3_c4b);
  or  #(TOR)  u_o3_c4b (o3_c4b, o2_c4b, t4_c4b);
  or  #(TOR)  u_c4b    (C[4], o1_c4b, o3_c4b);

  assign cout = C[4];

endmodule