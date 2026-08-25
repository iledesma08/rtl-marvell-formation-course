# Ejercicio 2 — CLA 4-bit → 16-bit jerárquico

## De qué va esto

En el ejercicio 1 vimos que el RCA es simple pero paga un precio: el carry
"riplea" bit a bit y eso hace que el delay crezca linealmente con `N`. Acá
atacamos justamente ese cuello de botella. La idea del **Carry Lookahead
Adder (CLA)** es no esperar a que el carry venga de la etapa anterior, sino
**calcular los carries en paralelo** a partir de los operandos.

Para eso cada bit se describe con dos señales:

```
g[i] = a[i] & b[i]          // genera carry con seguridad
p[i] = a[i] ^ b[i]          // propaga el carry de entrada
c[i + 1] = g[i] | (p[i] & c[i])
```

`g` dice "este bit siempre genera carry" y `p` dice "este bit deja pasar el
carry que venga". Con eso el carry del bit `i+1` depende solo de `g`, `p` y
`cin`, y no de la cadena entera de carries anteriores. Esa recurrencia se
**expande** en forma de lookahead para que todos los carries se resuelvan con
un árbol de compuertas de poca profundidad.

El plan es el clásico: primero armamos el bloque de 4 bits (`cla4`) y después
lo encadenamos en grupos de 4 para obtener el CLA jerárquico de 16 bits
(`cla16`). Implementamos **dos versiones** en carpetas separadas:

- **`v1/`** — un nivel de lookahead: los carries entre bloques de 4 bits
  "saltan" de bloque en bloque, encadenando `cout` de cada `cla4` con el `cin`
  del siguiente (el "lookahead inter-bloque por carry" de la consigna).
- **`v2/`** — dos niveles de lookahead: cada bloque además produce su `G` y su
  `P` de bloque, y los carries entre bloques se calculan **en paralelo** con un
  segundo nivel de lookahead. Es la mejora que la discusión de `v1` planteaba
  como hipotética; acá está implementada y medida.

## La estructura

```
ej2_CLA/
├── README.md
├── tb_cla.sv            ← testbench que testea y COMPARA v1 vs v2 vs RCA16
├── run.sh               ← compila v1 + v2 + RCA + tb y corre la verificación
├── v1/                 ← versión de un nivel (la que pedía la consigna)
│   ├── cla4.sv             (module cla4)
│   └── cla16.sv            (module cla16)
└── v2/                 ← versión de dos niveles (mejora)
    ├── cla4.sv             (module cla4_v2: agrega G/P de bloque)
    └── cla16.sv            (module cla16_v2: lookahead inter-bloque)
```

## Los módulos

### `v1/cla4.sv` — el bloque de 4 bits

Se construyó **100% estructural**, con compuertas primitivas de 2 entradas y
los mismos delays del ejercicio 1 (`xor = 2 ns`, `and = or = 1 ns`)
para que la comparación de delay contra el RCA sea justa: mismo modelo de
compuertas, distinta topología.

Por cada bit se calculan `g[i]` y `p[i]`, y después se arma el lookahead. La
recurrencia `c[i+1] = g[i] | (p[i] & c[i])` se expande en términos de solo
`g`, `p` y `cin`, por ejemplo:

```
c[2] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & cin)
c[3] = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0]) | (p[2] & p[1] & p[0] & cin)
```

Para que el árbol sea eficiente compartimos los **prefijos de producto**
`pp1 = p1&p0`, `pp2 = p2&p1&p0` y `pp3 = p3&p2&p1&p0`, que se reutilizan en
varios carries (así no duplicamos lógica). Cada carry se resuelve con un
pequeño árbol de `and`/`or` de 2 entradas, y los sumas salen de
`sum[i] = p[i] ^ c[i]`.

> Los términos de producto también se reutilizan entre
carries (`c[3]` usa el término de `c[2]` con un `and` más), así que el bloque
queda compacto y la profundidad del árbol crece poco.

### `v1/cla16.sv` — el CLA jerárquico de un nivel

Encadena cuatro bloques `cla4` con un `generate-for`. El carry-out de cada
bloque es el carry-in del siguiente:

```
cblk[0] = cin
cblk[i + 1] = carry-out del bloque i   ->   carry-in del bloque i + 1
```

Adentro de cada bloque los carries se resuelven en paralelo, y entre bloques el
carry "salta" en un solo paso en vez de propagarse bit a bit. Cada bloque se
conecta con part-selects (`a[i*4 +: 4]`) así que agregar más bloques es solo
cambiar el `generate`.

### `v2/cla4.sv` — el bloque de 4 bits con G y P de bloque

Es el mismo bloque de `v1` con **dos salidas nuevas**, `G` y `P`, que resumen
el comportamiento del bloque completo de cara al siguiente nivel:

