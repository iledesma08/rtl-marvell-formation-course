// mul23.sv — Multiplicador por la constante K = 23 implementado dos formas:
//
//   y_std : forma binaria estandar   ->  Y = (X<<4) + (X<<2) + (X<<1) + X
//                                        (4 sumandos -> 3 sumadores)
//   y_csd : forma CSD canonico       ->  Y = (X<<5) - (X<<3) - X
//                                        (3 sumandos -> 2 sumadores)
//
// X entero signado S(W_X, 0); el producto X*K cabe en S(W_X + 5, 0) porque
// |X*23| <= 23*2^(W_X-1) < 2^(W_X+4). Los shifts son gratuitos en hardware,
// de modo que la economia real de CSD esta en la cantidad de sumadores.

module mul23 #(
  parameter int W_X = 8,
  parameter int W_Y = W_X + 5            // S(13, 0) para W_X = 8
)(
  input   logic [W_X-1:0] x,
  output  logic [W_Y-1:0] y_std,         // via binario estandar
  output  logic [W_Y-1:0] y_csd          // via CSD canonico
);

  // X extendido con signo al ancho de salida (S(W_Y, 0)).
  // Se hace la extension en forma explicita para evitar el relleno con ceros
  // que SystemVerilog aplicaria al convertir un unsigned de W_X bits.
  logic signed [W_Y-1:0] x_s;
  assign x_s = {{(W_Y - W_X){x[W_X-1]}}, x};

  // Forma binaria estandar: 4 sumandos en complemento a 2.
  assign y_std = (x_s <<< 4) + (x_s <<< 2) + (x_s <<< 1) + x_s;

  // Forma CSD canonica (K = 10-100-1 = +32 -8 -1): 3 sumandos, una resta.
  assign y_csd = (x_s <<< 5) - (x_s <<< 3) - x_s;

endmodule