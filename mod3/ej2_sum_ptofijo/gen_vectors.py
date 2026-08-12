# gen_vectors.py — Modelo golden para la suma en punto fijo (Ejercicio 2).
#
# 1. Analiza el caso puntual del enunciado: A=S(6,4)=110010, B=S(8,5)=00011110.
#    Muestra los bits alineados a la coma, la suma en C2 y la verificacion decimal.
# 2. Genera los archivos a.hex / b.hex / expected.hex (mas nv.txt con la cantidad
#    de vectores) que consume el testbench en SystemVerilog.
# 3. Cross-check: compara el modelo fxpmath contra la aritmetica binaria en C2.
#
# Reglas del enunciado: NBF_out = max, NBI_out = max + 1.
import os
import random

from fxpmath import Fxp

# ---------------------------------------------------------------------------
# Formatos de entrada
# ---------------------------------------------------------------------------
W_A, NF_A = 6, 4  # A: S(6,4) -> NBI_A = 2 (con signo)
W_B, NF_B = 8, 5  # B: S(8,5) -> NBI_B = 3 (con signo)

# ---------------------------------------------------------------------------
# Formato de salida (reglas del enunciado)
# ---------------------------------------------------------------------------
NBF = max(NF_A, NF_B)  # NBF_out = max -> 5
NBIA, NBIB = W_A - NF_A, W_B - NF_B  # A: 2 / B: 3 bits int.
NBI = max(NBIA, NBIB) + 1  # NBI_out = max + 1 -> 4
NB = NBI + NBF  # NB_out = 9 -> S(9,5)

# val_from_bits y sig son el mismo "descodificador C2" (uno desde string y escalado,
# otro desde int crudo)


def val_from_bits(bits, nbits, n_frac):
    """Valor decimal de un patron binario en complemento a 2.
    Ejemplo: val_from_bits("110010", 6, 4) -> -0.875 (0b110010 = 0x32)."""
    raw = int(bits, 2)  # lee "110010" como entero SIN signo -> 50
    if raw & (1 << (nbits - 1)):  # está el bit de signo en 1? (0b100000 = 32)
        # Este es el truco del C2: un patrón con signo vale lo mismo que su versión
        # sin signo pero corrido 64 posiciones.
        raw -= 1 << nbits  # sí -> resto 2^nbits (2^6 = 64) -> 50 - 64 = -14
    return raw / (1 << n_frac)  # y divido por 2^NBF (2^4 = 16) -> -14/16 = -0.875


def sig(raw, nbits):
    """Entero con signo a partir del patron sin signo de nbits.
    Ejemplo: sig(50, 6) -> -14 (0b110010 = 0x32)."""
    if raw & (1 << (nbits - 1)):
        return raw - (1 << nbits)
    return raw


# to_hex es el "codificador" inverso para escribir los .hex


