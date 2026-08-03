#!/bin/bash
# run.sh — compila y simula con Icarus Verilog
set -e
cd "$(dirname "$0")"

echo ">>> Compilando con iverilog..."
iverilog -o sim.out tb_casos.v caso_a.v caso_b.v

echo ">>> Ejecutando con vvp..."
vvp sim.out

echo ""
echo "VCD generado: tb_casos.vcd (abrir con: gtkwave tb_casos.vcd)"
