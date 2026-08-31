// rom_atan.sv — ROM de 16 entradas con atan(2^-i) en S(16,14) (unidades de pi).
//
// El CORDIC vectoring acumula el angulo en "unidades de pi": el valor 1.0
// representa pi radianes (una vuelta de 180 grados). Asi el circulo completo
// (-pi, pi] mapea a (-1, 1], que entra holgado en S(16,14) (rango [-2, 2)).
//
// Tabla generada por gen_roms.py (atan_lut.vh). No editar a mano.

`timescale 1ns/1ps

module rom_atan (
  input  logic [3:0]         index,
  output logic signed [15:0] value
);
  always_comb begin
    `include "atan_lut.vh"
  end
endmodule