#!/bin/bash
# run.sh — Automatiza la resolucion del Ejercicio 1 (RCA N-bit parametrizable):
#          1) iverilog -> compila DUT + testbench de verificacion (-g2012)
#          2) vvp      -> simula y reporta PASS / FAIL
#          3) iverilog -> compila el barrido de delay (N = {4,8,16,32})
#          4) vvp      -> simula y escribe delays.txt
#          5) python3  -> plot_delay.py grafica output_delay.png
# Uso: ./run.sh
set -e
cd "$(dirname "$0")"

echo ">>> [1/5] Compilando full_adder.sv + rca.sv + tb_rca.sv (-g2012) ..."
iverilog -g2012 -o sim.out tb_rca.sv rca.sv full_adder.sv

echo ">>> [2/5] Simulando testbench de verificacion ..."
vvp sim.out

echo ">>> [3/5] Compilando barrido de delay (N = {4,8,16,32}) ..."
iverilog -g2012 -o sim_delay.out tb_rca_delay.sv rca.sv full_adder.sv

echo ">>> [4/5] Simulando barrido de delay ..."
vvp sim_delay.out

echo ">>> [5/5] Generando grafica delay vs N ..."
python3 plot_delay.py

echo ""
echo "Ondas VCD:  tb_rca.vcd y tb_rca_delay.vcd  ->  gtkwave tb_rca.vcd"
echo "Grafica:    output_delay.png"