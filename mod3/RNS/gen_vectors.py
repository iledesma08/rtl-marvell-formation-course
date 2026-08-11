# gen_vectors.py — Modelo golden para la multiplicacion modular en RNS
# (Residue Number System) con modulos {3, 5, 7} (Ejercicio 6).
#
# 1. Analiza el caso puntual del enunciado: X=14, Y=6.
#    Muestra los residuos de cada operando, el producto modular residuo a
#    residuo (operado en paralelo) y la recomposicion decimal del resultado.
# 2. Genera los archivos x.hex / y.hex / c3.hex / c5.hex / c7.hex / z.hex
#    (mas nv.txt con la cantidad de vectores) que consume el testbench
#    self-checking en SystemVerilog.
# 3. Cross-check: compara el modelo fxpmath contra la aritmetica entera
#    ((X*Y) mod M) y contra la recomposicion CRT.
import os
import random

from fxpmath import Fxp

# ---------------------------------------------------------------------------
# Datos del enunciado
# ---------------------------------------------------------------------------
MODS = (3, 5, 7)  # modulos del sistema RNS
M = 1
for m in MODS:
    M *= m  # M = 105 (valores representables: [0, M-1])
W = M.bit_length()  # W = 7 bits para los valores [0, 104]
W_CH = [(m - 1).bit_length() for m in MODS]  # bits por canal: 2, 3, 3


def crt_coeffs():
    """Coeficientes de recomposicion CRT: C_i = M_i * inv(M_i mod m_i, m_i)."""
    cs = []
    for mi in MODS:
        Mi = M // mi  # M_i = M / m_i
        Mi_mod = Mi % mi  # M_i mod m_i
        inv = next(
            k for k in range(mi) if (Mi_mod * k) % mi == 1  # inv(M_i mod m_i, m_i)
        )
        cs.append(Mi * inv)  # C_i = M_i * inv(M_i mod m_i, m_i)
    return cs


CRT = crt_coeffs()  # (70, 21, 15) para {3, 5, 7}

# to_hex es el "codificador" inverso para escribir los .hex


