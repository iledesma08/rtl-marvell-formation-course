#!/bin/bash
# run.sh — Automatiza la resolucion del Ejercicio 3 (CSLA 16 bits en bloques
#          de 4): iverilog compila csla16.sv + rca4.sv + las referencias de
#          los ejercicios 1 y 2 (RCA16 y CLA16 para el cross-check y la tabla
#          comparativa) + tb_csla.sv (-g2012) y vvp simula reportando
#          PASS / FAIL y la tabla CSLA vs CLA vs RCA.
# Uso: ./run.sh
set -e
cd "$(dirname "$0")"

echo ">>> [1/2] Compilando csla16.sv + rca4.sv + referencias (RCA/CLA) + tb_csla.sv (-g2012) ..."
iverilog -g2012 -o sim.out \
  tb_csla.sv \
  csla16.sv \
  rca4.sv \
  ../ej1_RCA/full_adder.sv \
  ../ej1_RCA/rca.sv \
  ../ej2_CLA/cla4.sv \
  ../ej2_CLA/cla16.sv

echo ">>> [2/2] Simulando ..."
vvp sim.out

echo ""
echo "Ondas VCD:  tb_csla.vcd  ->  gtkwave tb_csla.vcd"