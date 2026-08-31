#!/usr/bin/env python3
# analisis_error.py — Analiza el error vs cuadrante del Ejercicio 3 a partir
# de errores.csv (generado por tb_cordic_vect.sv) y genera output_ej3.png.
#
# El grafico es un grid 2x2 de barras agrupadas: para R y para phi, el error
# MAXIMO y el error MEDIO por cuadrante (CORDIC azul vs referencia naranja).
#
# Salidas:
#   output_ej3.png   -> grafico de error vs cuadrante (entregable d)
#   resumen en terminal

import numpy as np
from PIL import Image, ImageDraw, ImageFont

CSV = "datos/errores.csv"
OUT = "output_ej3.png"

COL_CORDIC = (31, 119, 180)  # azul
COL_REF = (255, 127, 14)  # naranja
COL_GRID = (200, 200, 200)
COL_TXT = (20, 20, 20)

FONT_REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def font(size, bold=False):
    try:
        return ImageFont.truetype(FONT_BOLD if bold else FONT_REG, size)
    except OSError:
        return ImageFont.load_default()


def bar_chart(draw, box, title, vals_c, vals_r, ymax, ylabel):
    """Dibuja un grafico de barras agrupadas (CORDIC vs REF) por cuadrante."""
    x0, y0, x1, y1 = box  # area del plot (sin margen interno)
    f_tit = font(17, bold=True)
    f_lab = font(13)
    f_val = font(12)

    draw.text((x0, y0 - 6), title, font=f_tit, fill=COL_TXT)

    plot_top = y0 + 26
    plot_bot = y1
    plot_h = plot_bot - plot_top

    # cuadricula vertical (1 ULP por paso) + ejes
    for yv in range(0, ymax + 1, 1):
        yy = plot_bot - (yv / ymax) * plot_h
        draw.line([x0, yy, x1, yy], fill=COL_GRID if yv else COL_TXT, width=1)
        draw.text((x0 - 8, yy - 7), str(yv), font=f_lab, fill=COL_TXT, anchor="rm")

    groups = 4
    gw = (x1 - x0) / groups
    n_ser = 2
    for g in range(groups):
        cx = x0 + (g + 0.5) * gw
        for v, col, side in ((vals_c[g], COL_CORDIC, -1), (vals_r[g], COL_REF, +1)):
            bw = gw * 0.33
            bx = cx + side * (gw * 0.17) - bw / 2
            bh = (v / ymax) * plot_h
            draw.rectangle([bx, plot_bot - bh, bx + bw, plot_bot], fill=col)
            if v > 0:
                draw.text(
                    (bx + bw / 2, plot_bot - bh - 4),
                    ("%d" % v) if float(v).is_integer() else ("%.2f" % v),
                    font=f_val,
                    fill=COL_TXT,
                    anchor="ms",
                )
        draw.text(
            (cx, plot_bot + 8), "Q%d" % (g + 1), font=f_lab, fill=COL_TXT, anchor="mm"
        )

    draw.text(
        (x0 + (x1 - x0) / 2, plot_bot + 30),
        ylabel,
        font=f_lab,
        fill=(90, 90, 90),
        anchor="mm",
    )


