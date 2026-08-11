#!/usr/bin/env bash
# run.sh — Genera los vectores golden, compila y simula el ejercicio de Booth radix-2.
set -e

echo "==> Generando vectores golden (fxpmath)..."
python3 model.py

echo "==> Compilando (Icarus Verilog)..."
iverilog -g2012 -o ejercicio_5.out booth_radix_2.v tb_booth.v

echo "==> Simulando..."
vvp ejercicio_5.out