#!/bin/bash
# run.sh — Automatiza la resolucion del Ejercicio 6 (RNS - multiplicacion
#          modular sobre {3, 5, 7}):
#          1) gen_vectors.py  -> modelo golden (fxpmath) + archivos .hex
#          2) iverilog         -> compila DUT + testbench (-g2012)
#          3) vvp              -> simula y reporta PASS / FAIL
# Uso:        ./run.sh
# Cobertura:  N_VECTORS=1000 ./run.sh    (muestreo aleatorio)
#             (default: exhaustivo, los 105 x 105 pares (X, Y) en [0, 104])
set -e
cd "$(dirname "$0")"

echo ">>> [1/3] Generando vectores con el modelo golden (fxpmath) ..."
python3 gen_vectors.py

echo ">>> [2/3] Compilando DUT + Testbench (-g2012) ..."
iverilog -g2012 -o sim.out tb_rns_mul.sv rns_mul.sv

echo ">>> [3/3] Simulando ..."
vvp sim.out

echo ""
echo "Onda VCD generada: tb_rns_mul.vcd  ->  gtkwave tb_rns_mul.vcd"