# Ejercicio 6 — RNS — multiplicación modular

## De qué va esto

En este ejercicio multiplicamos dos números, **X = 14** e **Y = 6**, pero en vez de
usar la aritmética binaria clásica los representamos en **RNS** (*Residue Number
System*) sobre los módulos **{3, 5, 7}**, con **M = 3 · 5 · 7 = 105**. La idea
central es partir la operación en canales independientes: como 3, 5 y 7 son
coprimos, cada residuo se puede operar **por separado y en paralelo**, sin
propagación de carry entre canales.

Desarrollamos tres cosas:

- **(a)** La representación RNS de `X = 14` e `Y = 6`.
- **(b)** El producto modular residuo a residuo, operado en paralelo.
- **(c)** La recomposición del resultado en decimal, verificando que da `84`.

---

## (a) Representación de X e Y en RNS

Cada número lo representamos como la tupla de residuos frente a los módulos:

```
X mod 3 = 14 mod 3 = 2     →  X = (2, 4, 0)
X mod 5 = 14 mod 5 = 4
X mod 7 = 14 mod 7 = 0

Y mod 3 =  6 mod 3 = 0     →  Y = (0, 1, 6)
Y mod 5 =  6 mod 5 = 1
Y mod 7 =  6 mod 7 = 6
```

> 💡 Como los módulos son coprimos, cada número en `[0, M-1] = [0, 104]` tiene
> una tupla de residuos **única**. Esa es la condición que hace funcionar al RNS:
> las `3 × 5 × 7 = 105` combinaciones posibles de residuos alcanzan para representar
> justo los 105 valores del rango.

---

## (b) Producto modular residuo a residuo (en paralelo)

La gracia del RNS es que la multiplicación se puede hacer canal por canal; cada
canal calcula `cᵢ = (aᵢ · bᵢ) mod mᵢ` **de forma independiente**. En el
enunciado, por ejemplo, el canal de módulo 3 hace `2 · 0 mod 3`, el canal de
módulo 5 hace `4 · 1 mod 5`, etc. Ningún canal necesita saber qué pasa en el otro:

```
c₃ = (2 · 0) mod 3 = 0
c₅ = (4 · 1) mod 5 = 4
c₇ = (0 · 6) mod 7 = 0
```

El producto en RNS queda entonces como la tupla `(0, 4, 0)`. Es la representación
del resultado `84` en el sistema `{3, 5, 7}`.

---

## (c) Recomposición del resultado

Como `X · Y = 84 < 105`, el enunciado nos habilita a recomponer **por
inspección**: alcanza con buscar qué número de `[0, 104]` tiene esos residuos.
`84` tiene residuo `0` frente a 3, `4` frente a 5 y `0` frente a 7, así que
directamente `Z = 84`.

Igual, para que el circuito sea general (y no solo válido cuando el resultado es
menor que `M`) y a modo de curiosidad porque fue nombrado en clase, implementamos la recomposición por **CRT (*Chinese Remainder Theorem* o *Teorema Chino del Resto*)**. Los coeficientes `Cᵢ = (M/mᵢ) · inv((M/mᵢ) mod mᵢ)` son:

```
C₃ = 35 · inv(35 mod 3, 3) = 35 · 2 = 70
C₅ = 21 · inv(21 mod 5, 5) = 21 · 1 = 21
C₇ = 15 · inv(15 mod 7, 7) = 15 · 1 = 15
```

y el número se recupera con:

```
Z = (c₃ · C₃ + c₅ · C₅ + c₇ · C₇) mod M
  = (0·70 + 4·21 + 0·15) mod 105
  = 84                       ✔
```

Verificación completa:

```
X · Y = 14 · 6 = 84   →   Z = (0, 4, 0) en RNS   →   recomposición = 84   ✔
```

---

## Cómo lo implementamos

Seguimos el flujo del tutorial: un **modelo golden** en Python calcula los
valores esperados y un **testbench self-checking** en SystemVerilog valida el
hardware contra ese modelo.

