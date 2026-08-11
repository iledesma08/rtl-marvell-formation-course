#!/usr/bin/env python3
# gen_vectors.py — Modelo golden para fixed_point_resize (Ejercicio 3: truncado/
# redondeo/saturacion/wrap-around).
#
# 1. Analiza los dos casos puntuales del enunciado:
#      x = 5.5625 en S(10,6) -> S(7,3), truncado y redondeo.
#      y = 8.75   en S(11,6) -> S(5,3), wrap-around y saturacion.
# 2. Genera x.hex / op.hex / expected.hex (mas nv.txt) para el testbench.
# 3. Cross-check: compara fxpmath contra la aritmetica en signo-magnitud
#    (el mismo esquema que usa el RTL, sin complemento a 2).
#
# Los 4 modos se codifican igual que en el RTL (op de 2 bits):
#   2'b00 truncamiento | 2'b01 redondeo | 2'b10 saturacion | 2'b11 wrap-around
#
import os
import random

from fxpmath import Fxp

OP_TRUNC, OP_ROUND, OP_SAT, OP_WRAP = 0, 1, 2, 3

# ---------------------------------------------------------------------------
# Formato de entrada (parametrizable: el RTL usa signo-magnitud, no C2, asi
# que trabajamos siempre con valores reales +/- y anchos NB/NBF por separado)
# ---------------------------------------------------------------------------
W_IN, NF_IN = 11, 6  # x: S(11,6) -> alcanza para ambos casos del enunciado
W_OUT, NF_OUT = 7, 3  # y por default: se pisa segun el caso (ver abajo)

# val_from_bits / sig / to_hex: mismos "descodificadores" que en el script de suma


def val_from_bits(bits, nbits, n_frac):
    """Valor decimal de un patron binario en SIGNO-MAGNITUD (no C2).
    Ejemplo: val_from_bits("01011100100", 11, 6) -> 5.5625."""
    sign = bits[0]
    raw = int(bits[1:], 2)
    val = raw / (1 << n_frac)
    return -val if sign == "1" else val


def sig_mag_bits(value, nbits, n_frac):
    """Valor decimal -> patron binario en signo-magnitud de nbits, n_frac
    bits fraccionales. Ejemplo: sig_mag_bits(-5.5625, 11, 6) -> '10101100100'."""
    sign = "1" if value < 0 else "0"
    mag = round(abs(value) * (1 << n_frac))
    return sign + format(mag, "0%db" % (nbits - 1))


