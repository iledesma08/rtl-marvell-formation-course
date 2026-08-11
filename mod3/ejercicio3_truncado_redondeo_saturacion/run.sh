#!/usr/bin/env bash
set -e

echo "==> Generando vectores golden (fxpmath)..."
python3 model.py

echo "==> Compilando truncamiento/redondeo..."
iverilog -g2012 -o sim_tr.out fixed_point_resize.v tb_resize_tr.v

echo "==> Simulando truncamiento/redondeo..."
vvp sim_tr.out

echo ""
echo "==> Compilando saturacion/wrap-around..."
iverilog -g2012 -o sim_sat.out fixed_point_resize.v tb_resize_sat.v

echo "==> Simulando saturacion/wrap-around..."
vvp sim_sat.out