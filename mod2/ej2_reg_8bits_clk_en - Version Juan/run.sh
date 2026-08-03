#!/bin/bash
# run.sh — compila y simula con Icarus Verilog
set -e
cd "$(dirname "$0")"

echo ">>> Compilando con iverilog..."
iverilog -g2012 -o ejercicio_2.out reg_ce.v tb_reg_ce.v #Coloco g2012 para compilar con estandar 2012
#sin esto no me deja usar Always_ff

echo ">>> Ejecutando con vvp..."
vvp ejercicio_2.out

echo ""
echo "VCD generado: tb_reg_ce.vcd (abrir con: gtkwave tb_reg_ce.vcd)"
