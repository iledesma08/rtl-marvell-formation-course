#!/bin/bash
# run.sh — Automatiza la resolucion del Ejercicio 4 (multiplicacion por K=23
#          en CSD canonico):
#          1) gen_vectors.py  -> modelo golden (fxpmath) + archivos .hex
#          2) iverilog         -> compila DUT + testbench (-g2012)
#          3) vvp              -> simula y reporta PASS / FAIL
# Uso:        ./run.sh
# Cobertura:  N_VECTORS=100 ./run.sh    (muestreo aleatorio)
#             (default: exhaustivo, los 256 valores de X en S(8,0))
set -e
cd "$(dirname "$0")"

echo ">>> [1/3] Generando vectores con el modelo golden (fxpmath) ..."
python3 gen_vectors.py

echo ">>> [2/3] Compilando DUT + Testbench (-g2012) ..."
iverilog -g2012 -o sim.out tb_mul23.sv mul23.sv

echo ">>> [3/3] Simulando ..."
vvp sim.out

echo ""
echo "Onda VCD generada: tb_mul23.vcd  ->  gtkwave tb_mul23.vcd"