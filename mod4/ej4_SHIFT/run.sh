#!/usr/bin/env bash
set -e

echo "==> Compilando" 
iverilog -g2012 -o Ejercicio-4.out Mul_seq.v  Control_FSM.v Tb_mul_seq.v

echo "==> Simulando"
vvp Ejercicio-4.out
