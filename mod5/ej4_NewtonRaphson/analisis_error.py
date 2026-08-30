#!/usr/bin/env python3
# analisis_error.py — Analisis de error vs N iteraciones (Entregable d).
#
# Barre la totalidad del rango normalizado de "a" (los 32768 valores de
# [0.5, 1.0) cuantizados a U(16,16)) y mide, para N = 0..4 iteraciones NR:
#   - error absoluto maximo (en ULP de U(16,15))
#   - error relativo maximo y medio
#   - bits correctos aproximados (log2(1/error_rel_max))
#
# Usa el modelo golden de gen_lut.nr_iterate (misma aritmetica que el RTL),
# asi que la tabla refleja exactamente lo que entrega el hardware. N=0 es la
# LUT sola (sin iterar). Genera output_ej4.png.

import os

import numpy as np

from gen_lut import make_lut, lut_index, y_true_q

DIR = os.path.dirname(os.path.abspath(__file__))
N_MAX = 4


# ---------------------------------------------------------------------
# Version vectorizada de nr_iterate: replica la aritmetica del RTL.
# ---------------------------------------------------------------------
def nr_iterate_vec(a_q, y_q, n_iter):
    y_q = y_q.astype(np.int64)
    for _ in range(n_iter):
        p1 = a_q * y_q  # 16x16 -> 32
        p1_hi = (p1 + (1 << 15)) >> 16  # round(p1[31:16])
        t = (1 << 16) - p1_hi  # t = 2 - a*y
        y_q = np.minimum((t * y_q + (1 << 14)) >> 15, 0xFFFF)
    return y_q


def main():
    a_q = np.arange(1 << 15, 1 << 16, dtype=np.int64)  # 32768..65535
    y_true = np.array([y_true_q(a) for a in a_q], dtype=np.int64)

    lut = make_lut()
    y0 = np.array([lut[lut_index(a)] for a in a_q], dtype=np.int64)

    print(
        "Analisis de error del divisor NR (barrido completo de "
        "[0.5, 1.0) x 32768 valores)"
    )
    print("")
    print(
        "  N | bits y0  | max err [ULP] | max err rel  | mean err rel | bits correctos"
    )
    print(
        "----+----------+---------------+--------------+--------------+---------------"
    )

    results = []
    y_prev = y0
    for n in range(N_MAX + 1):
        if n > 0:
            y_prev = nr_iterate_vec(a_q, y_prev, 1)
        err_abs = np.abs(y_prev - y_true)
        err_rel = err_abs / y_true
        max_ulp = int(err_abs.max())
        max_rel = float(err_rel.max())
        mean_rel = float(err_rel.mean())
        bits = float(-np.log2(max_rel)) if max_rel > 0 else float("inf")
        results.append((n, max_ulp, max_rel, mean_rel, bits))
        print(
            f"  {n} | {'solo LUT' if n == 0 else 'NR x%d  ' % n:8s} |"
            f" {max_ulp:12d}  | {max_rel:12.3e} | {mean_rel:12.3e} | {bits:12.2f}"
        )

    print("")
    print(
        "Conclusion: con 3 iteraciones ya se alcanza el piso de 1 ULP de U(16,15) (error relativo ~3e-5 = 2^-15, el limite del punto fijo);"
    )

    # -----------------------------------------------------------------
    # Grafico (opcional): error absoluto maximo vs N.
    # -----------------------------------------------------------------
    try:
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        ns = [r[0] for r in results]
        ulps = [r[1] for r in results]
        fig, ax = plt.subplots(figsize=(7, 5))
        ax.semilogy(ns, [max(u, 1) for u in ulps], "o-", color="#c0392b")
        ax.set_xticks(ns)
        ax.set_xlabel("N (iteraciones NR)")
        ax.set_ylabel("Error absoluto maximo [ULP de U(16,15)]")
        ax.set_title("Error vs N iteraciones del divisor por Newton-Raphson")
        ax.grid(True, which="both", alpha=0.3)
        for n, u in zip(ns, ulps):
            ax.annotate(
                str(u),
                (n, max(u, 1)),
                textcoords="offset points",
                xytext=(0, 8),
                ha="center",
                fontsize=9,
            )
        fig.tight_layout()
        fig.savefig(os.path.join(DIR, "output_ej4.png"), dpi=120)
        print("Grafico guardado en output_ej4.png")
    except ImportError:
        print("matplotlib no disponible: se omite el grafico output_ej4.png")


if __name__ == "__main__":
    main()
