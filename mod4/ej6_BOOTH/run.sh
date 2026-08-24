#!/usr/bin/env bash
set -e

echo "==> Compilando" 
iverilog -g2012 -o Ejercicio-6.out booth_r2.v  tb_booth.v

echo "==> Simulando"
vvp Ejercicio-6.out
