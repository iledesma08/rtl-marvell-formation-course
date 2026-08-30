#!/usr/bin/env python3
# gen_lut.py — Generador de la LUT inicial y0(a) para el divisor por
# Newton-Raphson.
#
# El divisor calcula y = 1/a con "a" normalizado a [0.5, 1.0), asi que el
# resultado cae siempre en (1, 2]. La LUT cubre ese rango con 8 indices:
#
#     index = (a >> 12) & 7
#
# porque a >= 0.5 fija el MSB en 1: (a >> 12) recorre [8, 15] y el &7 lo
# lleva a [0, 7]. Cada bin tiene ancho 1/16 = 0.0625 y guardamos el
# reciproco 1/a del punto medio, cuantizado a U(16,15) (16 bits sin signo,
# 15 fraccionarios: el MSB vale 1, justo el rango [1, 2) de y).
#
# Tambien provee el modelo golden de la iteracion NR en punto fijo
# (nr_iterate) que replica EXACTAMENTE la aritmetica del RTL:
#     p1    = a * y                       (multiplicador 16x16 -> 32)
#     t     = 2 - round(p1[31:16])        (redondeo a nearest)
#     y     = clamp(round((t * y) >> 15)) (redondeo a nearest + saturacion)
#
# Este modelo lo reusan gen_vectors.py (vectores dorados del testbench) y
# analisis_error.py (error vs N iteraciones), de modo que Python y RTL
# siempre hablan el mismo lenguaje de punto fijo.

import os

NB = 16  # ancho de palabra (bits)
N_LUT = 8  # cantidad de entradas de la LUT
A_QUANT = 1 << NB  # escala de "a"  -> U(16,16): a_q = a * 2^16
Y_QUANT = 1 << (NB - 1)  # escala de "y"  -> U(16,15): y_q = y * 2^15
Y_MAX = (1 << NB) - 1  # 0xFFFF (clamp)

DIR = os.path.dirname(os.path.abspath(__file__))
LUT_HEADER = os.path.join(DIR, "lut_y0.vh")


def lut_index(a_q):
    """Indice de la LUT para un 'a' normalizado a [0.5, 1.0)."""
    return (a_q >> 12) & (N_LUT - 1)


def make_lut():
    """Devuelve las 8 entradas y0 (U(16,15)) para los bins de [0.5, 1.0).

    Entrada k: a en [0.5 + k/16, 0.5 + (k+1)/16); y0 = 1/a del punto medio,
    redondeado al nearest y saturado a 0xFFFF.
    """
    entries = []
    for k in range(N_LUT):
        a_mid = (1 << 15) + k * (1 << 12) + (1 << 11)  # punto medio del bin
        y0 = min(round((1 << 31) / a_mid), Y_MAX)  # 2^15/a_mid*2^16
        entries.append(y0)
    return entries


def nr_iterate(a_q, y_q, n_iter):
    """Replica exacta del datapath NR del RTL.

    y_q puede ser la salida de la LUT (n_iter=1..4) o el propio valor de la
    LUT (n_iter=0). Devuelve el 'y' cuantizado tras n_iter iteraciones.
    """
    y_q = int(y_q)
    for _ in range(n_iter):
        p1 = a_q * y_q  # multiplicador 16x16 -> 32
        p1_hi = (p1 + (1 << 15)) >> 16  # round a nearest de p1[31:16]
        t = (1 << 16) - p1_hi  # t = 2 - a*y en U(16,15)
        y_q = min((t * y_q + (1 << 14)) >> 15, Y_MAX)
    return y_q


def y_true_q(a_q):
    """Valor 'verdadero' redondeado: 1/a en U(16,15) (referencia en doble)."""
    return min(round((1 << 31) / a_q), Y_MAX)


def _write_header(entries):
    lines = []
    lines.append("// lut_y0.vh — LUT inicial y0(a) para el divisor por Newton-Raphson.")
    lines.append("// AUTO-GENERADO por gen_lut.py — NO EDITAR A MANO.")
    lines.append("//")
    lines.append("// 8 entradas para 'a' normalizado a [0.5, 1.0), formato U(16,15).")
    lines.append("// index = (a >> 12) & 7  ->  cada bin tiene ancho 1/16.")
    lines.append("//")
    lines.append("function automatic logic [15:0] lut_y0(input logic [2:0] idx);")
    lines.append("  begin")
    lines.append("    case (idx)")
    for k, y0 in enumerate(entries):
        lines.append(f"      3'd{k}: lut_y0 = 16'h{y0:04x};")
    lines.append("      default: lut_y0 = 16'h0000;")
    lines.append("    endcase")
    lines.append("  end")
    lines.append("endfunction")
    lines.append("")
    with open(LUT_HEADER, "w") as f:
        f.write("\n".join(lines))


def main():
    entries = make_lut()

    _write_header(entries)

    print(
        f"LUT y0(a) generada en {os.path.basename(LUT_HEADER)} (formato U(16,15), index = (a >> 12) & 7, {N_LUT} entradas)"
    )
    print("")
    print("  bin |    rango de a     |   a_mid  |    y0 (U16.15)     | y0 dec")
    print("------+-------------------+----------+--------------------+--------")
    for k, y0 in enumerate(entries):
        a_lo = (1 << 15) + k * (1 << 12)
        a_mid = a_lo + (1 << 11)
        print(
            f"  {k}   | [{a_lo/A_QUANT:.4f}, {a_mid/A_QUANT:+.4f}) | "
            f" {a_mid/A_QUANT:.4f}  | 0x{y0:04x}  ({y0/Y_QUANT:.6f}) | {y0}"
        )
    print("")
    print("Error inicial estimado (solo LUT, sin iterar):")
    for k, y0 in enumerate(entries):
        a_lo = (1 << 15) + k * (1 << 12)
        a_hi = a_lo + (1 << 12) - 1
        rels = []
        for a_q in range(a_lo, a_hi + 1):
            rels.append(abs(y0 / (1 << 31) * a_q - 1.0))
        print(f"  bin {k}: error relativo max ~{max(rels)*100:.2f}%")

    print("")
    print("Cross-check del modelo golden (nr_iterate) contra 1/a real:")
    for n in (1, 2, 3, 4):
        max_ulp = 0
        for a_q in range(1 << 15, 1 << 16):
            y = nr_iterate(a_q, entries[lut_index(a_q)], n)
            max_ulp = max(max_ulp, abs(y - y_true_q(a_q)))
        print(f"  N={n}: max error vs valor redondeado = {max_ulp} ULP")


if __name__ == "__main__":
    main()
