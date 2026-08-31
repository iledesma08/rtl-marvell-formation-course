set -e
cd "$(dirname "$0")"

echo ">>Compilando el ejercicio"

iverilog -g2012 -o ej2.out ROM.sv CORDIC_stage.sv TOP.sv tb_top_pipeline.sv

echo ">>ejecutando el ejercicio"
vvp ej2.out