def to_hex(bits):
    """String binario -> hex sin signo con ancho fijo."""
    return format(int(bits, 2), "0%dx" % ((len(bits) + 3) // 4))


def mostrar_caso_1(x_bin):
    """Caso 1 del enunciado: x=5.5625, S(10,6) -> S(7,3), truncado y redondeo."""
    NB_in, NF_in = 10, 6
    NB_out, NF_out = 7, 3

    x_val = val_from_bits(x_bin, NB_in, NF_in)

    trunc_val = trunc_signo_mag(x_val, NB_out, NF_out)
    round_val = round_signo_mag(x_val, NB_out, NF_out)

    print("=" * 64)
    print("CASO 1: x = %.4f en S(%d,%d) -> S(%d,%d)" % (x_val, NB_in, NF_in, NB_out, NF_out))
    print("=" * 64)
    print("  x = %s (bits)" % x_bin)
    print("  Truncamiento: %.4f  (error = %+.4f)" % (trunc_val, x_val - trunc_val))
    print("  Redondeo:     %.4f  (error = %+.4f)" % (round_val, x_val - round_val))
    print("=" * 64)
    print("")


def mostrar_caso_2(y_bin):
    """Caso 2 del enunciado: y=8.75, S(11,6) -> S(5,3), wrap-around y saturacion."""
    NB_in, NF_in = 11, 6
    NB_out, NF_out = 5, 3

    y_val = val_from_bits(y_bin, NB_in, NF_in)

    sat = expected_fxp_signo_mag(y_val, NB_out, NF_out, "trunc", "saturate")
    wrap = expected_fxp_c2(y_val, NB_in, NF_in, NB_out, NF_out)

    print("=" * 64)
    print("CASO 2: y = %.4f en S(%d,%d) -> S(%d,%d)" % (y_val, NB_in, NF_in, NB_out, NF_out))
    print("=" * 64)
    print("  y = %s (bits)" % y_bin)
    print("  Saturacion:   %.4f" % val_from_bits(sat, NB_out, NF_out))
    print("  Wrap-around:  %.4f  (calculado en complemento a 2, ver informe)" % wrap)
    print("=" * 64)
    print("")


# ---------------------------------------------------------------------------
# Truncamiento / redondeo en signo-magnitud (igual que hace el RTL: el signo
# nunca se toca, solo se opera sobre la magnitud)
# ---------------------------------------------------------------------------


def trunc_signo_mag(value, NB_out, NF_out):
    sign = -1 if value < 0 else 1
    mag = Fxp(abs(value), signed=False, n_word=NB_out - 1, n_frac=NF_out,
              rounding="trunc", overflow="saturate")
    return sign * float(mag)


def round_signo_mag(value, NB_out, NF_out):
    sign = -1 if value < 0 else 1
    mag = Fxp(abs(value), signed=False, n_word=NB_out - 1, n_frac=NF_out,
              rounding="nearest_posinf", overflow="saturate")
    return sign * float(mag)


def expected_fxp_signo_mag(value, NB_out, NF_out, rounding, overflow):
    """Devuelve el patron de bits (signo + magnitud) esperado."""
    sign = "1" if value < 0 else "0"
    mag = Fxp(abs(value), signed=False, n_word=NB_out - 1, n_frac=NF_out,
              rounding=rounding, overflow=overflow)
    return sign + mag.bin()


def expected_fxp_c2(value, NB_in, NF_in, NB_out, NF_out):
    """Wrap-around: se calcula igual que hace el hardware -> se interpreta el
    numero como si estuviera en complemento a 2 y se descartan los bits mas
    significativos que sobran al reducir el ancho (ver charla sobre wrap)."""
    x = Fxp(value, signed=True, n_word=NB_in, n_frac=NF_in)
    x.rounding = "trunc"
    x.overflow = "wrap"
    x.resize(n_word=NB_out, n_frac=NF_out)
    return float(x)


def generar_vectores():
    """Genero DOS conjuntos de archivos separados, cada uno respetando el
    supuesto de diseño del RTL para ese par de modos (los parametros de un
    modulo Verilog son fijos en tiempo de compilacion, asi que no se puede
    mezclar un unico barrido con dos anchos distintos en una sola instancia):

      - truncamiento/redondeo (op 00/01): SOLO cambia NF, NBI se mantiene
        constante -> S(10,6) -> S(7,3) (NBI_in = NBI_out = 3), igual que el
        Ejercicio 1. El RTL no chequea overflow en estos casos.
        Archivos: x_tr.hex / op_tr.hex / expected_tr.hex / nv_tr.txt

      - saturacion/wrap-around (op 10/11): cambia NBI -> S(11,6) -> S(5,3)
        (NBI_in=4, NBI_out=1), igual que el Ejercicio 2.
        Archivos: x_sat.hex / op_sat.hex / expected_sat.hex / nv_sat.txt
    """

    # --- Conjunto 1: truncamiento y redondeo (S(10,6) -> S(7,3), NBI fijo) ---
    NB_in_1, NF_in_1 = 10, 6
    NB_out_1, NF_out_1 = 7, 3
    vecs_1 = []

    for x_raw in range(1 << NB_in_1):
        for op in (OP_TRUNC, OP_ROUND):
            x_bits = format(x_raw, "0%db" % NB_in_1)
            x_sign = x_bits[0]  # preservo el signo ORIGINAL (evito perder "-0")
            x_val = val_from_bits(x_bits, NB_in_1, NF_in_1)
            rounding = "trunc" if op == OP_TRUNC else "nearest_posinf"
            # sin saturacion: el RTL no chequea overflow en estos 2 casos
            y_bits = x_sign + expected_fxp_signo_mag(x_val, NB_out_1, NF_out_1, rounding, "wrap")[1:]
            vecs_1.append((x_bits, op, y_bits))

    with open("x_tr.hex", "w") as fx, open("op_tr.hex", "w") as fo, open(
        "expected_tr.hex", "w"
    ) as fe:
        for x_bits, op, y_bits in vecs_1:
            fx.write(to_hex(x_bits) + "\n")
            fo.write(format(op, "01x") + "\n")
            fe.write(to_hex(y_bits) + "\n")
    with open("nv_tr.txt", "w") as fn:
        fn.write(format(len(vecs_1), "08x") + "\n")

    # --- Conjunto 2: saturacion y wrap-around (S(11,6) -> S(5,3), NBI cambia) ---
    NB_in_2, NF_in_2 = 11, 6
    NB_out_2, NF_out_2 = 5, 3
    vecs_2 = []

    for x_raw in range(1 << NB_in_2):
        for op in (OP_SAT, OP_WRAP):
            x_bits = format(x_raw, "0%db" % NB_in_2)
            x_sign = x_bits[0]  # preservo el signo ORIGINAL (evito perder "-0")
            x_val = val_from_bits(x_bits, NB_in_2, NF_in_2)
            if op == OP_SAT:
                y_bits = x_sign + expected_fxp_signo_mag(x_val, NB_out_2, NF_out_2, "trunc", "saturate")[1:]
            else:  # OP_WRAP: en SIGNO-MAGNITUD el signo se preserva siempre,
                   # solo se recorta la magnitud (igual que hace el RTL) --
                   # NO es el wrap de complemento a 2 (ese voltea el signo)
                y_bits = x_sign + expected_fxp_signo_mag(x_val, NB_out_2, NF_out_2, "trunc", "wrap")[1:]
            vecs_2.append((x_bits, op, y_bits))

    with open("x_sat.hex", "w") as fx, open("op_sat.hex", "w") as fo, open(
        "expected_sat.hex", "w"
    ) as fe:
        for x_bits, op, y_bits in vecs_2:
            fx.write(to_hex(x_bits) + "\n")
            fo.write(format(op, "01x") + "\n")
            fe.write(to_hex(y_bits) + "\n")
    with open("nv_sat.txt", "w") as fn:
        fn.write(format(len(vecs_2), "08x") + "\n")

    print("Truncamiento/redondeo -> %d vectores en x_tr.hex / op_tr.hex / expected_tr.hex" % len(vecs_1))
    print("  S(%d,%d) -> S(%d,%d), NBI constante" % (NB_in_1, NF_in_1, NB_out_1, NF_out_1))
    print("Saturacion/wrap-around -> %d vectores en x_sat.hex / op_sat.hex / expected_sat.hex" % len(vecs_2))
    print("  S(%d,%d) -> S(%d,%d), NBI cambia" % (NB_in_2, NF_in_2, NB_out_2, NF_out_2))
    print("")


if __name__ == "__main__":
    X_BIN = sig_mag_bits(5.5625, 10, 6)
    Y_BIN = sig_mag_bits(8.75, 11, 6)

    mostrar_caso_1(X_BIN)
    mostrar_caso_2(Y_BIN)

    generar_vectores()


# NOTA para nosotros: sobre redondeo: fxpmath usa 'around' (round-half-to-even) por default,
# pero el RTL implementa "sumar el bit de guarda y truncar" -> eso es
# round-half-up. El modo equivalente en fxpmath es 'nearest_posinf'.


# Lo divido en vectores de sat y de truncamiento porque asi esta pensado RTL, es mas por los tamaños del formato
