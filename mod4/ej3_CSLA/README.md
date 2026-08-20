# Ejercicio 3 — Carry Select Adder por bloques de 4 bits

## De qué va esto

En el ejercicio 1 vimos que el RCA paga caro el *ripple* del carry: para 16
bits son 16 saltos de compuerta y el delay crece con `N`. Después, en el
ejercicio 2, el CLA atacó ese cuello de botella calculando todos los carries
en paralelo con lookahead. Acá exploramos una tercera estrategia, la del
**Carry Select Adder (CSLA)**, que es otra forma de "no esperar al carry".

Ahora en vez de esperar a saber el carry que
viene del bloque anterior, **especulamos**. Por cada bloque calculamos la suma
dos veces EN PARALELO — una suponiendo que el carry de entrada es `0` y otra
suponiendo que es `1` — y cuando por fin llega el carry real, un mux 2:1 elige
cuál de las dos respuestas era la correcta. Como las dos sumas se resuelven al
mismo tiempo y en paralelo, la única espera es la del mux.

El diseño sigue al pie de la consigna: **16 bits en 4 bloques de 4**, con
`rca4` como bloque interno y muxes 2:1 entre bloques.

## Los módulos

### `rca4.sv` — la célula de 4 bits

Es el RCA de 4 bits estructural que ya conocemos del ejercicio 1, pero fijo a
4 bits: encadena 4 `full_adder` (reutilizamos `full_adder.sv` del ej. 1, con
sus mismas compuertas y delays `xor = 2 ns`, `and = or = 1 ns`). Lo armamos
como módulo aparte porque es la **célula que el CSLA duplica**: por cada bloque
se instancian dos copias idénticas, una con `cin = 0` y otra con `cin = 1`.

Un dato importante: el delay de este bloque es **corto y constante**
sin importar cuántos bloques haya. Pagar 4 bits de ripple es barato; el
problema era pagar 16.

### `csla16.sv` — la estructura selectiva

Dentro del `csla16` conectamos los 4 bloques:

- **Bloque 0**: un solo `rca4` con el carry-in externo `cin`. No lleva mux
  porque su carry de entrada ya se conoce de antemano (es `cin`), así que no
  tiene sentido especular sobre él.
- **Bloques 1 a 3**: dos `rca4` en paralelo (uno con `cin = 0`, otro con
  `cin = 1`) + un mux 2:1 de 4 bits para la suma y un mux 2:1 de 1 bit para el
  carry, ambos controlados por el carry-out del bloque anterior.

```systemverilog
genvar i;
generate
  for (i = 1; i < 4; i = i + 1) begin : sel_blocks
    rca4 u_rca0 ( .a (a[i*4 +: 4]), .b (b[i*4 +: 4]), .cin (1'b0),
                  .sum (sum0[i]), .cout (cout0[i]) );
    rca4 u_rca1 ( .a (a[i*4 +: 4]), .b (b[i*4 +: 4]), .cin (1'b1),
                  .sum (sum1[i]), .cout (cout1[i]) );
    // muxes 2:1 por bit de la suma + mux del carry
    ...
  end
endgenerate
```

El mux 2:1 lo armamos **estructural**, con `not/and/or` primitivas y delays de
1 ns (`y = (d0 & ~sel) | (d1 & sel)`), porque si lo escribíamos con un
operador ternario no tendría delay y no habría nada que medir. Le ponemos 4
compuertas por bit de mux: el camino `sel -> y` suma ~3 ns.

> Una decisión de diseño que vale aclarar: **el bloque 0 no especula**. La
consigna dice que "cada bloque" tenga los dos sumadores y el mux, pero el
bloque 0 no tiene bloque anterior que lo gobierne, y su carry de entrada ya es
conocido. Meterle los dos sumadores + mux sería desperdiciar área sin ganar
nada de delay. Por eso lo dejamos como un RCA simple, que es la implementación
clásica del CSLA.

## La verificación

El `tb_csla.sv` es **self-checking** y sigue el estilo de los ejercicios 1 y 2:

1. **`rca4` exhaustivo**: las 512 combinaciones de `(a, b) × cin` chequeadas
   contra `a + b + cin` en 5 bits. Con 4 bits es barato probarlo todo.
2. **`csla16` bordes**: `0 + 0`, `max + max` (carry-out = 1), `max + 0` con
   `cin = 1` y `max + 1`.