```
P = p[3] & p[2] & p[1] & p[0]                              // propaga cin hasta cout
G = g[3] | (p[3]&g[2]) | (p[3]&p[2]&g[1]) | (p[3]&p[2]&p[1]&g[0])  // genera carry solo
```

Con eso se cumple la misma recurrencia a nivel bloque: `cout = G | (P & cin)`.
Lo elegante es que **`v1` ya calculaba casi todo**: `P` no es otra cosa que el
prefijo de producto compartido `pp3`, y `G` son los cuatro primeros términos
del árbol de `c[4]`. Así que sumar `G`/`P` cuesta **un solo `or` extra** (para
`G`) y un `assign` (para `P`), sin duplicar lógica. El bloque sigue siendo
100% estructural.

### `v2/cla16.sv` — el CLA jerárquico de dos niveles

Instancia cuatro bloques `cla4_v2` y, en vez de encadenar `cout`, **calcula
los carries entre bloques en paralelo** con un segundo nivel de lookahead
idéntico en estructura al lookahead interno de 4 bits, pero con los `G`/`P` de
bloque:

```
C[0]      = cin
C[1]      = G[0] | (P[0] & cin)
C[2]      = G[1] | (P[1]&G[0]) | (P[1]&P[0]&cin)
C[3]      = G[2] | (P[2]&G[1]) | (P[2]&P[1]&G[0]) | (P[2]&P[1]&P[0]&cin)
C[4] =cout = G[3] | (P[3]&G[2]) | (P[3]&P[2]&G[1]) | (P[3]&P[2]&P[1]&G[0])
               | (P[3]&P[2]&P[1]&P[0]&cin)
```

Se comparten los prefijos de producto de bloque `PP1`, `PP2`, `PP3` (igual que
adentro del bloque de 4 bits) para no duplicar compuertas. Cada bloque se
conecta con part-selects y recibe `C[i]` como `cin`; su `cout` ya no se usa
porque el lookahead inter-bloque lo calcula antes de que llegue el carry. El
`generate` solo cambia la cantidad de bloques; la estructura de lookahead es
independiente del `N`.

## La verificación

### `tb_cla.sv` — testbench que compara ambas versiones con el RCA

Toma el testbench de `v1` (que sigue el estilo del ejercicio 1) y lo **amplía**
para estimular juntas las dos versiones (módulos `cla4`/`cla16` de `v1` y
`cla4_v2`/`cla16_v2` de `v2`, por eso los nombres con sufijo) más el RCA16 de
referencia:

1. **`cla4` v1 exhaustivo**: las 512 combinaciones de `(a, b) × cin`,
   chequeadas contra `a + b + cin` en 5 bits.
2. **`cla4` v2 exhaustivo**, y además valida funcionalmente sus señales de
   bloque: `cout(cin=0) == G` y `cout(cin=1) == G | P`.
3. **`cla16` v1 y v2 en los bordes**: `0 + 0`, `max + max`, `max + 0` con
   `cin = 1` y `max + 1`.
4. **`cla16` v1 y v2 con 1000 vectores random**, cada uno contra
   `a + b + cin` en 17 bits.
5. **Cross-check triple**: `CLA16 v1` vs `CLA16 v2` vs `RCA16` — tres
   implementaciones correctas de la misma operación deben coincidir siempre.
6. **Tabla de delay** con las tres arquitecturas medidas en el mismo peor caso.

El testbench verifica de paso que ambas versiones se comportan idéntico:
reporta cuántos de los 1004 vectores (4 bordes + 1000 random) coincidieron
entre `v1` y `v2` (tienen que ser todos).

## El delay: CLA16 v1 vs CLA16 v2 vs RCA

Para medir el delay usamos el mismo **peor caso** que en el ejercicio 1:
partimos de `0 + 0` y aplicamos `a = max`, `b = 1`. El bit 0 genera carry y
este tiene que llegar hasta el final. Con monitores dedicados medimos por
separado el camino hasta `cout` y hasta `sum[15]`, en el CLA v1, el CLA v2 y
el RCA, con el mismo modelo de compuertas en todos:

| Arquitectura      | delay `cout` [ns] | delay `sum[15]` [ns] |
|-------------------|-------------------|----------------------|
| **CLA16 v1** (1N) | 17                | 19                   |
| **CLA16 v2** (2N) | **13**            | **16**               |
| **RCA16**         | 32                | 32                   |

Resultado: el CLA16 v2 es el más rápido de los tres. Contra el RCA gana por
lejos (13 vs 32 ns en `cout`, **~60 % más rápido**), y contra el CLA16 v1
mejora el camino crítico del carry en **~24 %** (13 vs 17 ns). ¿De dónde sale
cada diferencia?

- En el **RCA**, el carry atraviesa 16 etapas de `and + or` (~2 ns c/u):
  16 × 2 = 32 ns. Crecimiento **lineal** con `N`.