def to_hex(value, nbits):
    """Patron binario C2 -> hex sin signo de nbits con ancho fijo.
    Ejemplo: to_hex(-14, 6) -> "0x32" (0b110010 = 50)."""
    # hace el enmascarado (wrap-around a 2^nbits)
    # Si el valor ya es positivo dentro del rango no cambia nada;
    # si fuera negativo lo convierte a su representación C2
    wrapped_value = value & ((1 << nbits) - 1)
    return format(wrapped_value, "0%dx" % ((nbits + 3) // 4))


# alinear genera el patrón de 9 bits que el RTL reproduce
# con {{(NBI-NBIA){a[W_A-1]}}, a, {(NBF-NBFA){1'b0}}}


def alinear(bits, n_frac_in, nbi_in):
    """Alinea A/B a S(NB, NBF): agrega ceros hacia la derecha (extiende la
    coma) y extiende el signo hacia la izquierda.
    Ejemplo: alinear("110010", 4, 2) -> "111001000" (S(9,5))."""
    sign = bits[0]  # '1' o '0' (MSB)
    replicate = sign * (NBI - nbi_in)  # extiende el signo a la izquierda
    bits = bits + "0" * (NBF - n_frac_in)  # extiende la coma a la derecha
    return replicate + bits  # bits alineados a la coma


def mostrar_caso_enunciado(a_bin, b_bin):
    """Entregables del caso puntual: alineacion, suma en C2 y verificacion."""
    a_val = val_from_bits(a_bin, W_A, NF_A)
    b_val = val_from_bits(b_bin, W_B, NF_B)

    a_alg = alinear(a_bin, NF_A, NBIA)
    b_alg = alinear(b_bin, NF_B, NBIB)

    suma_full = int(a_alg, 2) + int(b_alg, 2)  # hasta 10 bits
    s_raw = suma_full & ((1 << NB) - 1)  # 9 bits C2
    s_bits = format(s_raw, "0%db" % NB)
    carry = (suma_full >> NB) & 1
    s_val = sig(s_raw, NB) / (1 << NBF)  # resultado decimal

    print("=" * 64)
    print("CASO PARTICULAR DEL ENUNCIADO")
    print("=" * 64)
    print("  A = S(6,4)  valor %+.4f  bits %s" % (a_val, a_bin))
    print("  B = S(8,5)  valor %+.4f  bits %s" % (b_val, b_bin))
    print("")
    print("  (a) Formato del resultado:")
    print("      NBF_out = max(4,5)       = %d" % NBF)
    print("      NBI_out = max(2,3) + 1   = %d   ->   S(%d, %d)" % (NBI, NB, NBF))
    print("")
    print("  (b) Bits alineados a la coma (S(%d,%d)):" % (NB, NBF))
    print("      A ->  %s" % a_alg)
    print("      B ->  %s" % b_alg)
    print("")
    print("      Suma en complemento a 2:")
    print("          %s   (A)" % a_alg)
    print("        + %s   (B)" % b_alg)
    print("        ----------")
    print("          %s   (carry = %d , descartado)" % (s_bits, carry))
    print("")
    print("  (c) Verificacion decimal:")
    print("      %+.4f + %+.4f = %+.4f" % (a_val, b_val, a_val + b_val))
    print("      %s en S(9,5) = %+d x 2^-5 = %+.4f" % (s_bits, sig(s_raw, NB), s_val))
    print("=" * 64)
    print("")


def expected_fxp(a_raw, b_raw):
    """Esperado con el modelo golden (fxpmath) para un par de bits RAW."""
    # La suma se calcula con valores reales (-0.875 + 0.9375), no con raws.
    # Por eso hay que "bajar" del raw al real.
    Ax = Fxp(sig(a_raw, W_A) / (1 << NF_A), signed=True, n_word=W_A, n_frac=NF_A)
    Bx = Fxp(sig(b_raw, W_B) / (1 << NF_B), signed=True, n_word=W_B, n_frac=NF_B)
    Sx = Fxp(
        Ax.get_val() + Bx.get_val(),
        signed=True,
        n_word=NB,
        n_frac=NBF,
        rounding="trunc",
        overflow="wrap",
    )
    return int(Sx.bin(), 2)


def generar_vectores(a_bin, b_bin):
    a_raw0, b_raw0 = int(a_bin, 2), int(b_bin, 2)
    vecs = []

    def push(a_raw, b_raw):
        exp_raw = expected_fxp(a_raw, b_raw)
        # cross-check con aritmetica binaria C2
        # (cálculo "a mano" del esperado en puro C2)
        # Aproxima al hardware, y va en tres etapas: escalar, sumar, enmascarar.
        exp_c2 = (
            (sig(a_raw, W_A) << (NBF - NF_A))
            + (sig(b_raw, W_B) << (NBF - NF_B))
            # sig(a_raw, 6) << (NBF - NF_A)   =  -14 << 1  =  -28   (paso de 2^-4 a 2^-5)
            # sig(b_raw, 8) << (NBF - NF_B)   =   30 << 0  =  +30   (ya estaba en 2^-5, shift 0)
            # -28 + 30 = +2    (resultado exacto, en unidades de 2^-5  →  2/32 = 0.0625)
        ) & (
            (1 << NB) - 1  # enmascarado a 9 bits C2
        )
        assert exp_raw == exp_c2, "fxpmath != C2  (a=%d, b=%d)" % (a_raw, b_raw)
        vecs.append((a_raw, b_raw, exp_raw))

    # vector 0: el caso del enunciado
    push(a_raw0, b_raw0)

    n_vec = os.environ.get("N_VECTORS")
    if n_vec:
        n_vec = int(n_vec)
        random.seed(2026)
        for _ in range(n_vec):
            push(random.randrange(1 << W_A), random.randrange(1 << W_B))
    else:
        # Cobertura exhaustiva total: 64 x 256 = 16384 casos
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
        fn.write(
            to_hex(n, 32) + "\n"
        )  # cantidad de vectores (n) entre el modelo golden y el testbench en SystemVerilog
        # (0x4000 = 16384 vectores para cobertura exhaustiva total, o menos si se pasa N_VECTORS)

    print("Vectores generados -> %d en a.hex / b.hex / expected.hex" % n)
    print("Cross-check fxpmath vs C2: OK (%d/%d)" % (n, n))
    print("")


if __name__ == "__main__":
    A_BIN, B_BIN = "110010", "00011110"
    mostrar_caso_enunciado(A_BIN, B_BIN)
    generar_vectores(A_BIN, B_BIN)
