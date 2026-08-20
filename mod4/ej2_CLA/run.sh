#!/bin/bash
# run.sh — Automatiza la resolucion del Ejercicio 2 (CLA 4-bit -> 16-bit):
#          1) iverilog -> compila cla4.sv + cla16.sv + RCA de referencia
#             (rca.sv / full_adder.sv del ejercicio 1, para el cross-check y
#             la tabla de delay) + tb_cla.sv (-g2012)
#          2) vvp      -> simula y reporta PASS / FAIL + tabla delay CLA vs RCA
# Uso: ./run.sh
set -e
cd "$(dirname "$0")"

echo ">>> [1/2] Compilando cla4.sv + cla16.sv + RCA (referencia ej1) + tb_cla.sv (-g2012) ..."
iverilog -g2012 -o sim.out tb_cla.sv cla16.sv cla4.sv ../ej1_RCA/rca.sv ../ej1_RCA/full_adder.sv

echo ">>> [2/2] Simulando ..."
vvp sim.out

echo ""
echo "Ondas VCD:  tb_cla.vcd  ->  gtkwave tb_cla.vcd"