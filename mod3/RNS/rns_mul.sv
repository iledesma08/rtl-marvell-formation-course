// rns_mul.sv — Multiplicador modular en RNS (Residue Number System).
//
// Sistema RNS con modulos {3, 5, 7} -> M = 3*5*7 = 105 (unico: todo entero
// en [0, M-1] tiene una representacion RNS distinta). Dados X e Y en 7 bits:
//
//   1. descompone cada operando en sus residuos  rx_i = X mod m_i
//      (los buses "bin -> RNS" de un sistema RNS real);
//   2. multiplica residuo a residuo EN PARALELO:  c_i = (rx_i * ry_i) mod m_i
//      (los canales son independientes, no propagan carry entre si);
//   3. recompone el resultado con CRT:  Z = sum(c_i * C_i) mod M, con
//      C_i = (M/m_i) * inv((M/m_i) mod m_i)  ->  C = {70, 21, 15}.
//
// Por comodidad se deja parametrizado el ancho W de las entradas (7 bits
// para [0, M-1]); los modulos y coeficientes corresponden a {3, 5, 7}.

module rns_mul #(
  parameter int W = 7                     // bits para valores [0, M-1]
)(
  input  logic [W-1:0] x,                 // X in   [0, 104]
  input  logic [W-1:0] y,                 // Y in   [0, 104]
  output logic [1:0]   c3,                // canal modulo 3   (0..2)
  output logic [2:0]   c5,                // canal modulo 5   (0..4)
  output logic [2:0]   c7,                // canal modulo 7   (0..6)
  output logic [W-1:0] z                  // recomposicion CRT (0..104)
);

  // ---------------------------------------------------------------------
  // 1) Descomposicion: residuos de X e Y en cada canal (bin -> RNS).
  // ---------------------------------------------------------------------
  logic [1:0] rx3, ry3;                   // canal 3, residuos 0..2
  logic [2:0] rx5, ry5;                   // canal 5, residuos 0..4
  logic [2:0] rx7, ry7;                   // canal 7, residuos 0..6

  assign rx3 = x % 3'd3;
  assign ry3 = y % 3'd3;
  assign rx5 = x % 3'd5;
  assign ry5 = y % 3'd5;
  assign rx7 = x % 3'd7;
  assign ry7 = y % 3'd7;

  // ---------------------------------------------------------------------
  // 2) Producto modular residuo a residuo, en paralelo.
  // ---------------------------------------------------------------------
  logic [2:0] p3;                         // 2*2 = 4   -> 3 bits
  logic [4:0] p5;                         // 4*4 = 16  -> 5 bits
  logic [5:0] p7;                         // 6*6 = 36  -> 6 bits

  assign p3 = rx3 * ry3;
  assign p5 = rx5 * ry5;
  assign p7 = rx7 * ry7;

  assign c3 = p3 % 3'd3;
  assign c5 = p5 % 3'd5;
  assign c7 = p7 % 3'd7;

  // ---------------------------------------------------------------------
  // 3) Recomposicion del resultado (CRT): Z = sum(c_i * C_i) mod M.
  //    C = {70, 21, 15}.
  // ---------------------------------------------------------------------
  logic [9:0] crt_sum;
  assign crt_sum = c3 * 70 + c5 * 21 + c7 * 15;
  assign z = crt_sum % 105;

endmodule