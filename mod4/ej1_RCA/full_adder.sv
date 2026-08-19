// full_adder.sv — Full adder estructural de 1 bit.
//
// Se arma con compuertas primitivas (xor / and / or) para que el circuito sea
// realmente "estructural" como pide el enunciado y no una suma comportamental. 
// Cada compuerta lleva un delay de propagacion modelado explicitamente 
// (valores tipicos: la xor es la mas lenta, con 2 ns, mientras que 
// and/or tardan 1 ns). Esos delays son los que despues explican el 
// path critico del RCA.
//
// Logica:
//   p    = a ^ b            (propaga el carry)
//   g    = a & b            (genera el carry)
//   cout = g | (p & cin)
//   sum  = p ^ cin          (a ^ b ^ cin)

module full_adder (
  input  logic a,
  input  logic b,
  input  logic cin,
  output logic sum,
  output logic cout
);

  // Delays de propagacion por compuerta (constantes de simulacion).
  localparam time TXOR = 2ns;   // xor:  2 ns
  localparam time TAND = 1ns;   // and:  1 ns
  localparam time TOR  = 1ns;   // or :  1 ns

  logic p;    // a ^ b
  logic g;    // a & b
  logic pc;   // p & cin

  xor #(TXOR) u_xor_p  (p,   a, b);
  and #(TAND) u_and_g  (g,   a, b);
  and #(TAND) u_and_pc (pc,  p, cin);
  or  #(TOR)  u_or_cout(cout, g, pc);
  xor #(TXOR) u_xor_sum(sum,  p, cin);

endmodule