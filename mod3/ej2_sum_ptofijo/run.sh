#!/bin/bash
# run.sh — Automatiza la resolucion del Ejercicio 2 (suma en punto fijo):
#          1) gen_vectors.py  -> modelo golden (fxpmath) + archivos .hex
#          2) iverilog         -> compila DUT + testbench (-g2012)
#          3) vvp              -> simula y reporta PASS / FAIL
# Uso:        ./run.sh
# Cobertura:  N_VECTORS=1000 ./run.sh   (muestreo aleatorio)
#             N_VECTORS=16384 ./run.sh  (exhaustivo, default si no se setea)
set -e
cd "$(dirname "$0")"

echo ">>> [1/3] Generando vectores con el modelo golden (fxpmath) ..."
python3 gen_vectors.py

echo ">>> [2/3] Compilando DUT + Testbench (-g2012) ..."
iverilog -g2012 -o sim.out tb_sum_ptofijo.sv sum_ptofijo.sv

echo ">>> [3/3] Simulando ..."
vvp sim.out

echo ""
echo "Onda VCD generada: tb_sum_ptofijo.vcd  ->  gtkwave tb_sum_ptofijo.vcd"