- En el **CLA16 v1**, el carry atraviesa solo 4 fronteras de bloque: el
  lookahead interno del primer bloque (~8 ns) y después un salto por bloque
  (~3 ns c/u) → 17 ns. Crecimiento con la **cantidad de bloques** (`N/4`).
- En el **CLA16 v2**, los carries entre bloques ya no se esperan entre sí: se
  calculan **en paralelo** en cuanto llegan los `G`/`P` de bloque. El camino
  crítico es `g/p` del bloque → árbol de `G` → árbol inter-bloque → `xor` de
  la suma, y quedó en 13 ns en `cout` y 16 ns en `sum[15]`. Al fijar el ancho
  de bloque, ese árbol de lookahead inter-bloque agrega una profundidad
  constante (~3-4 ns) por nivel de jerarquía: el delay pasa a crecer con
  **`log(N)`** y no con `N` ni con `N/4`.

Ojo: para `N = 16` la ganancia de `v2` sobre `v1` es modesta (los 4 bloques se
resuelven casi igual de rápido). La diferencia se nota cuando `N` crece: con
más bloques, `v1` agrega un salto secuencial por bloque mientras que `v2` solo
agrega un nivel de lookahead (y eventualmente otro `N` de jerarquía).

## Discusión: dónde gana CLA

- **Gana en delay cuando el carry es el camino crítico.** El RCA paga `N`
  etapas de ripple; el CLA las transforma en saltos entre bloques (`v1`) y
  finalmente en un árbol de lookahead (`v2`). Nuestro CLA16 v2 casi triplica
  la velocidad del RCA16 en `cout` (13 vs 32 ns).
- **El scaling es la clave.** Con bloques fijos de 4 bits, un solo nivel de
  lookahead crece con la cantidad de bloques (`N/4`); con **dos niveles**
  (bloques que exponen `G`/`P` y lookahead inter-bloque) el delay crece con
  `log(N)`. Ese segundo nivel ya está implementado en `v2` y medido: 13 ns en
  `cout` para `N = 16`.
- **A cambio de área.** El CLA usa muchas más compuertas que el RCA (cada
  carry expandido es un montón de `and`/`or`), y las redes de lookahead
  tienen *fan-out* y *fan-in* altos que en síntesis real complican el
  enrutamiento. `v2` agrega un bloque más de lookahead (los `G`/`P` y el árbol
  inter-bloque), por lo que es un poco más caro que `v1`. Para `N` chico el
  RCA sigue siendo razonable; el CLA se justifica cuando el ancho crece o el
  tiempo de ciclo aprieta.
- **Regla práctica:** para un sumador de pocos bits la estructura importa
  poco; para sumadores anchos el camino del carry domina y ahí el CLA (y
  después el CSLA del ejercicio 3) le gana al RCA por lejos.

## Cómo correrlo

```bash
./run.sh
```

El script compila `tb_cla.sv` junto con las fuentes de `v1` (`cla4` + `cla16`),
las de `v2` (`cla4_v2` + `cla16_v2`) y el RCA de referencia del ejercicio 1
(para el cross-check y la tabla de delay), y corre el testbench que testea y
compara las dos versiones en un solo run.

Salida esperada (al final de la verificación):

```
  CLA16 v1 (1N) |       17         |       19
  CLA16 v2 (2N) |       13         |       16
  RCA16         |       32         |       32
  ...
  CLA16 v1 y v2 coincidieron en los 1004 vectores (bordes + random)
RESULTADO: PASS  (cla4 v1+v2 exhaustivo, bordes, 1000 random, cross-check y delay OK)
```

Las formas de onda quedan en `tb_cla.vcd`.

## Conclusiones

- El CLA ataca el problema de fondo del RCA: **el carry ya no riplea bit a
  bit**, se calcula en paralelo con lookahead.
- Con un nivel de jerarquía (`v1`, bloques de 4) el CLA16 casi duplica la
  velocidad del RCA16 (17 vs 32 ns en `cout`) y el delay pasa a crecer con la
  cantidad de bloques en vez de con `N`.
- El **segundo nivel de lookahead** (`v2`) convierte el salto entre bloques en
  un árbol paralelo: cada bloque expone su `G`/`P` y los carries entre bloques
  se calculan con lookahead. Medido: 13 ns en `cout` (vs 17 de `v1`), y el
  delay pasa a crecer con `log(N)`, que es la promesa clásica del CLA.
- La verificación exhaustiva del bloque de 4 bits + 1000 random + cross-check
  contra el RCA y entre ambas versiones le da mucha confianza: si tres
  sumadores distintos coinciden en todo, es muy difícil que haya un bug en
  alguno.
- El costo es área y *fan-out*: el CLA es más rápido pero más caro que el RCA,
  y `v2` cuesta un poco más de área que `v1`. El balance entre velocidad y
  costo es justamente lo que explora el ejercicio 3 (CSLA).