#!/usr/bin/env bash
set -e

echo "==> Compilando" 
iverilog -g2012 -o Ejercicio-5.out array_mul.v  tb_array_mul.v full_adder.v multiplicacion.v

echo "==> Simulando"
vvp Ejercicio-5.out
