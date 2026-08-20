// csla16.sv — Carry Select Adder de 16 bits en 4 bloques de 4 bits.
//
// La idea del CSLA es evitar que el carry "riplee" por los 16 bits. En vez de
// una sola cadena larga, se arman bloques de 4 bits donde el carry se calcula
// dos veces EN PARALELO: una suponiendo que el carry de entrada es 0 y otra
// suponiendo que es 1. Cuando llega el carry real del bloque anterior, un mux
// 2:1 elige cuál de los dos resultados era el correcto.
//
// Estructura (4 bloques x 4 bits):
//   - Bloque 0: un solo rca4 con el carry-in externo `cin` (no tiene bloque
//     anterior que lo gobierne, asi que no necesita mux).
//   - Bloques 1..3: dos rca4 en paralelo (cin = 0 y cin = 1) + un mux 2:1 de
//     4 bits + 1 de carry, controlado por el carry-out del bloque anterior.
//
// El mux se arma estructural (not/and/or primitivas, delays de 1 ns) para que
// la medicion de delay sea consistente con el modelo de compuertas de los
// ejercicios 1 y 2. El delay ya no crece con 16 etapas de ripple sino con la
// cantidad de bloques: ~10 ns del primer bloque + ~3 ns por cada mux.

module csla16 (
  input  logic [15:0] a,
  input  logic [15:0] b,
  input  logic        cin,
  output logic [15:0] sum,
  output logic        cout
);

  // carry de entrada/salida de cada bloque: cblk[0] = cin, cblk[4] = cout.
  logic [4:0] cblk;

  // Resultados de las dos opciones de carry por bloque (bloques 1..3):
  //   sum0/cout0 = bloque sumando con cin = 0
  //   sum1/cout1 = bloque sumando con cin = 1
  logic [3:0] sum0 [1:3];
  logic [3:0] sum1 [1:3];
  logic       cout0 [1:3];
  logic       cout1 [1:3];

  assign cblk[0] = cin;

  // ---------------------------------------------------------------------
  // Bloque 0: RCA de 4 bits con el carry-in externo. No lleva mux porque
  // su carry de entrada ya se conoce (es `cin`).
  // ---------------------------------------------------------------------
  rca4 u_blk0 (
    .a   (a[3:0]),
    .b   (b[3:0]),
    .cin (cblk[0]),
    .sum (sum[3:0]),
    .cout(cblk[1])
  );

  // ---------------------------------------------------------------------
  // Bloques 1..3: dos rca4 en paralelo + mux 2:1 (suma y carry).
  // ---------------------------------------------------------------------
  genvar i;
  genvar k;
  generate
    for (i = 1; i < 4; i = i + 1) begin : sel_blocks
      // Sumador especulativo con carry-in = 0.
      rca4 u_rca0 (
        .a   (a[i*4 +: 4]),
        .b   (b[i*4 +: 4]),
        .cin (1'b0),
        .sum (sum0[i]),
        .cout(cout0[i])
      );

      // Sumador especulativo con carry-in = 1.
      rca4 u_rca1 (
        .a   (a[i*4 +: 4]),
        .b   (b[i*4 +: 4]),
        .cin (1'b1),
        .sum (sum1[i]),
        .cout(cout1[i])
      );

      // Mux 2:1 de 4 bits para la suma: elige entre la version cin=0 y cin=1
      // segun el carry que venga del bloque anterior (cblk[i]).
      for (k = 0; k < 4; k = k + 1) begin : sum_mux
        mux2 u_mux_s (
          .sel (cblk[i]),
          .d0  (sum0[i][k]),
          .d1  (sum1[i][k]),
          .y   (sum[i*4 + k])
        );
      end

      // Mux 2:1 del carry: el carry-out del bloque tambien depende de la
      // eleccion especulativa.
      mux2 u_mux_c (
        .sel (cblk[i]),
        .d0  (cout0[i]),
        .d1  (cout1[i]),
        .y   (cblk[i + 1])
      );
    end
  endgenerate

  assign cout = cblk[4];

endmodule


// mux2 — Mux 2:1 de 1 bit estructural (not/and/or primitivas).
//
// Se arma con compuertas primitivas y los mismos delays del
// ejercicio 1 (and/or/not = 1 ns) para que el path 'sel -> y' sume ~3 ns y la
// medicion de delay del CSLA sea consistente con la del CLA/RCA.

module mux2 (
  input  logic sel,
  input  logic d0,
  input  logic d1,
  output logic y      // y = (d0 & ~sel) | (d1 & sel)
);

  localparam time TAND = 1ns;   // and:  1 ns
  localparam time TOR  = 1ns;   // or :  1 ns
  localparam time TNOT = 1ns;   // not:  1 ns

  logic sel_b;   // ~sel
  logic t0;      // d0 & ~sel
  logic t1;      // d1 & sel

  not #(TNOT) u_not (sel_b, sel);
  and #(TAND) u_and0 (t0, d0, sel_b);
  and #(TAND) u_and1 (t1, d1, sel);
  or  #(TOR)  u_or   (y, t0, t1);

endmodule