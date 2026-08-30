#!/bin/bash
# run.sh — Automatiza la resolucion del Ejercicio 4 (divisor por Newton-Raphson
#          con LUT de 8 entradas y datapath folded):
#
#          1) gen_lut.py        -> genera la LUT inicial y0(a) (lut_y0.vh)
#
#          2) gen_vectors.py    -> genera los vectores dorados (a.hex y los
#                                  y_exp_N.hex para N_ITER = 1..4)
#
#          3) iverilog -g2012   -> compila nr_div.sv + tb_nr_div.sv
#
#          4) vvp               -> simula y reporta PASS / FAIL + tabla
#                                  error vs N iteraciones (entregable d)
#
#          5) analisis_error.py -> analisis de error vs N en Python (entrega-
#                                  ble d, con grafico output_ej4.png)

set -e
cd "$(dirname "$0")"

echo ">>> [1/5] Generando LUT y0(a) (gen_lut.py -> lut_y0.vh) ..."
python3 gen_lut.py

echo ""
echo ">>> [2/5] Generando vectores dorados (gen_vectors.py) ..."
python3 gen_vectors.py

echo ""
echo ">>> [3/5] Compilando nr_div.sv + tb_nr_div.sv (-g2012) ..."
iverilog -g2012 -o sim.out \
  tb_nr_div.sv \
  nr_div.sv

echo ""
echo ">>> [4/5] Simulando ..."
vvp sim.out

echo ""
echo ">>> [5/5] Analisis de error vs N iteraciones (Python) ..."
python3 analisis_error.py

echo ""
echo "Ondas VCD:  tb_nr_div.vcd  ->  gtkwave tb_nr_div.vcd"