3. **`csla16` con 1000 vectores random** contra `a + b + cin` en 17 bits.
4. **Cross-check contra el RCA16 (ej. 1) y el CLA16 (ej. 2)**: con la misma
   estimulación, los tres sumadores tienen que dar exactamente la misma
   salida. Tres implementaciones correctas de la misma operación no pueden
   discrepar; si una difiere, hay un bug en alguna.

Como los DUTs son estructurales y tienen gate delays, después de cada vector
esperamos a que estabilicen las salidas (lo más lento es el RCA16, ~32 ns).

## El delay y el path crítico

Para el peor caso usamos el clásico: partimos de `0 + 0` y aplicamos
`a = max`, `b = 1`, `cin = 0`. El bit 0 genera carry y tiene que llegar hasta
el final. Medimos por separado `cout` y `sum[15]` en las tres arquitecturas,
con monitores dedicados y el mismo modelo de compuertas:

| Arquitectura | delay `cout` [ns] | delay `sum[15]` [ns] | gates |
|--------------|-------------------|----------------------|-------|
| **CSLA16**   | 16                | 17                   | 200   |
| **CLA16**    | 17                | 19                   | 140   |
| **RCA16**    | 32                | 32                   | 80    |

El CSLA16 gana por muy poco:

- En el **RCA**, el carry atraviesa 16 etapas de `and + or` (~2 ns c/u):
  16 × 2 = 32 ns. Crecimiento lineal con `N`.
- En el **CLA**, el carry atraviesa 4 fronteras de bloque con lookahead
  interno: 17 ns en `cout`. Crecimiento con la cantidad de bloques.
- En el **CSLA**, el camino crítico es: ripple del bloque 0 (~8-10 ns) +
  3 muxes de bloque (~3 ns c/u) = ~16-17 ns. La clave es que **el carry ya no
  se propaga por los 16 bits**: los bloques 1 a 3 calculan su resultado en
  paralelo mientras el carry viene, y el mux solo "elige" al final.

### ¿Y si el CLA tuviera lookahead de 2º nivel?

Un matiz importante sobre los 17/19 ns del CLA16: ese número corresponde a la
**versión que pide la consigna** — bloques `cla4` encadenados por carry, con
lookahead solo *adentro* de cada bloque. Es un CLA jerárquico de **un solo
nivel**.

Existe la variante "ideal" con **Lookahead Carry Generator (LCG) de 2º nivel**:
cada bloque, además de su suma, entrega el generate/propagate de bloque
(`G_blk`, `P_blk`), y un LCG global calcula todos los carries entre bloques en
paralelo directamente desde `cin` (por ejemplo `c_blk2 = G1 | P1·G0 |
P1·P0·cin`). Así el carry deja de saltar de bloque en bloque en serie: los
bloques no esperan al carry del anterior, lo calculan todos a la vez.

Con el lookahead de 2º nivel, el CLA16 **pasaria a ganarle de forma considerable
al CSLA16 también en delay**.

## Área: el costo de especular

Nada es gratis. El conteo estructural de compuertas en
`tb_csla.sv` parte del costo de cada célula — 5 gates el `full_adder`, 4 el
`mux2`, 35 el `cla4` — y se aplican las fórmulas estructurales de cada
arquitectura:

- **RCA16**: 16 full adders × 5 gates = **80 gates**.
- **CLA16**: 4 bloques × 35 gates (g/p + prefijos + lookahead + xor de suma)
  = **140 gates**.
- **CSLA16**: bloque 0 (20) + 3 bloques × (2 rca4 = 40 + 5 mux2 = 20) =
  **200 gates**.

El CSLA es el más caro de los tres: **duplicamos los sumadores** en los
bloques 1 a 3 y además pagamos los muxes. A cambio de ese ~43 % de área extra
sobre el CLA (200 vs 140 gates), recortamos el delay **apenas 1-2 ns** (16/17
vs 17/19). El RCA, con 80 gates, es el más chico pero el más lento por lejos.

Esa asimetría es el punto clave del ejercicio: **60 gates extra por 1-2 ns**.
Con la versión de la consigna, la diferencia de tiempo entre CSLA y CLA es
mínima, pero la de área es enorme. El intercambio solo se justifica cuando el
tiempo de ciclo es el recurso crítico y el área sobra — o cuando la regularidad
del CSLA rinde en silicio real. Y vale recordarlo: el