def main():
    data = np.genfromtxt(CSV, delimiter=",", skip_header=1)
    q = data[:, 0].astype(int)
    errR_c, errR_r = data[:, 2], data[:, 3]
    errP_c, errP_r = data[:, 4], data[:, 5]

    n_vec = len(q)
    print("")
    print("errores.csv: %d vectores" % n_vec)

    # ---- Metricas por cuadrante ------------------------------------------
    maxRc, meanRc = [], []
    maxRr, meanRr = [], []
    maxPc, meanPc = [], []
    maxPr, meanPr = [], []
    for qq in range(1, 5):
        m = q == qq
        maxRc.append(errR_c[m].max())
        meanRc.append(errR_c[m].mean())
        maxRr.append(errR_r[m].max())
        meanRr.append(errR_r[m].mean())
        maxPc.append(errP_c[m].max())
        meanPc.append(errP_c[m].mean())
        maxPr.append(errP_r[m].max())
        meanPr.append(errP_r[m].mean())

    # ---- Resumen por cuadrante (terminal) --------------------------------
    # Tabla alineada: se calculan los anchos por columna y se usa la misma
    # funcion para encabezado y filas, asi los separadores "|" siempre calzan.
    head = [
        "Q",
        "R CORDIC max/med",
        "R ref max/med",
        "phi CORDIC max/med",
        "phi ref max/med",
    ]
    rows = []
    for i in range(4):
        rows.append(
            [
                "%d" % (i + 1),
                "%d/%.2f" % (maxRc[i], meanRc[i]),
                "%d/%.2f" % (maxRr[i], meanRr[i]),
                "%d/%.2f" % (maxPc[i], meanPc[i]),
                "%d/%.2f" % (maxPr[i], meanPr[i]),
            ]
        )
    widths = [max(len(head[c]), *(len(r[c]) for r in rows)) for c in range(len(head))]

    def line(cells):
        return "  " + " | ".join(cell.ljust(widths[c]) for c, cell in enumerate(cells))

    def sep(cells):
        return "  " + " + ".join("-" * widths[c] for c in range(len(cells)))

    print("")
    print(line(head))
    print(sep(head))
    for r in rows:
        print(line(r))
    print(sep(head))
    print("")
    print(
        "  Peor caso total: R CORDIC=%d ULP, R ref=%d ULP | "
        "phi CORDIC=%d ULP, phi ref=%d ULP"
        % (errR_c.max(), errR_r.max(), errP_c.max(), errP_r.max())
    )

    # ---- Grafico 2x2 de barras agrupadas ---------------------------------
    W, H = 1500, 1040
    ml, mr, mt, mb = 130, 60, 150, 90
    gx, gy = 110, 60
    pw = (W - ml - mr - gx) // 2
    ph = (H - mt - mb - gy) // 2

    img = Image.new("RGB", (W, H), (255, 255, 255))
    draw = ImageDraw.Draw(img)
    f_tit = font(26, bold=True)
    f_sub = font(16)

    draw.text(
        (W // 2, 34),
        "Ejercicio 3 — CORDIC Vectoring: error vs cuadrante",
        font=f_tit,
        fill=COL_TXT,
        anchor="mm",
    )
    draw.text(
        (W // 2, 68),
        "Error en ULP por cuadrante. Azul: CORDIC vectoring. "
        "Naranja: referencia (mult + ROM).",
        font=f_sub,
        fill=(90, 90, 90),
        anchor="mm",
    )

    # leyenda
    ly = 100
    draw.rectangle([W // 2 - 150, ly, W // 2 - 150 + 18, ly + 18], fill=COL_CORDIC)
    draw.text((W // 2 - 126, ly), "CORDIC vectoring", font=f_sub, fill=COL_TXT)
    draw.rectangle([W // 2 + 40, ly, W // 2 + 58, ly + 18], fill=COL_REF)
    draw.text((W // 2 + 64, ly), "Referencia (mult + ROM)", font=f_sub, fill=COL_TXT)

    x0s = ml
    x1s = W - mr
    y0s = mt
    y1s = H - mb

    # fila superior: R ; fila inferior: phi
    boxes = [
        (x0s, y0s, x0s + pw, y0s + ph),  # R max
        (x0s + pw + gx, y0s, x1s, y0s + ph),  # R mean
        (x0s, y0s + ph + gy, x0s + pw, y1s),  # phi max
        (x0s + pw + gx, y0s + ph + gy, x1s, y1s),  # phi mean
    ]

    # escalas compartidas para que las comparaciones sean claras
    bar_chart(
        draw,
        boxes[0],
        "R — error máximo [ULP]",
        maxRc,
        maxRr,
        5,
        "producto de la simulación",
    )
    bar_chart(
        draw,
        boxes[1],
        "R — error medio [ULP]",
        meanRc,
        meanRr,
        2,
        "media por cuadrante",
    )
    bar_chart(
        draw,
        boxes[2],
        "φ — error máximo [ULP]",
        maxPc,
        maxPr,
        5,
        "producto de la simulación",
    )
    bar_chart(
        draw,
        boxes[3],
        "φ — error medio [ULP]",
        meanPc,
        meanPr,
        2,
        "media por cuadrante",
    )

    # eje X comun
    for x0, y0, x1, y1 in boxes:
        draw.text(
            ((x0 + x1) / 2, y1 + 46),
            "cuadrante",
            font=f_sub,
            fill=(120, 120, 120),
            anchor="mm",
        )

    img.save(OUT)


if __name__ == "__main__":
    main()
