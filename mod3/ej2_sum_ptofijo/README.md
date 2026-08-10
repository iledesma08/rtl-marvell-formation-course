# Ejercicio 2 — Suma en punto fijo

## De qué va esto

En este ejercicio sumamos dos señales signadas en punto fijo que vienen con formatos distintos:

- **A** = `110010` en **S(6, 4)** → valor **−0,875**
- **B** = `00011110` en **S(8, 5)** → valor **+0,9375**

El objetivo es (a) determinar el formato de la suma `A + B` aplicando las reglas
`NBF_out = max` y `NBI_out = max + 1`, (b) alinear los bits a la coma y sumar en
complemento a 2, y (c) verificar el resultado en decimal.

> Nota: la consigna escrita dice "A = −1,75", pero ese valor no se corresponde con
> sus propios bits `110010`. En S(6, 4) ese patrón vale −0,875 (es exactamente el
> ejemplo que usa el tutorial de la libreria fxpmath). Resolvimos usando los **bits como fuente
> de verdad**: `110010` → −0,875. Si quisiéramos forzar el valor −1,75, los bits
> correctos serían `100100`.

---

## (a) Formato del resultado

Para armar el formato de salida contamos primero los bits enteros (incluyendo el signo):

| Señal | Formato | NBF | NBI = NB − NBF |
|---|---|---|---|
| A | S(6, 4) | 4 | 2 |
| B | S(8, 5) | 5 | 3 |

Aplicamos las reglas:

- **NBF_out = max(4, 5) = 5**
- **NBI_out = max(2, 3) + 1 = 4**

Entonces **`S = S(NB_out, NBF_out) = S(9, 5)`**. El bit extra en NBI nos da un bit de
signo de sobra, así que sumar dos operandos dentro de su rango nunca desborda.

---

## (b) Bits alineados y suma en complemento a 2

Para sumar hay que llevar ambos operandos a `S(9, 5)`. Lo hacemos rellenando con
ceros hacia la derecha (para que ambos tengan 5 bits fraccionarios) y extendiendo el
signo hacia la izquierda (para llegar a 9 bits):

```
A = 110010        →  alinear a S(9,5)  →  111100100
B = 00011110      →  alinear a S(9,5)  →  000011110
```

Sumamos bit a bit en complemento a 2:

```
   111100100   (A alineado, −0,875)
 + 000011110   (B alineado, +0,9375)
 ----------
  1000000010   (carry = 1 → se descarta, queda representado igual en C2)
   000000010   (resultado S(9,5))
```

Y verificamos: `000000010` en S(9, 5) = `+2 · 2⁻⁵ = +0,0625`.

---

## (c) Verificación decimal

```
A + B = −0,875 + 0,9375 = +0,0625
```

El resultado decimal coincide con la suma binaria: obtuvimos `000000010` → `0,0625`.

---

## Cómo lo implementamos

Seguimos el flujo del tutorial: un **modelo golden** en Python calcula los valores
esperados, y un **testbench self-checking** en SystemVerilog valida el hardware
contra ese modelo.

| Archivo | Rol |
|---|---|
| `gen_vectors.py` | Modelo golden con `fxpmath`: muestra el análisis del caso puntual y genera `a.hex`, `b.hex`, `expected.hex` y `nv.txt`. |
| `sum_ptofijo.sv` | DUT: sumador en punto fijo parametrizado (extiende signo y alinea NBF). |
| `tb_sum_ptofijo.sv` | Testbench que lee los `.hex`, aplica cada vector al DUT y compara contra el esperado. |
| `run.sh` | Automatiza generacion → compilacion → simulacion. |

### El DUT

`sum_ptofijo.sv` es un sumador **parametrizado** por los formatos de entrada. Dado
`A` en `S(W_A, NBFA)` y `B` en `S(W_B, NBFB)`, calcula `NB`, `NBI` y `NBF` según las
reglas del enunciado, alinea ambos operandos y suma:

```systemverilog
assign a_ext = { {(NBI - NBIA){a[W_A-1]}}, a, {(NBF - NBFA){1'b0}} };
assign b_ext = { {(NBI - NBIB){b[W_B-1]}}, b, {(NBF - NBFB){1'b0}} };
assign sum   = a_ext + b_ext;
```

### El modelo golden

`gen_vectors.py` no solo resuelve el caso del enunciado sino que además genera la
**cobertura de todo el espacio de entrada** (64 valores de A × 256 de B = 16384
vectores). Para cada par calcula el esperado con `fxpmath` y aparte hace un
*cross-check* contra la aritmética binaria en complemento a 2, asegurando que el
modelo referencial y la cuenta a mano coinciden.

---

## Cómo correrlo

```bash
./run.sh                      # cobertura exhaustiva (16 384 vectores)
N_VECTORS=1000 ./run.sh       # muestreo aleatorio (modo rápido)
```

Salida esperada (al final de la simulación):

```
RESULTADO: PASS  (16384/16384 vectores OK)
```

La forma de onda queda en `tb_sum_ptofijo.vcd`.

---

## Conclusiones

- Practicamos el **alineado a la coma**: extender NBF con ceros y extender el signo
  hacia la izquierda antes de sumar.
- Vimos por qué `NBI_out = max + 1` elimina el desbordamiento por diseño: el carry
  de salida, si aparece, se descarta sin perder información.
- Cerramos el circuito completo **Python golden → RTL → testbench automático**, con
  verificación cruzada y cobertura total del espacio de estados.
  