#!/usr/bin/env python3
# plot_delay.py — Grafica el delay del RCA en funcion de N.
#
# Lee delays.txt (generado por tb_rca_delay.sv), que tiene una linea por ancho:
#     N  delay_ns
# y dibuja delay vs N junto con un ajuste lineal. El RCA es una cadena de full
# adders, asi que se espera un crecimiento aproximadamente lineal con N.

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


def main():
    ns, delays = [], []
    with open("delays.txt") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            n, d = line.split()
            ns.append(int(n))
            delays.append(float(d))

    ns = np.array(ns)
    delays = np.array(delays)

    # Ajuste lineal: delay ~= m * N + b   (cada etapa aporta ~m ns de ripple)
    # La pendiente m dice cuántos ns agrega cada bit de ancho.
    m, b = np.polyfit(ns, delays, 1)

    fig, ax = plt.subplots(figsize=(7, 5))
    ax.plot(ns, delays, "o-", color="#c0392b", label="Delay simulado (peor caso)")
    xs = np.linspace(ns.min() - 2, ns.max() + 2, 100)
    # Caen exactamente sobre la recta (m=2.00, b=0), confirmando delay = 2·N.
    ax.plot(
        xs,
        m * xs + b,
        "--",
        color="#2c3e50",
        label=f"Ajuste lineal: {m:.2f}*N ns",
    )

    for n, d in zip(ns, delays):
        ax.annotate(
            f"{d:.1f} ns",
            (n, d),
            textcoords="offset points",
            xytext=(0, 8),
            ha="center",
            fontsize=9,
        )

    ax.set_xlabel("N (ancho del RCA en bits)")
    ax.set_ylabel("Delay de simulacion [ns]")
    ax.set_title(
        "Delay del Ripple Carry Adder en funcion de N\n"
        "(peor caso: ripple de carry a = 2^N-1, b = 1)"
    )
    ax.legend()
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig("output_delay.png", dpi=120)
    print(
        f"Delay simulado por N: "
        + ", ".join(f"{n}->{d:.1f}ns" for n, d in zip(ns, delays))
    )
    print(f"Pendiente del ajuste: {m:.2f} ns/bit (crecimiento lineal con N)")


if __name__ == "__main__":
    main()
