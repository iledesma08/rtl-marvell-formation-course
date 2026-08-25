#!/bin/bash
# run.sh — Automatiza la resolucion del Ejercicio 3 (CSLA 16 bits en bloques
#          de 4):
#          1) iverilog -> compila csla16.sv + rca4.sv + las referencias de
#             los ejercicios 1 y 2 (RCA16 y las DOS versiones del CLA16, v1 y
#             v2, para el cross-check y la tabla comparativa) + tb_csla.sv
#             (-g2012)
#          2) vvp      -> simula y reporta PASS / FAIL + tabla comparativa
#             CSLA vs CLA (v1 y v2) vs RCA
#          3) yosys    -> verifica el conteo estructural de compuertas que
#             reporta el testbench (CSLA16=200, CLA16 v1=140, CLA16 v2=167,
#             RCA16=80), contando el netlist real preprocesado.
# Uso: ./run.sh
set -e
cd "$(dirname "$0")"

echo ">>> [1/2] Compilando csla16.sv + rca4.sv + referencias (RCA / CLA v1 / CLA v2) + tb_csla.sv (-g2012) ..."
iverilog -g2012 -o sim.out \
  tb_csla.sv \
  csla16.sv \
  rca4.sv \
  ../ej1_RCA/full_adder.sv \
  ../ej1_RCA/rca.sv \
  ../ej2_CLA/v1/cla4.sv \
  ../ej2_CLA/v1/cla16.sv \
  ../ej2_CLA/v2/cla4.sv \
  ../ej2_CLA/v2/cla16.sv

echo ">>> [2/2] Simulando ..."
vvp sim.out

echo ""
echo ">>> Verificando conteo estructural de compuertas con Yosys ..."
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Yosys no acepta `localparam time` ni los delays `#(...)`: preprocesamos una
# copia sanitaria de cada fuente (se borra con el trap al salir).
sanitize() { sed -E '/localparam time/d; s/#\([^)]*\)//g' "$1"; }

sanitize ../ej1_RCA/full_adder.sv > "$WORK/full_adder.sv"
sanitize ../ej1_RCA/rca.sv        > "$WORK/rca.sv"
sanitize rca4.sv                  > "$WORK/rca4.sv"
sanitize csla16.sv                > "$WORK/csla16.sv"
sanitize ../ej2_CLA/v1/cla4.sv    > "$WORK/cla4_v1.sv"
sanitize ../ej2_CLA/v1/cla16.sv   > "$WORK/cla16_v1.sv"
sanitize ../ej2_CLA/v2/cla4.sv    > "$WORK/cla4_v2.sv"
sanitize ../ej2_CLA/v2/cla16.sv   > "$WORK/cla16_v2.sv"

# Cuenta las compuertas primitivas (and/or/xor/not de 2 entradas) del netlist
# aplanado, sin `opt`, para que el conteo coincida con el estructural del tb.
count_gates() {   # $1 = top module, resto = fuentes sanitizadas
  yosys -p "read_verilog -sv ${*:2}; hierarchy -top $1; flatten; techmap; stat" 2>/dev/null \
    | awk '/Number of cells/{print $NF}'
}

G_CSLA=$(count_gates csla16   "$WORK/csla16.sv" "$WORK/rca4.sv" "$WORK/full_adder.sv")
G_CLA1=$(count_gates cla16    "$WORK/cla16_v1.sv" "$WORK/cla4_v1.sv")
G_CLA2=$(count_gates cla16_v2 "$WORK/cla16_v2.sv" "$WORK/cla4_v2.sv")
G_RCA=$(yosys -p "read_verilog -sv $WORK/rca.sv $WORK/full_adder.sv; chparam -set N 16 rca; hierarchy -top rca; flatten; techmap; stat" 2>/dev/null \
        | awk '/Number of cells/{print $NF}')

M_CSLA=200; M_CLA1=140; M_CLA2=167; M_RCA=80

check() {   # $1 = nombre, $2 = yosys, $3 = manual esperado
  if [ "$2" = "$3" ]; then
    printf "  %-10s yosys=%4d manual=%4d  OK\n" "$1" "$2" "$3"
  else
    printf "  %-10s yosys=%4d manual=%4d  !! DIFIEREN (revisar tb/README)\n" "$1" "$2" "$3"
  fi
}

echo ""
check "CSLA16"   "$G_CSLA" "$M_CSLA"
check "CLA16 v1" "$G_CLA1" "$M_CLA1"
check "CLA16 v2" "$G_CLA2" "$M_CLA2"
check "RCA16"    "$G_RCA"  "$M_RCA"

echo ""
echo "Ondas VCD:  tb_csla.vcd  ->  gtkwave tb_csla.vcd"