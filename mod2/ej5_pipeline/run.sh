#!/bin/bash
# run.sh — Compila y ejecuta el ejercicio 5 (SystemVerilog) con Icarus Verilog.
# Uso: ./run.sh   (desde este directorio)
# Nota: -g2012 habilita constructos SystemVerilog (always_ff, logic, >>>, ...).
set -e
cd "$(dirname "$0")"

echo ">>> Compilando tb_pipeline.sv + pipeline_3stage.sv (-g2012) ..."
iverilog -g2012 -o sim.out tb_pipeline.sv pipeline_3stage.sv

echo ">>> Simulando con vvp ..."
vvp sim.out

echo ""
echo "VCD generado: tb_pipeline.vcd"
echo "  -> abrir en GTKWave:  gtkwave tb_pipeline.vcd"
