// cla4.sv — Carry Lookahead Adder de 4 bits con ecuaciones de
// generate/propagate explicitas.
//
// En un RCA el carry "riplea" bit a bit; el CLA corta ese camino calculando
// todos los carries en paralelo a partir de dos senales por bit:
//
//   g[i] = a[i] & b[i]            (genera carry con seguridad)
//   p[i] = a[i] ^ b[i]            (propaga el carry de entrada)
//   c[i + 1] = g[i] | (p[i] & c[i])
//
// La recurrencia de c[i+1] se expande en forma de lookahead: en lugar de
// esperar a c[i] para calcular c[i+1], cada carry se escribe como una suma de
// terminos que dependen solo de g, p y cin (por ejemplo c[2] =
// g[1] | (p[1]&g[0]) | (p[1]&p[0]&cin)). 
//
// Se arma 100% estructural (compuertas and/or/xor de 2 entradas) con los
// mismos delays del ejercicio 1 (xor=2ns, and/or=1ns), para que la
// comparacion de delay con el RCA de 16 bits sea justa: mismo modelo de
// compuertas, distinta topologia.

module cla4 (
  input  logic [3:0] a,
  input  logic [3:0] b,
  input  logic       cin,
  output logic [3:0] sum,
  output logic       cout
);

  // Delays de propagacion por compuerta (iguales a los del ejercicio 1).
  localparam time TXOR = 2ns;   // xor:  2 ns
  localparam time TAND = 1ns;   // and:  1 ns
  localparam time TOR  = 1ns;   // or :  1 ns

  logic [3:0] p;        // propagate: p[i] = a[i] ^ b[i]
  logic [3:0] g;        // generate : g[i] = a[i] & b[i]
  logic [4:0] c;        // carries:   c[0] = cin, c[1..4] por lookahead

  // Prefijos de producto compartidos (arbol de ands de 2 entradas):
  // Se reutilizan en varios carries, asi no se duplica logica.
  logic pp1;                         // p1 & p0
  logic pp2;                         // p2 & p1 & p0
  logic pp3;                         // p3 & p2 & p1 & p0

  // Terminos de producto de cada carry (todos ands de 2 entradas).
  logic t1_c1;                       // p0 & c0
  logic t1_c2, t2_c2;                // p1&g0 ; pp1&c0
  logic t1_c3, t2_c3, t3_c3;         // p2&g1 ; p2&p1&g0 ; pp2&c0
  logic t1_c4, t2_c4, t3_c4, t4_c4;  // p3&g2 ; p3&p2&g1 ; p3&p2&p1&g0 ; pp3&c0

  // Arboles de or internos (2 entradas).
  logic o1_c2;
  logic o1_c3, o2_c3;
  logic o1_c4, o2_c4, o3_c4;

  genvar i;
  genvar j;

  // ---------------------------------------------------------------------
  // g[i] y p[i] para cada bit.
  // ---------------------------------------------------------------------
  generate
    for (i = 0; i < 4; i = i + 1) begin : gp
      and #(TAND) u_and_g (g[i], a[i], b[i]); // g[i] = a[i] & b[i]
      xor #(TXOR) u_xor_p (p[i], a[i], b[i]); // p[i] = a[i] ^ b[i]
    end
  endgenerate

  assign c[0] = cin;

  // ---------------------------------------------------------------------
  // Prefijos de producto compartidos: pp1, pp2, pp3.
  // ---------------------------------------------------------------------
  and #(TAND) u_pp1 (pp1, p[1], p[0]);        // pp1 = p1 & p0
  and #(TAND) u_pp2 (pp2, p[2], pp1);         // pp2 = p2 & p1 & p0
  and #(TAND) u_pp3 (pp3, p[3], pp2);         // pp3 = p3 & p2 & p1 & p0

  // ---------------------------------------------------------------------
  // c[1] = g[0] | (p[0] & c[0])
  // ---------------------------------------------------------------------
  and #(TAND) u_t1_c1 (t1_c1, p[0], c[0]);
  or  #(TOR)  u_c1    (c[1], g[0], t1_c1);    

  // ---------------------------------------------------------------------
  // c[2] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & c[0])
  // ---------------------------------------------------------------------
  and #(TAND) u_t1_c2 (t1_c2, p[1], g[0]);
  and #(TAND) u_t2_c2 (t2_c2, pp1, c[0]);      
  or  #(TOR)  u_o1_c2 (o1_c2, g[1], t1_c2);
  or  #(TOR)  u_c2    (c[2], o1_c2, t2_c2);   

  // ---------------------------------------------------------------------
  // c[3] = g[2] | (p[2]&g[1]) | (p[2]&p[1]&g[0]) | (p[2]&p[1]&p[0]&c[0])
  // ---------------------------------------------------------------------
  and #(TAND) u_t1_c3 (t1_c3, p[2], g[1]);
  and #(TAND) u_t2_c3 (t2_c3, p[2], t1_c2);   // p2&p1&g0 (reusa t1_c2)
  and #(TAND) u_t3_c3 (t3_c3, pp2, c[0]);
  or  #(TOR)  u_o1_c3 (o1_c3, g[2], t1_c3);
  or  #(TOR)  u_o2_c3 (o2_c3, t2_c3, t3_c3);
  or  #(TOR)  u_c3    (c[3], o1_c3, o2_c3);

  // ---------------------------------------------------------------------
  // c[4] = g[3] | (p[3]&g[2]) | (p[3]&p[2]&g[1])
  //        | (p[3]&p[2]&p[1]&g[0]) | (p[3]&p[2]&p[1]&p[0]&c[0])
  // ---------------------------------------------------------------------
  and #(TAND) u_t1_c4 (t1_c4, p[3], g[2]);
  and #(TAND) u_t2_c4 (t2_c4, p[3], t1_c3);   // p3&p2&g1   (reusa t1_c3)
  and #(TAND) u_t3_c4 (t3_c4, p[3], t2_c3);   // p3&p2&p1&g0 (reusa t2_c3)
  and #(TAND) u_t4_c4 (t4_c4, pp3, c[0]);
  or  #(TOR)  u_o1_c4 (o1_c4, g[3], t1_c4);
  or  #(TOR)  u_o2_c4 (o2_c4, t2_c4, t3_c4);
  or  #(TOR)  u_o3_c4 (o3_c4, o2_c4, t4_c4);
  or  #(TOR)  u_c4    (c[4], o1_c4, o3_c4);

  assign cout = c[4];

  // ---------------------------------------------------------------------
  // sum[i] = p[i] ^ c[i]   (= a[i] ^ b[i] ^ c[i]).
  // ---------------------------------------------------------------------
  generate
    for (j = 0; j < 4; j = j + 1) begin : sum_xors
      xor #(TXOR) u_xor_s (sum[j], p[j], c[j]);
    end
  endgenerate

endmodule