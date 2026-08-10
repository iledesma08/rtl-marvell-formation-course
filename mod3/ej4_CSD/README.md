# Ejercicio 4 — CSD — recodificación

## De qué va esto

En este ejercicio multiplicamos una señal `X` por la constante **K = 23**, pero
buscamos que el hardware sea lo más chico posible. La idea central es la
**recodificación CSD** (*Canonical Signed Digit*): representar `K` usando los
dígitos `{-1, 0, +1}` en vez del `{0, 1}` clásico, de forma tal que la cantidad
de sumadores en `Y = X · 23` sea mínima.

Desarrollamos tres cosas:

- **(a)** `K = 23` en binario estándar.
- **(b)** `23` recodificado a CSD canónico (sin no-ceros consecutivos).
- **(c)** La expresión `Y = X · 23` como sumas/restas y shifts, comparando la
  cantidad de sumadores de cada forma.

---

## (a) K en binario estándar

`23` es fácil de partir en potencias de dos:

```
23 = 16 + 4 + 2 + 1 = 10111₂
```

Tiene **cuatro unos**, en las posiciones 4, 2, 1 y 0.

---

## (b) Recodificación CSD canónica

La representación CSD usa dígitos que pueden ser `-1`, `0` o `+1`, con la regla
de que **no pueden quedar dos no-ceros consecutivos**. El truco clásico que nos
da el enunciado es reemplazar el patrón `"0111"` por `"100-1"` (porque
`-1 + 8 = 7`). Aplicándolo a `10111`:

- Los tres unos de la derecha (`...111`) se convierten en un `+1` en la
  posición 3 y un `-1` en la posición 0: `0111 → 100-1`.
- Al quedar `1` y `1` juntos arriba (posiciones 4 y 3), volvemos a aplicar la
  regla sobre ese par y propagamos el acarreo: `11... → 10-1...`.

El resultado es:

```
K = 1  0 -1  0  0 -1   (posiciones 5 .. 0)
   = +32 - 8 - 1
   = 23                ✔
```

Los no-ceros quedan en las posiciones 5, 3 y 0: **ninguno es consecutivo**,
así que la representación es canónica. Pasamos de **4 unos** (binario) a
**3 no-ceros** (CSD).

> 💡 En Python lo implementamos con el algoritmo NAF (*Non-Adjacent Form*):
> se recorre el número de LSB a MSB y cada corrida de unos se cierra con un
> `-1` y un acarreo `+1` hacia la posición siguiente. Es la forma sistemática
> del truco `"0111" → "100-1"`.

---

## (c) Expresión Y = X · 23 y comparación de sumadores

Cada dígito no nulo del multiplicador se convierte en un sumando: el peso lo da
un shift (que en hardware es gratis, son cables) y el signo lo da una suma o una
resta.

| Forma | Expresión | Sumandos | Sumadores |
|---|---|---|---|
| Binario estándar | `Y = (X<<4) + (X<<2) + (X<<1) + X` | 4 | **3** |
| CSD | `Y = (X<<5) - (X<<3) - X` | 3 | **2** |

Con CSD ahorramos **un sumador completo** (pasamos de 3 a 2, un 25 % menos de
las sumas originales) manteniendo el mismo resultado para todo `X`:

```
X<<5 = 32·X
X<<3 = 8·X
Y    = 32·X - 8·X - X = 23·X   ✔
```

---

## Cómo lo implementamos

Seguimos el flujo del tutorial: un **modelo golden** en Python calcula los
valores esperados y un **testbench self-checking** en SystemVerilog valida el
hardware contra ese modelo.

| Archivo | Rol |
|---|---|
| `gen_vectors.py` | Modelo golden con `fxpmath`: resuelve el caso puntual (K en binario, en CSD y las expresiones) y genera `x.hex`, `expected.hex` y `nv.txt`. |
| `mul23.sv` | DUT: multiplicador por 23 con dos salidas, `y_std` (forma binaria) y `y_csd` (forma CSD), para compararlas en el mismo testbench. |
| `tb_mul23.sv` | Testbench que lee los `.hex`, aplica cada `X` al DUT y valida ambas salidas contra el esperado. |
| `run.sh` | Automatiza generación → compilación → simulación. |

### El DUT

`mul23.sv` está parametrizado por el ancho `W_X` de `X`. Como `X` es un entero
signado `S(W_X, 0)` y `23 < 2^5`, el producto siempre cabe en `S(W_X + 5, 0)`.
Primero extendemos el signo de `X` al ancho de salida y después calculamos cada
forma por separado:

```systemverilog
assign x_s  = {{(W_Y - W_X){x[W_X-1]}}, x};               // X en S(W_Y,0)
assign y_std = (x_s <<< 4) + (x_s <<< 2) + (x_s <<< 1) + x_s;
assign y_csd = (x_s <<< 5) - (x_s <<< 3) - x_s;
```

### El modelo golden

`gen_vectors.py` además de resolver el caso puntual genera la **cobertura
exhaustiva de todo el espacio de entrada**: los 256 valores de `X` en `S(8,0)`.
Para cada uno calcula el esperado con `fxpmath` y hace un *cross-check* triple:

- el valor de **fxpmath**,
- la **aritmética entera** `X · 23`,
- la **expresión CSD** `(X<<5) - (X<<3) - X`.

Las tres rutas tienen que dar lo mismo; si no, el script aborta. Así validamos
en el propio modelo que la recodificación es equivalente a multiplicar por 23.

---

## Cómo correrlo

```bash
./run.sh                      # cobertura exhaustiva (256 vectores, default)
N_VECTORS=100 ./run.sh        # muestreo aleatorio (modo rápido)
```

Salida esperada (al final de la simulación):

```
RESULTADO: PASS  (256/256 vectores OK)
```

La forma de onda queda en `tb_mul23.vcd` (`gtkwave tb_mul23.vcd`).

---

## Conclusiones

- Recodificamos `23 = 10111₂` a CSD canónico `10-100-1 = +32 - 8 - 1`, dejando
  los no-ceros en posiciones no consecutivas.
- Bajamos la cantidad de sumadores de **3** (binario) a **2** (CSD) para el
  mismo `Y = X · 23`: los shifts son gratis y las restas salen de los dígitos
  `-1`.
- Cerramos el circuito completo **Python golden → RTL → testbench automático**,
  validando la equivalencia CSD contra fxpmath y contra la aritmética entera,
  con cobertura total del espacio de `X`.
  