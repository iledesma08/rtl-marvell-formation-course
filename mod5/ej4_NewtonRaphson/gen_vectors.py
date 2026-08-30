#!/usr/bin/env python3
# gen_vectors.py — Genera los vectores dorados para el testbench del divisor
# por Newton-Raphson (Ejercicio 4, mod5).
#
# Escribe:
#   a.hex          -> "a" normalizado a [0.5, 1.0) en U(16,16)
#   y_exp_N.hex    -> salida esperada en U(16,15) tras N iteraciones NR
#                     (N = 1..4), calculada con el modelo golden de
#                     gen_lut.nr_iterate (misma aritmetica que el RTL).
#
# El testbench lee estos archivos con $readmemh y compara bit a bit contra
# cada DUT (uno por N_ITER). Asi, la "referencia" y el hardware comparten
# exactamente el mismo punto fijo y cualquier diferencia es un bug real.

import os
import random
import sys

from gen_lut import lut_index, make_lut, nr_iterate

DIR = os.path.dirname(os.path.abspath(__file__))

N_VECTORS_DEFAULT = 1000

# Casos de borde: 0.5 exacto, casi 1, y valores "redondos" del rango.
EDGE_CASES = [
    0x8000,
    0x8001,
    0x9FFF,
    0xAAAA,
    0xBFFF,
    0xC000,
    0xE000,
    0xFFFF,
]


def main():
    n_vectors = int(sys.argv[1]) if len(sys.argv) > 1 else N_VECTORS_DEFAULT
    lut = make_lut()

    rng = random.Random(2026)  # seed fijo -> reproducible
    a_vals = EDGE_CASES + [rng.randrange(0x8000, 0x10000) for _ in range(n_vectors)]

    with open(os.path.join(DIR, "a.hex"), "w") as fa, open(
        os.path.join(DIR, "y_exp_1.hex"), "w"
    ) as f1, open(os.path.join(DIR, "y_exp_2.hex"), "w") as f2, open(
        os.path.join(DIR, "y_exp_3.hex"), "w"
    ) as f3, open(
        os.path.join(DIR, "y_exp_4.hex"), "w"
    ) as f4, open(
        os.path.join(DIR, "nvec.txt"), "w"
    ) as fn:
        fn.write(f"{len(a_vals)}\n")
        for a_q in a_vals:
            y0 = lut[lut_index(a_q)]
            fa.write(f"{a_q:04x}\n")
            f1.write(f"{nr_iterate(a_q, y0, 1):04x}\n")
            f2.write(f"{nr_iterate(a_q, y0, 2):04x}\n")
            f3.write(f"{nr_iterate(a_q, y0, 3):04x}\n")
            f4.write(f"{nr_iterate(a_q, y0, 4):04x}\n")

    print(
        f"Generados {len(a_vals)} vectores ({len(EDGE_CASES)} bordes + "
        f"{n_vectors} random): a.hex + y_exp_1..4.hex"
    )


if __name__ == "__main__":
    main()