| Archivo | Rol |
|---|---|
| `gen_vectors.py` | Modelo golden con `fxpmath`: resuelve el caso puntual (residuos, producto paralelo y recomposición CRT) y genera `x.hex`, `y.hex`, `c3.hex`, `c5.hex`, `c7.hex`, `z.hex` y `nv.txt`. |
| `rns_mul.sv` | DUT: multiplicador RNS con los tres canales `{3, 5, 7}` y la recomposición CRT. |
| `tb_rns_mul.sv` | Testbench que lee los `.hex`, aplica cada par `X/Y` al DUT y compara los tres residuos y la recomposición contra el esperado. |
| `run.sh` | Automatiza generación → compilación → simulación. |

### El DUT

`rns_mul.sv` hace la cuenta en tres etapas bien separadas:

```systemverilog
// 1) Descomposición: residuos por canal (los buses bin -> RNS de un sistema real)
assign rx3 = x % 3'd3;   assign ry3 = y % 3'd3;
assign rx5 = x % 3'd5;   assign ry5 = y % 3'd5;
assign rx7 = x % 3'd7;   assign ry7 = y % 3'd7;

// 2) Producto modular en paralelo (cada canal es independiente)
assign p3 = rx3 * ry3;   assign c3 = p3 % 3'd3;
assign p5 = rx5 * ry5;   assign c5 = p5 % 3'd5;
assign p7 = rx7 * ry7;   assign c7 = p7 % 3'd7;

// 3) Recomposición por CRT
assign crt_sum = c3 * 70 + c5 * 21 + c7 * 15;
assign z = crt_sum % 105;
```

> Un detalle de diseño: el producto `rx·ry` se calcula en una **net de ancho
> suficiente** antes de aplicar el `mod`. Si lo hiciéramos a 3 bits directo, `4·4` o
> `6·6` se recortarían y el residuo saldría mal; por eso `p₅` y `p₇` llevan 5 y 6
> bits respectivamente.

### El modelo golden

`gen_vectors.py` además de resolver el caso puntual genera la **cobertura
exhaustiva de todo el espacio de entrada**: los 105 valores de `X` por los 105
valores de `Y` (11 025 pares sobre `[0, 104]`). Para cada par calcula el esperado
con `fxpmath` (que hace el producto completo `X·Y` y después reduce) y aparte hace
un *cross-check* de tres rutas independientes:

- el **cálculo residuo a residuo** (el mismo que ejecuta el hardware),
- la **aritmética entera** `(X·Y) mod M`,
- la **recomposición CRT**.

Las tres rutas tienen que dar lo mismo; si no, el script aborta con un `assert`.
Así validamos en el propio modelo que la cuenta paralela por canales es equivalente
a multiplicar y reducir en binario clásico.

---

## Cómo correrlo

```bash
./run.sh                      # cobertura exhaustiva (11 025 vectores, default)
N_VECTORS=300 ./run.sh        # muestreo aleatorio (modo rápido)
```

Salida esperada (al final de la simulación):

```
RESULTADO: PASS  (11025/11025 vectores OK)
```

La forma de onda queda en `tb_rns_mul.vcd`.

---

## Conclusiones

- Vimos cómo el RNS parte la multiplicación en **canales independientes**: cada
  canal reduce el resultado de inmediato, sin esperar carry de ningún vecino.
- Comprobamos que `(X mod mᵢ) · (Y mod mᵢ) mod mᵢ = (X·Y) mod mᵢ`, es decir que
  reducir después de multiplicar o multiplicar residuos ya reducidos da lo mismo.
- Implementamos la recomposición con **CRT**, que fue nombrado en clase y que
  permite usar un RNS real no solo para cuentas "chicas" sino para cualquier valor
  del rango `[0, M-1]`.
- Cerramos el circuito completo **Python golden → RTL → testbench automático**,
  validando el hardware contra fxpmath, la aritmética entera y el CRT, con
  cobertura total del espacio de `(X, Y)`.
