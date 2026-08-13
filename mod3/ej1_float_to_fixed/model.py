#!/usr/bin/env python3
# gen_vectors.py — Modelo golden para conversion_float_to_fixed (Ejercicio 1:
# IEEE754 simple precision -> punto fijo S(NB, NF)).
#
# 1. Analiza el caso puntual del enunciado: x = 9.625 -> S(8,3).
#    Muestra los bits IEEE754 (signo, exponente, mantisa) y el resultado
#    esperado en punto fijo signo-magnitud.
# 2. Genera los archivos x.hex / expected.hex (mas nv.txt con la cantidad de
#    vectores) que consume el testbench self-checking en SystemVerilog.
# 3. Cross-check: compara el modelo fxpmath contra el calculo manual de
#    normalizacion + shift (el mismo mecanismo que usa el RTL).
#
import os
import random
import struct

from fxpmath import Fxp

# ---------------------------------------------------------------------------
# Formato de salida: S(NB, NF) -- por defecto el del enunciado, S(8,3)
# ---------------------------------------------------------------------------
NB, NF = 8, 3



def float_a_bits_ieee754(value):
    """Float de Python -> string de 32 bits IEEE754 simple precision.
    Ejemplo: float_a_bits_ieee754(9.625) -> '01000001000110100000000000000000'."""
    packed = struct.pack(">f", value)
    n = int.from_bytes(packed, "big")
    return format(n, "032b")


def bits_ieee754_a_float(bits):
    """String de 32 bits IEEE754 -> float de Python (el decodificador inverso)."""
    n = int(bits, 2)
    packed = n.to_bytes(4, "big")
    return struct.unpack(">f", packed)[0]


def to_hex(bits):
    """String binario -> hex sin signo con ancho fijo."""
    return format(int(bits, 2), "0%dx" % ((len(bits) + 3) // 4))



def esperado_signo_mag(value, NB, NF):
    """Devuelve el patron de bits S(NB,NF) esperado para 'value', en
    signo-magnitud (bit de signo aparte, nunca tocado por la magnitud)."""
    sign = "1" if value < 0 else "0"
    mag = Fxp(abs(value), signed=False, n_word=NB - 1, n_frac=NF,
              rounding="trunc", overflow="saturate")
    return sign + mag.bin()


def mostrar_caso_enunciado(x_val, NB, NF):
    """Entregables del caso puntual: bits IEEE754 (signo/exponente/mantisa),
    normalizacion + shift (el mismo mecanismo que usa el RTL) y verificacion
    contra el modelo golden."""
    x_bits = float_a_bits_ieee754(x_val)
    sign_ieee = x_bits[0]
    exp_biased = int(x_bits[1:9], 2)
    mantisa = x_bits[9:]
    exp_real = exp_biased - 127

    # Reconstruyo 1.mantisa * 2^exp_real, igual que hace el RTL con el shift
    normalizado = (1 << 23) | int(mantisa, 2)
    if exp_real >= 0:
        numero_32 = normalizado << exp_real
    else:
        numero_32 = normalizado >> (-exp_real)
    MANT_W = 23
    NI = NB - 1 - NF
    entero = (numero_32 >> MANT_W) & ((1 << NI) - 1)
    fraccion = (numero_32 >> (MANT_W - NF)) & ((1 << NF) - 1)
    overflow = (numero_32 >> (MANT_W + NI)) != 0

    esperado = esperado_signo_mag(x_val, NB, NF)

    print("=" * 64)
    print("CASO PARTICULAR DEL ENUNCIADO: x = %.4f -> S(%d,%d)" % (x_val, NB, NF))
    print("=" * 64)
    print("  IEEE754 (32 bits): %s" % x_bits)
    print("    signo=%s  exponente=%s (sesgo=%d, real=%d)  mantisa=%s" %
          (sign_ieee, x_bits[1:9], exp_biased, exp_real, mantisa))
    print("")
    print("  Normalizado (1.mantisa << exp_real):")
    print("    entero=%s  fraccion=%s  overflow=%s" %
          (format(entero, "0%db" % NI), format(fraccion, "0%db" % NF), overflow))
    print("")
    print("  Resultado esperado (signo-magnitud): %s" % esperado)
    if not overflow:
        assert esperado == sign_ieee + format(entero, "0%db" % NI) + format(fraccion, "0%db" % NF), \
            "el calculo manual no coincide con fxpmath!"
        print("  Coincide con el calculo manual (shift + bit-slicing): OK")
    print("=" * 64)
    print("")


def generar_vectores(NB, NF):
    """Genero vectores barriendo un conjunto de floats representativos
    (positivos, negativos, con overflow, con exponente negativo, y en el
    limite exacto de representacion), mas un barrido aleatorio grande."""
    vecs = []

    def push(value):
        x_bits = float_a_bits_ieee754(value)
        sign_ieee = x_bits[0]   # preservo el signo IEEE754 ORIGINAL (evito perder "-0.0")
        y_bits = sign_ieee + esperado_signo_mag(value, NB, NF)[1:]
        vecs.append((x_bits, y_bits))

    # Vector 0: el caso del enunciado
    push(9.625)

    # Casos especiales ya verificados a mano con el RTL
    casos_especiales = [-9.625, 20.5, 0.625, 15.875, -15.875, 0.0, -0.0, 0.0625]
    for v in casos_especiales:
        push(v)

    n_vec = int(os.environ.get("N_VECTORS", "2000"))
    random.seed(2026)
    for _ in range(n_vec):
        exp = random.uniform(-4, 5)
        mag = random.uniform(0, 2 ** exp)
        sign = random.choice([1, -1])
        push(sign * mag)

    n = len(vecs)
    with open("x.hex", "w") as fx, open("expected.hex", "w") as fe:
        for x_bits, y_bits in vecs:
            fx.write(to_hex(x_bits) + "\n")
            fe.write(to_hex(y_bits) + "\n")
    with open("nv.txt", "w") as fn:
        fn.write(format(n, "08x") + "\n")

    print("Vectores generados -> %d en x.hex / expected.hex" % n)
    print("")


if __name__ == "__main__":
    mostrar_caso_enunciado(9.625, NB, NF)
    generar_vectores(NB, NF)