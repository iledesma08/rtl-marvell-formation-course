#!/usr/bin/env python3
# gen_vectors.py — Modelo golden para la multiplicacion Booth radix-2 (Ejercicio Booth).
#
# 1. Analiza el caso puntual del enunciado: A=+6 (S(4,0)), B=-5 (S(4,0)).
#    Muestra los bits en C2, la tabla de pasos de Booth (pares bi/bi-1, accion,
#    producto parcial) y la verificacion decimal (A*B = -30).
# 2. Genera los archivos a.hex / b.hex / expected.hex (mas nv.txt con la cantidad
#    de vectores) que consume el testbench self-checking en SystemVerilog.
# 3. Cross-check: compara el modelo fxpmath contra la aritmetica binaria en C2.
#
# Regla del enunciado: se agrega el bit b(-1) = 0, y se recorren W_B pasos
# (uno por cada bit de B), acumulando +A, -A o nada segun el par (bi, bi-1).
import os
import random

from fxpmath import Fxp

# ---------------------------------------------------------------------------
# Formatos de entrada (numeros enteros con signo, sin parte fraccionaria)
# ---------------------------------------------------------------------------
W_A, NF_A = 4, 0  # A: S(4,0), con signo
W_B, NF_B = 4, 0  # B: S(4,0), con signo

# ---------------------------------------------------------------------------
# Formato de salida (regla estandar de multiplicacion: bits_P = bits_A + bits_B)
# ---------------------------------------------------------------------------
NBF = 0  # el producto de dos enteros sigue siendo entero
NB = W_A + W_B  # NB_out = 8 -> S(8,0)



def val_from_bits(bits, nbits, n_frac):
    """Valor decimal de un patron binario en complemento a 2.
    Ejemplo: val_from_bits("1011", 4, 0) -> -5 (0b1011 = 0xB)."""
    raw = int(bits, 2)  # lee "1011" como entero SIN signo -> 11
    if raw & (1 << (nbits - 1)):  # esta el bit de signo en 1? (0b1000 = 8)
        raw -= 1 << nbits  # si -> resto 2^nbits (2^4 = 16) -> 11 - 16 = -5
    return raw / (1 << n_frac)  # y divido por 2^NBF (2^0 = 1) -> -5/1 = -5.0


def sig(raw, nbits):
    """Entero con signo a partir del patron sin signo de nbits.
    Ejemplo: sig(11, 4) -> -5 (0b1011 = 0xB)."""
    if raw & (1 << (nbits - 1)):
        return raw - (1 << nbits)
    return raw


# to_hex es el "codificador" inverso para escribir los .hex


