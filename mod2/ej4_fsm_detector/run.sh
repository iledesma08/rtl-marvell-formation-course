set -e
cd "$(dirname "$0")"

echo ">>> Compilando con iverilog..."
iverilog -g2012 -o ejercicio_4.out tb_detector_101.v detector_101.v

echo ">>> Ejecutando con vvp..."
vvp ejercicio_4.out

echo ""
echo "VCD generado: tb_detector_101.vcd (abrir con: gtkwave tb_detector_101.vcd)"
