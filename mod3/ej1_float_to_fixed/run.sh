#!/usr/bin/env bash
# run.sh — Genera los vectores golden, compila y simula el ejercicio 
set -e

echo "==> Generando vectores golden (fxpmath)..."
python3 model.py

echo "==> Compilando (Icarus Verilog)..."
iverilog -g2012 -o ejercicio_1.out Conversor_float_to_fixed.v tb_conversion.v

echo "==> Simulando..."
vvp ejercicio_1.out