CLA de 2º nivel del apartado anterior iguala el área del CSLA (~200 gates) y
encima le gana en delay, lo que deja al CSLA sin argumentos de velocidad.

## Recomendación de arquitectura

Con todo lo anterior, "¿cuál es la mejor?" se responde por escenario:

| Escenario | Qué conviene | Por qué |
|-----------|--------------|---------|
| El área o el consumo importan | **CLA16** | 140 gates vs 200 del CSLA (~30 % menos) y, en la versión de la consigna, solo 1-2 ns más lento. El mejor balance. |
| `F_max` alto con el diseño de la consigna | **CSLA16** | gana 1-2 ns con estructura regular y bajo fan-out. |
| `F_max` alto y se puede invertir en arquitectura | **CLA16 con LCG de 2º nivel** | Le gana al CSLA en delay con área similar (~200 gates). |
| Anchos grandes (32, 64, ...) | **CLA jerárquico (2 niveles)** | su delay crece con `log(N)`; el CSLA crece con la cantidad de bloques (los muxes van en serie). |
| Anchos chicos (4-8 bits) | **RCA** | 80 gates y 8-16 ns alcanzan de sobra; no se justifica nada más. |

Dos matices que explican *por qué* el CLA suele preferirse al CSLA:

- **El CLA es "mejorable" y el CSLA no.** El CLA de la consigna se convierte
  en el CLA de 2º nivel agregando un LCG global, sin cambiar su esencia, y pasa
  a ganar en delay. El CSLA, en cambio, para bajar el delay tiene que pagar más
  muxes en serie (o bloques más chicos): más área, y su orden de crecimiento no
  cambia. Si el ancho crece, el CLA escala con `log(N)` y el CSLA con la
  cantidad de bloques.
- **La estructura del CSLA le da una ventaja que la simulación no ve.** Todo
  esto es con un modelo pedagógico de compuertas de 2 entradas. En silicio
  real, el CSLA tiene conexiones locales y poco fan-out (cada bloque solo mira
  su dato y un carry), mientras que el lookahead del CLA distribuye `g`/`p`
  hacia muchos árboles (fan-out alto) y complica el enrutamiento y el timing.
  Por eso en síntesis, para anchos medios y `F_max` alto, el CSLA sigue siendo
  competitivo a pesar de que en esta tabla de simulación apenas empata.

> Si el área es un problema → **CLA16**; 
> si el delay es lo único que importa y se puede invertir en arquitectura → **CLA16 de 2º nivel**; 
> si querés un diseño simple, regular y de bajo fan-out para correr a alta frecuencia → **CSLA16**. 
> Para anchos chicos → **RCA**.

## Cómo correrlo

```bash
./run.sh
```

El script compila `csla16.sv + rca4.sv` junto con las referencias de los
ejercicios 1 y 2 (RCA16 y CLA16 para el cross-check y la tabla comparativa) y
corre el testbench.

Salida esperada (al final de la verificación):

```
RESULTADO: PASS  (rca4 exhaustivo, bordes, 1000 random y delay OK)
```

Las formas de onda quedan en `tb_csla.vcd`

## Las conclusiones

- El CSLA elimina el ripple inter-bloque **especulando**: calcula la suma dos
  veces en paralelo y un mux elige cuando llega el carry real.
- Con la versión de la consigna, la diferencia de delay entre CSLA16 (16/17 ns)
  y CLA16 (17/19 ns) es mínima, y ambos le ganan al RCA16 (32/32 ns) por
  lejos: el carry solo ve 4 bits de ripple + muxes, no 16 etapas.
- La diferencia real está en el **área**: 200 gates el CSLA vs 140 el CLA
  (~43 % extra por apenas 1-2 ns). Y si se pudiera usar el CLA con LCG de
  2º nivel, el CLA16 le ganaría al CSLA hasta en delay, con área
  similar.
- Para `F_max` alto: el CSLA aporta estructura regular y bajo *fan-out*, que en
  silicio real es una ventaja; pero si el área importa, el CLA es el mejor
  balance, y si se puede invertir en la arquitectura, el CLA de 2º nivel es el
  que gana.
- La verificación exhaustiva del bloque + bordes + 1000 random + cross-check
  contra RCA16 y CLA16 da mucha confianza: si tres sumadores distintos
  coinciden en todo, es muy difícil que haya un bug en alguno.
