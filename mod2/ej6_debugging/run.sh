#!/bin/bash
# run.sh — compila y simula con Icarus Verilog (SystemVerilog)
set -e
cd "$(dirname "$0")"

echo ">>> Compilando con iverilog (SystemVerilog 2012)..."
iverilog -g2012 -o ejercicio6.out alu_bad.v alu_fix1.v alu_fix2.v tb_alu.v
 
echo ">>> Ejecutando con vvp..."
vvp "ejercicio6.out"
 
echo "ejercicio6.out ejecutado"
echo "VCD generado: tb_alu.vcd (abrir con: gtkwave tb_alu.vcd)"