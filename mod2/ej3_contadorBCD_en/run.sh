#!/bin/bash
# run.sh — compila y simula con Icarus Verilog
set -e
cd "$(dirname "$0")"

echo ">>> Compilando con iverilog..."
iverilog -g2012 -o ejercicio_3.out bcd_counter.v tb_bcd_counter.v

echo ">>> Ejecutando con vvp..."
vvp ejercicio_3.out

echo ""
echo "VCD generado: tb_bcd_counter.vcd (abrir con: gtkwave tb_bcd_counter.vcd)"
