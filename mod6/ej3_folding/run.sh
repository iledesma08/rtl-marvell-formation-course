#!/bin/bash
# run.sh — Automatiza la resolucion del Ejercicio 3 (FIR de 4 coeficientes con
#          recursos compartidos: 1 multiplicador + 1 sumador):
#          1) iverilog -> compila fir4_folded.sv + tb_fir4.sv (-g2012)
#          2) vvp      -> simula y reporta PASS / FAIL + tabla teorico vs
#             medido (latencia, periodo streaming, utilizacion de recursos)
#          3) yosys    -> verifica la premisa central del ejercicio sobre el
#             netlist real: el diseno tiene EXACTAMENTE 1 multiplicador ($mul)
#             y 1 sumador ($add), y 88 bits de registro (4 taps x 8b = 32,
#             producto 16, acumulador 18, salida 18, estado 3, out_valid 1).
# Uso: ./run.sh
set -e
cd "$(dirname "$0")"

echo ">>> [1/2] Compilando fir4_folded.sv + tb_fir4.sv (-g2012) ..."
iverilog -g2012 -o sim.out tb_fir4.sv fir4_folded.sv

echo ">>> [2/2] Simulando ..."
vvp sim.out

echo ""
echo ">>> Verificando recursos con Yosys sobre el netlist real ..."
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cp fir4_folded.sv "$WORK/"

# -- 1) Aritmetica de alto nivel: tiene que quedar 1 solo $mul y 1 solo $add.
yosys -p "read_verilog -sv $WORK/fir4_folded.sv; hierarchy -top fir4_folded; flatten; proc; opt -fast; stat" 2>/dev/null \
  | awk '/\$mul/{m=$NF} /\$add/{a=$NF} END{print m, a}' > "$WORK/arith.txt"
read -r N_MUL N_ADD < "$WORK/arith.txt"

# -- 2) Conteo de flip-flops: techmap baja los registros a celdas de 1 bit.
yosys -p "read_verilog -sv $WORK/fir4_folded.sv; hierarchy -top fir4_folded; flatten; proc; opt -fast; techmap; stat" 2>/dev/null \
  | awk '/[$]_DFF/{s+=$NF} END{print s}' > "$WORK/ff.txt"
read -r N_FF < "$WORK/ff.txt"

check() {   # $1 = nombre, $2 = yosys, $3 = esperado
  if [ "$2" = "$3" ]; then
    printf "  %-28s yosys=%4s esperado=%4s  OK\n" "$1" "$2" "$3"
  else
    printf "  %-28s yosys=%4s esperado=%4s  !! DIFIEREN (revisar tb/README)\n" "$1" "$2" "$3"
  fi
}

echo ""
check "multiplicadores (\$mul)"   "$N_MUL" 1
check "sumadores (\$add)"         "$N_ADD" 1
check "bits de registro"          "$N_FF"  88

echo ""
echo "Ondas VCD:  tb_fir4.vcd  ->  gtkwave tb_fir4.vcd"
