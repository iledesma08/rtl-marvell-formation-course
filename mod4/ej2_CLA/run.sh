#!/bin/bash
# run.sh — Automatiza la resolucion del Ejercicio 2 (CLA 4-bit -> 16-bit):
#          testea y compara las DOS versiones (v1: un nivel de lookahead,
#          v2: dos niveles con G/P de bloque) junto con el RCA16 de referencia
#          del ejercicio 1 (cross-check y tabla de delay).
#          1) iverilog -> compila tb_cla.sv + v1/cla4+cla16 + v2/cla4+cla16
#             + RCA (ej1) (-g2012)
#          2) vvp      -> simula y reporta PASS / FAIL + tabla delay
#             CLA16 v1 vs CLA16 v2 vs RCA16
# Uso: ./run.sh
set -e
cd "$(dirname "$0")"

echo ">>> [1/2] Compilando tb_cla.sv + cla4/cla16 v1 + cla4/cla16 v2 + RCA (referencia ej1) (-g2012) ..."
iverilog -g2012 -o sim.out \
  tb_cla.sv \
  v1/cla4.sv \
  v1/cla16.sv \
  v2/cla4.sv \
  v2/cla16.sv \
  ../ej1_RCA/rca.sv \
  ../ej1_RCA/full_adder.sv

echo ">>> [2/2] Simulando ..."
vvp sim.out

echo ""
echo "Ondas VCD:  tb_cla.vcd  ->  gtkwave tb_cla.vcd"