def to_hex(value, nbits):
    """Patron binario C2 -> hex sin signo de nbits con ancho fijo.
    Ejemplo: to_hex(-5, 4) -> "b" (0b1011 = 11)."""
    wrapped_value = value & ((1 << nbits) - 1)
    return format(wrapped_value, "0%dx" % ((nbits + 3) // 4))


# ---------------------------------------------------------------------------
# Booth radix-2: recorre B agregando b(-1)=0, y para cada par (bi, bi-1)
# decide la accion (+A, -A, nada) con el mismo criterio que el 'case' del RTL
# ---------------------------------------------------------------------------


def tabla_booth(a_val, b_raw):
    """Genera la tabla de pasos de Booth radix-2 para un B de W_B bits.
    Devuelve la lista de filas (i, bi, bi_1, accion, producto_parcial) y el
    acumulado final (== A*B)."""
    b_ext = b_raw << 1  # agrego b(-1) = 0 en el bit menos significativo
    filas = []
    acumulado = 0

    for i in range(1, W_B + 1):
        ventana = (b_ext >> (i - 1)) & 0b11  # {bi, bi-1}, igual que x[i -: 2] en el RTL
        bi = (ventana >> 1) & 1
        bi_1 = ventana & 1

        if ventana == 0b01:
            accion, factor = "+A", +1
        elif ventana == 0b10:
            accion, factor = "-A", -1
        else:  # 00 o 11
            accion, factor = "  0", 0

        producto_parcial = factor * a_val * (1 << (i - 1))
        acumulado += producto_parcial
        filas.append((i, bi, bi_1, accion, producto_parcial))

    return filas, acumulado


def mostrar_caso_enunciado(a_bin, b_bin):
    """Entregables del caso puntual: bits en C2, tabla de Booth, suma de
    productos parciales y verificacion A*B = -30."""
    a_val = int(val_from_bits(a_bin, W_A, NF_A))
    b_val = int(val_from_bits(b_bin, W_B, NF_B))
    b_raw = int(b_bin, 2)

    filas, acumulado = tabla_booth(a_val, b_raw)

    print("=" * 64)
    print("CASO PARTICULAR DEL ENUNCIADO")
    print("=" * 64)
    print("  A = S(4,0)  valor %+d  bits %s (C2)" % (a_val, a_bin))
    print("  B = S(4,0)  valor %+d  bits %s (C2)" % (b_val, b_bin))
    print("")
    print("  (a) A y B en complemento a 2 (4 bits):")
    print("      A = %+d -> %s" % (a_val, a_bin))
    print("      B = %+d -> %s   (se agrega b(-1) = 0)" % (b_val, b_bin))
    print("")
    print("  (b) Tabla de pasos Booth radix-2:")
    print("      %-4s %-4s %-6s %-6s %-10s" % ("i", "bi", "bi-1", "accion", "producto parcial"))
    for i, bi, bi_1, accion, pp in filas:
        print("      %-4d %-4d %-6d %-6s %+d x 2^%d = %+d" % (i, bi, bi_1, accion, {"+A": 1, "-A": -1, "  0": 0}[accion] * a_val, i - 1, pp))
    print("")
    print("  (c) Suma de productos parciales:")
    terminos = " + ".join("(%+d)" % pp for _, _, _, _, pp in filas)
    print("      %s = %+d" % (terminos, acumulado))
    print("")
    print("  (d) Verificacion:")
    print("      A x B = %+d x %+d = %+d" % (a_val, b_val, a_val * b_val))
    assert acumulado == a_val * b_val == -30, "el acumulado no coincide con A*B=-30!"
    print("      Booth radix-2 coincide con A*B: OK (-30)")
    print("=" * 64)
    print("")


def expected_fxp(a_raw, b_raw):
    """Esperado con el modelo golden (fxpmath) para un par de bits RAW."""
    Ax = Fxp(sig(a_raw, W_A), signed=True, n_word=W_A, n_frac=NF_A)
    Bx = Fxp(sig(b_raw, W_B), signed=True, n_word=W_B, n_frac=NF_B)
    Px = Fxp(
        Ax.get_val() * Bx.get_val(),
        signed=True,
        n_word=NB,
        n_frac=NBF,
        rounding="trunc",
        overflow="wrap",
    )
    return int(Px.bin(), 2)


def generar_vectores(a_bin, b_bin):
    a_raw0, b_raw0 = int(a_bin, 2), int(b_bin, 2)
    vecs = []

    def push(a_raw, b_raw):
        exp_raw = expected_fxp(a_raw, b_raw)
        # cross-check con aritmetica binaria C2 (calculo "a mano" del esperado)
        exp_c2 = (sig(a_raw, W_A) * sig(b_raw, W_B)) & ((1 << NB) - 1)
        assert exp_raw == exp_c2, "fxpmath != C2  (a=%d, b=%d)" % (a_raw, b_raw)
        vecs.append((a_raw, b_raw, exp_raw))

    # vector 0: el caso del enunciado (A=+6, B=-5)
    push(a_raw0, b_raw0)

    n_vec = os.environ.get("N_VECTORS")
    if n_vec:
        n_vec = int(n_vec)
        random.seed(2026)
        for _ in range(n_vec):
            push(random.randrange(1 << W_A), random.randrange(1 << W_B))
    else:
        # Cobertura exhaustiva total: 16 x 16 = 256 casos
        n_vec = (1 << W_A) * (1 << W_B)
        for a_raw in range(1 << W_A):
            for b_raw in range(1 << W_B):
                if a_raw == a_raw0 and b_raw == b_raw0:
                    continue  # ya incluido como vector 0
                push(a_raw, b_raw)

    n = len(vecs)
    with open("a.hex", "w") as fa, open("b.hex", "w") as fb, open(
        "expected.hex", "w"
    ) as fs:
        for a_raw, b_raw, s_raw in vecs:
            fa.write(to_hex(a_raw, W_A) + "\n")
            fb.write(to_hex(b_raw, W_B) + "\n")
            fs.write(to_hex(s_raw, NB) + "\n")
    with open("nv.txt", "w") as fn:
        fn.write(to_hex(n, 32) + "\n")  # cantidad de vectores (n)

    print("Vectores generados -> %d en a.hex / b.hex / expected.hex" % n)
    print("Cross-check fxpmath vs C2: OK (%d/%d)" % (n, n))
    print("")


if __name__ == "__main__":
    A_BIN, B_BIN = "0110", "1011"  # A=+6, B=-5
    mostrar_caso_enunciado(A_BIN, B_BIN)
    generar_vectores(A_BIN, B_BIN)