def to_hex(value, nbits):
    """Patron binario -> hex sin signo de nbits con ancho fijo."""
    return format(value & ((1 << nbits) - 1), "0%dx" % ((nbits + 3) // 4))


# residuos y recomponer son el "descodificador" del sistema RNS


def residuos(x):
    """Residuos de x en cada modulo del sistema (tupla por canal)."""
    return tuple(
        x % m
        for m in MODS  # residuos de x en cada modulo del sistema (tupla por canal)
    )


def recomponer(r):
    """Recompone el resultado decimal a partir de los residuos (CRT)."""
    return sum(ri * ci for ri, ci in zip(r, CRT)) % M  # recomposicion CRT del resultado


def mostrar_caso_enunciado(x_val, y_val):
    """Entregables del caso puntual: residuos, producto modular y recomp."""
    rx = residuos(x_val)
    ry = residuos(y_val)
    c = tuple((a * b) % m for a, b, m in zip(rx, ry, MODS))  # paralelo
    z = recomponer(c)

    print("=" * 64)
    print("CASO PARTICULAR DEL ENUNCIADO - X=%d, Y=%d" % (x_val, y_val))
    print("=" * 64)
    print("  Modulos: {%d, %d, %d}   M = %d" % (MODS[0], MODS[1], MODS[2], M))
    print("")
    print("  (a) Representacion RNS:")
    print("      X = %2d -> (%2d, %2d, %2d)" % (x_val, rx[0], rx[1], rx[2]))
    print("      Y = %2d -> (%2d, %2d, %2d)" % (y_val, ry[0], ry[1], ry[2]))
    print("")
    print("  (b) Producto modular residuo a residuo (en paralelo):")
    for i, (a, b, mi) in enumerate(zip(rx, ry, MODS)):
        print("      c%d = (%2d * %2d) mod %d = %2d" % (i, a, b, mi, c[i]))
    print("")
    print("  (c) Recomposicion decimal (CRT, C = %s):" % (CRT,))
    print("      Z = sum(c_i * C_i) mod %d" % M)
    print(
        "        = (%d*%d + %d*%d + %d*%d) mod %d"
        % (c[0], CRT[0], c[1], CRT[1], c[2], CRT[2], M)
    )
    print("        = %d" % (c[0] * CRT[0] + c[1] * CRT[1] + c[2] * CRT[2]))
    print("        = %d (mod %d)" % (z, M))
    print("")
    print("  Verificacion:")
    print(
        "      %d * %d = %d   ->   %d mod %d = %d = (residuos)"
        % (x_val, y_val, x_val * y_val, x_val * y_val, M, x_val * y_val % M)
    )
    print(
        "      como %d < %d, la recomposicion por inspeccion coincide con"
        % (x_val * y_val, M)
    )
    print("      la recomposicion CRT:  Z = %d" % z)
    print("=" * 64)
    print("")


def expected_fxp(x_raw, y_raw):
    """Esperados con el modelo golden (fxpmath) para X, Y en [0, M-1]."""
    Xx = Fxp(x_raw, signed=False, n_word=W)
    Yy = Fxp(y_raw, signed=False, n_word=W)
    # Producto completo exacto (cabe en 2*W bits): 104*104 < 2^14
    Px = Fxp(Xx.get_val() * Yy.get_val(), signed=False, n_word=2 * W)
    pv = int(Px.get_val())

    c = tuple(pv % m for m in MODS)  # residuo a residuo del producto
    z = pv % M  # producto modulo M (recomposicion)
    return c, z


def generar_vectores(x_val, y_val):
    vecs = []

    def push(x_raw, y_raw):
        c, z = expected_fxp(x_raw, y_raw)
        # cross-check de 3 rutas independientes:
        c_par = tuple((x_raw % m) * (y_raw % m) % m for m in MODS)
        z_int = (x_raw * y_raw) % M
        z_crt = recomponer(c_par)
        assert c == c_par, "fxpmath != paralelo (x=%d, y=%d)" % (x_raw, y_raw)
        assert z == z_int, "fxpmath != entero   (x=%d, y=%d)" % (x_raw, y_raw)
        assert z_crt == z_int, "CRT != entero     (x=%d, y=%d)" % (x_raw, y_raw)
        vecs.append((x_raw, y_raw, c, z))

    # vector 0: el caso del enunciado (X=14, Y=6)
    push(x_val, y_val)

    n_vec = os.environ.get("N_VECTORS")
    if n_vec:
        n_vec = int(n_vec)
        random.seed(2026)
        for _ in range(n_vec):
            push(random.randrange(M), random.randrange(M))
    else:
        # Cobertura exhaustiva total: los 105 x 105 pares (X, Y) en [0, M-1]
        n_vec = M * M
        for x_raw in range(M):
            for y_raw in range(M):
                if x_raw == x_val and y_raw == y_val:
                    continue  # ya incluido como vector 0
                push(x_raw, y_raw)

    n = len(vecs)
    with open("x.hex", "w") as fx, open("y.hex", "w") as fy, open(
        "c3.hex", "w"
    ) as fc3, open("c5.hex", "w") as fc5, open("c7.hex", "w") as fc7, open(
        "z.hex", "w"
    ) as fz:
        for x_raw, y_raw, c, z in vecs:
            fx.write(to_hex(x_raw, W) + "\n")
            fy.write(to_hex(y_raw, W) + "\n")
            fc3.write(to_hex(c[0], W_CH[0]) + "\n")
            fc5.write(to_hex(c[1], W_CH[1]) + "\n")
            fc7.write(to_hex(c[2], W_CH[2]) + "\n")
            fz.write(to_hex(z, W) + "\n")
    with open("nv.txt", "w") as fn:
        fn.write(to_hex(n, 32) + "\n")  # cantidad de vectores generados

    print(
        "Vectores generados -> %d en x.hex / y.hex / c3.hex / c5.hex / c7.hex / z.hex"
        % n
    )
    print("Cross-check fxpmath vs paralelo vs entero vs CRT: OK (%d/%d)" % (n, n))
    print("")


if __name__ == "__main__":
    X, Y = 14, 6  # caso del enunciado
    mostrar_caso_enunciado(X, Y)
    generar_vectores(X, Y)
