#!/bin/bash
# run.sh — Automatiza la resolucion del Ejercicio 3 (CORDIC Vectoring):
#
#   1) gen_roms.py         -> genera las ROMs (atan_lut.vh, sqrt_rom.hex,
#                             atan2_rom.hex) y los vectores de test
#                             (vectors.hex, nvec.txt)
#   2) iverilog -g2012     -> compila cordic_vect.sv + rom_atan.sv +
#                             ref_direct.sv + tb_cordic_vect.sv
#   3) vvp                 -> simula y reporta PASS/FAIL + tabla de error
#                             vs cuadrante (entregable d) + errores.csv
#   4) yosys               -> sintetiza CORDIC y referencia y compara el area
#                             (celdas logicas + bits de ROM, entregable c)
#   5) analisis_error.py   -> grafico del error vs cuadrante
#                             (output_ej3.png, entregable d)

set -e
cd "$(dirname "$0")"

echo ">>> [1/5] Generando ROMs y vectores de test (gen_roms.py) ..."
python3 gen_roms.py

echo ""
echo ">>> [2/5] Compilando cordic_vect.sv + rom_atan.sv + ref_direct.sv + tb_cordic_vect.sv (-g2012) ..."
iverilog -g2012 -o datos/sim.out \
  cordic_vect.sv \
  rom_atan.sv \
  ref_direct.sv \
  tb_cordic_vect.sv

echo ""
echo ">>> [3/5] Simulando ..."
echo ""
vvp datos/sim.out

echo ""
echo ">>> [4/5] Comparacion de area con Yosys (flatten + techmap + stat) ..."
# Reporta "celdas logicas bits_de_ROM" para un top y sus fuentes.
yosys_area() {   # $1 = top module, resto = fuentes
  yosys -p "read_verilog -sv ${*:2}; hierarchy -top $1; flatten; techmap; stat" 2>/dev/null \
    | awk '/Number of cells:/{c=$NF} /Number of memory bits:/{b=$NF} END{print c, b}'
}

read C_CELLS C_BITS <<< "$(yosys_area cordic_vect 'cordic_vect.sv rom_atan.sv')"
read R_CELLS R_BITS <<< "$(yosys_area ref_direct 'ref_direct.sv')"

echo ""
echo "  Arquitectura        | celdas logicas | ROM (bits)"
echo "----------------------+----------------+------------------"
printf "  CORDIC vectoring    | %14s | %16s\n" "$C_CELLS" "$C_BITS"
printf "  Referencia mult+ROM | %14s | %16s\n" "$R_CELLS" "$R_BITS"
echo "----------------------+----------------+------------------"
echo ""
echo "  Nota: la tabla atan del CORDIC (16x16) queda absorbida en la logica (case-based)."
echo "  La ROM de la referencia son 2 x 64K x 16 = 2 Mbit, que en un FPGA Artix-7 equivalen"
echo "  a ~64 BRAMs de 32 Kb. La ROM del CORDIC es 0 bits; la de la referencia 2 Mbit."

echo ""
echo ">>> [5/5] Analisis de error vs cuadrante (Python, output_ej3.png) ..."
python3 analisis_error.py

echo ""
echo "Ondas VCD:  datos/tb_cordic_vect.vcd  ->  gtkwave datos/tb_cordic_vect.vcd"