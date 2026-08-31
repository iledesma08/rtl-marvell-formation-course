set -e
cd "$(dirname "$0")"

echo ">>Compilando el ejercicio"

iverilog -g2012 -o ej1.out ROM.sv CORDIC.sv FSM.sv TOP.sv tb_top.sv

echo ">>ejecutando el ejercicio"
vvp ej1.out