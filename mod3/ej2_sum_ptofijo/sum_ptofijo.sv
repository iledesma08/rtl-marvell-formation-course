// sum_ptofijo.sv — Sumador binario en punto fijo signado (Complemento a 2).
//
// Entradas:  A en S(W_A, NBFA)   y   B en S(W_B, NBFB)
// Salida :   S en S(NB, NBF)      con las reglas del enunciado:
//              NBF_out = max(NBFA, NBFB)
//              NBI_out = max(NBI_A, NBI_B) + 1          (NBI incluye el signo)
//
// Por diseño (un bit de signo de mas) la suma de dos operandos nunca
// desborda: el carry final se descarta naturalmente al recortar a NB bits.

module sum_ptofijo #(
  parameter int W_A  = 6,
  parameter int NBFA = 4,
  parameter int W_B  = 8,
  parameter int NBFB = 5,

  parameter int NBF  = (NBFA > NBFB) ? NBFA : NBFB, // Numero de bits fraccionarios en la salida
  parameter int NBIA = W_A - NBFA,
  parameter int NBIB = W_B - NBFB,
  parameter int NBI  = ((NBIA > NBIB) ? NBIA : NBIB) + 1, // Numero de bits enteros (incluye el signo) en la salida
  parameter int NB   = NBI + NBF // Numero total de bits en la salida
)(
  input  logic [W_A-1:0] a,
  input  logic [W_B-1:0] b,
  output logic [NB-1:0]  sum
);

  // Alineacion de A a S(NB,NBF): relleno con ceros (extiende NBF) y
  // extension de signo (extiende NBI hasta NB).
  wire [NB-1:0] a_ext = { {(NBI - NBIA){a[W_A-1]}}, a, {(NBF - NBFA){1'b0}} };

  // Alineacion de B (misma logica, ya viene con NBF = NBF_out).
  wire [NB-1:0] b_ext = { {(NBI - NBIB){b[W_B-1]}}, b, {(NBF - NBFB){1'b0}} };

  // Suma en complemento a 2. El carry de salida se pierde (wrap), lo cual es
  // correcto porque NBI_out = max+1 garantiza que el resultado entra en NB.
  assign sum = a_ext + b_ext;

endmodule