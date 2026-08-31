#!/usr/bin/env python3
# gen_roms.py — Genera las ROMs y los vectores de test del Ejercicio 3
#
# Salidas:
#   atan_lut.vh   -> tabla atan(2^-i) en S(16,14), unidades de pi (16 entradas)
#   sqrt_rom.hex  -> ROM de raiz cuadrada para la referencia directa (64K x 16)
#   atan2_rom.hex -> ROM de atan2 para la referencia directa (64K x 16)
#   vectors.hex   -> vectores de test (x y en hex por linea, S(16,15))
#   nvec.txt      -> cantidad de vectores

import math
import random
import os

S16_15 = 2**15
S16_14 = 2**14

# Directorio donde van los datos generados (ROMs .hex, vectores .txt).
# atan_lut.vh NO va aca: se `include` desde rom_atan.sv, asi que queda en la raiz.
D = "datos"
os.makedirs(D, exist_ok=True)


def q15(v):
    # Cuantiza un real al formato S(16,15) con redondeo a nearest.
    return round(v * S16_15)


def q14_pi(ang_rad):
    # Cuantiza un angulo en radianes a S(16,14) expresado en unidades de pi.
    return round(ang_rad / math.pi * S16_14)


# ---------------------------------------------------------------------------
# 1) Tabla atan(2^-i) en unidades de pi, S(16,14) -> atan_lut.vh
# ---------------------------------------------------------------------------
atan_q = [q14_pi(math.atan(2.0**-i)) for i in range(16)]

with open("atan_lut.vh", "w") as f:
    f.write("// atan_lut.vh — tabla atan(2^-i) en S(16,14), unidades de pi.\n")
    f.write("// Generado por gen_roms.py. No editar.\n")
    f.write("case (index)\n")
    for i, v in enumerate(atan_q):
        f.write("  4'd%-2d: value = 16'sd%-6d; // atan(2^-%2d)/pi * 2^14\n" % (i, v, i))
    f.write("  default: value = 16'sd0;\n")
    f.write("endcase\n")

print("")
print("atan_lut.vh: %d entradas (S16.14, unidades de pi)" % len(atan_q))

# ---------------------------------------------------------------------------
# 2) ROM de raiz cuadrada (64K x 16) para la referencia directa
# ---------------------------------------------------------------------------
N_SQRT = 65536
with open(os.path.join(D, "sqrt_rom.hex"), "w") as f:
    for k in range(N_SQRT):
        s_mid = (k + 0.5) * 2**15  # punto medio del bin de s
        r_q = round(math.sqrt(s_mid))
        f.write("%04X\n" % (r_q & 0xFFFF))

print("sqrt_rom.hex: %d entradas x 16 bits (%d bits)" % (N_SQRT, N_SQRT * 16))

# ---------------------------------------------------------------------------
# 3) ROM de atan2 para la referencia directa (64K x 16)
#    Indice: q = min(|y|,|x|)/max(|y|,|x|) en U(16,16). Salida: atan(q)/pi.
# ---------------------------------------------------------------------------
N_ATAN2 = 65536
with open(os.path.join(D, "atan2_rom.hex"), "w") as f:
    for q in range(N_ATAN2):
        ratio = q / 65536.0
        t = round(math.atan(ratio) / math.pi * S16_14)
        f.write("%04X\n" % (t & 0xFFFF))

print("atan2_rom.hex: %d entradas x 16 bits (%d bits)" % (N_ATAN2, N_ATAN2 * 16))

# ---------------------------------------------------------------------------
# 4) Vectores de test (cuadrantes I..IV)
# ---------------------------------------------------------------------------
random.seed(2026)
vecs = []  # (x_q, y_q)


def add_vec(ang_deg, r):
    a = math.radians(ang_deg)
    xq = q15(r * math.cos(a))
    yq = q15(r * math.sin(a))
    vecs.append((xq, yq))


# 4.1) Barrido fijo por cuadrante (radio 0.8)
for q_off, a_list in (
    (0, [15, 30, 45, 60, 75]),  # QI
    (90, [15, 30, 45, 60, 75]),  # QII
    (-90, [-15, -30, -45, -60, -75]),  # QIII
    (0, [-15, -30, -45, -60, -75]),  # QIV
):
    for a in a_list:
        add_vec(q_off + a, 0.8)

# 4.2) Casos de borde (ejes y cerca de las verticales)
for ang_deg, r in (
    (0, 0.8),
    (180, 0.8),
    (90, 0.8),
    (-90, 0.8),
    (89.7, 0.8),
    (90.3, 0.8),
    (-89.7, 0.8),
    (-90.3, 0.8),
):
    add_vec(ang_deg, r)

# 4.3) Aleatorios: 200 por cuadrante, R en [0.2, 0.95]
for q_lo, q_hi in ((0, 90), (90, 180), (-90, 0), (-180, -90)):
    for _ in range(200):
        a = random.uniform(q_lo + 1, q_hi - 1)
        r = random.uniform(0.2, 0.95)
        add_vec(a, r)

# 4.4) Saneo: nada en (0,0), nada con R >= 1 (salida saturada fuera de rango)
assert all(xq != 0 or yq != 0 for xq, yq in vecs), "vector (0,0) presente"
for xq, yq in vecs:
    assert xq * xq + yq * yq < (1 << 30), "R >= 1 en un vector de test"

with open(os.path.join(D, "vectors.hex"), "w") as f:
    for xq, yq in vecs:
        f.write("%04X %04X\n" % (xq & 0xFFFF, yq & 0xFFFF))

with open(os.path.join(D, "nvec.txt"), "w") as f:
    f.write("%d\n" % len(vecs))

# Resumen por cuadrante (angulo real del vector)
n_q = [0, 0, 0, 0]
for xq, yq in vecs:
    if xq >= 0 and yq >= 0:
        n_q[0] += 1
    elif xq < 0 and yq >= 0:
        n_q[1] += 1
    elif xq < 0 and yq < 0:
        n_q[2] += 1
    else:
        n_q[3] += 1

print("vectors.hex: %d vectores" % (len(vecs)))
