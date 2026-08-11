# gen_vectors.py — Modelo golden para la multiplicacion por la constante K=23
# en CSD canonico (Ejercicio 4).
#
# 1. Analiza el caso puntual del enunciado: K=23 en binario estandar, su
#    recodificacion a CSD canonico (digitos {-1, 0, +1}, sin no-ceros
#    consecutivos) y las expresiones Y = X*23 con shifts y sumas/restas,
#    comparando la cantidad de sumadores de cada forma.
# 2. Genera los archivos x.hex / expected.hex (mas nv.txt con la cantidad de
#    vectores) que consume el testbench self-checking en SystemVerilog.
# 3. Cross-check: compara el modelo fxpmath contra la aritmetica entera (X*23)
#    y contra la expresion CSD.
import os
import random

from fxpmath import Fxp

# ---------------------------------------------------------------------------
# Datos del enunciado
# ---------------------------------------------------------------------------
K = 23  # constante del multiplicador -> 10111
W_X = 8  # X entero signado en S(8, 0)  rango [-128, 127]
W_Y = W_X + 5  # producto X*K cabe en S(W_X + 5, 0) = S(13,0)
MASK = (1 << W_Y) - 1

# sig es "descodificador C2" desde int crudo


def sig(raw, nbits):
    """Entero con signo a partir del patron sin signo de nbits."""
    if raw & (1 << (nbits - 1)):
        return raw - (1 << nbits)
    return raw


# to_hex es el "codificador" inverso para escribir los .hex


def to_hex(value, nbits):
    """Patron binario C2 -> hex sin signo de nbits con ancho fijo."""
    return format(value & ((1 << nbits) - 1), "0%dx" % ((nbits + 3) // 4))


def csd(n, con_steps=False):
    """Recodifica un entero positivo a CSD canonico (Non-Adjacent Form).
    Devuelve los digitos de LSB(0) a MSB; si con_steps es True devuelve
    ademas el detalle de cada paso (posicion, valor y accion)."""
    d, steps = [], []
    v, i = n, 0
    while v > 0:
        if v & 1:
            if v & 3 == 3:  # corrida de unos -> -1 y propaga +1
                d.append(-1)
                if con_steps:
                    steps.append((i, v, "impar, termina en '11' -> -1, propago +1"))
                v = (v + 1) >> 1
            else:  # uno aislado -> +1
                d.append(1)
                if con_steps:
                    steps.append((i, v, "impar aislado -> +1"))
                v = v >> 1
        else:  # cero -> 0
            d.append(0)
            if con_steps:
                steps.append((i, v, "par -> 0"))
            v = v >> 1
        i += 1
    return (d, steps) if con_steps else d


def mostrar_caso_enunciado():
    """Entregables del caso puntual: K en binario, en CSD y las expresiones Y."""
    k_bin = format(K, "b")
    n_k = sum(int(b) for b in k_bin)  # cantidad de unos (sumandos)
    d_lsb, steps = csd(K, con_steps=True)  # digitos de LSB a MSB
    n_csd = sum(1 for x in d_lsb if x != 0)  # no-ceros (sumandos)
    digs = " ".join("%+d" % x for x in d_lsb[::-1])

    print("=" * 64)
    print("CASO PARTICULAR DEL ENUNCIADO - K = %d" % K)
    print("=" * 64)
    print("  K = %d -> binario estandar: %sb" % (K, k_bin))
    print("")
    print("  (a) K en binario estandar:")
    print("      10111 = 16 + 4 + 2 + 1   (%d unos)" % n_k)
    print("")
    print("  (b) K en CSD canonico (recodificacion NAF, de LSB a MSB):")
    for pos, valor, accion in steps:
        print("      pos %d: %5d  %s" % (pos, valor, accion))
    print("      digitos (de MSB a LSB):  %s" % digs)
    print("      K = (+1)*2^5 + (-1)*2^3 + (-1)*2^0 = +32 - 8 - 1 = %d" % K)
    print(
        "      %d no-ceros, sin pares consecutivos -> representacion canonica" % n_csd
    )
    print("")
    print("  (c) Expresiones Y = X * %d con shifts y +-:" % K)
    print(
        "      binario estandar: Y = (X<<4) + (X<<2) + (X<<1) + X"
        "  (%d sumandos -> %d sumadores)" % (n_k, n_k - 1)
    )
    print(
        "      CSD: Y = (X<<5) - (X<<3) - X"
        "  (%d sumandos -> %d sumadores)" % (n_csd, n_csd - 1)
    )
    print(
        "      ahorro: %d sumador menos con CSD (%.0f%% menos)"
        % (n_k - n_csd, 100.0 * (n_k - n_csd) / n_k)
    )
    print("=" * 64)
    print("")


def expected_fxp(x_raw):
    """Esperado con el modelo golden (fxpmath) para X en S(8,0)."""
    Xx = Fxp(sig(x_raw, W_X), signed=True, n_word=W_X)
    Yx = Fxp(Xx.get_val() * K, signed=True, n_word=W_Y)
    return int(Yx.bin(), 2)


def generar_vectores(x_bin):
    x_raw0 = int(x_bin, 2)
    vecs = []

    def push(x_raw):
        exp_raw = expected_fxp(x_raw)
        # cross-check con aritmetica entera y con la expresion CSD:
        exp_int = (sig(x_raw, W_X) * K) & MASK
        exp_csd = (
            (sig(x_raw, W_X) << 5) - (sig(x_raw, W_X) << 3) - sig(x_raw, W_X)
        ) & MASK
        assert exp_raw == exp_int, "fxpmath != entero (x=%d)" % x_raw
        assert exp_raw == exp_csd, "fxpmath != CSD    (x=%d)" % x_raw
        vecs.append((x_raw, exp_raw))

    # vector 0: el caso ilustrativo (X = +11 -> Y = 253)
    push(x_raw0)

    n_vec = os.environ.get("N_VECTORS")
    if n_vec:
        n_vec = int(n_vec)
        random.seed(2026)
        for _ in range(n_vec):
            push(random.randrange(1 << W_X))
    else:
        # Cobertura exhaustiva total: los 256 valores de X en S(8,0)
        n_vec = 1 << W_X
        for x_raw in range(1 << W_X):
            if x_raw == x_raw0:
                continue  # ya incluido como vector 0
            push(x_raw)

    n = len(vecs)
    with open("x.hex", "w") as fx, open("expected.hex", "w") as fe:
        for x_raw, y_raw in vecs:
            fx.write(to_hex(x_raw, W_X) + "\n")
            fe.write(to_hex(y_raw, W_Y) + "\n")
    with open("nv.txt", "w") as fn:
        fn.write(
            to_hex(n, 32) + "\n"
        )  # cantidad de vectores (n) entre el modelo golden y el testbench en SystemVerilog

    print("Vectores generados -> %d en x.hex / expected.hex" % n)
    print("Cross-check fxpmath vs entero vs CSD: OK (%d/%d)" % (n, n))
    print("")


if __name__ == "__main__":
    X_BIN = "00001011"  # caso ilustrativo: X = +11 -> Y = 253
    mostrar_caso_enunciado()
    generar_vectores(X_BIN)
