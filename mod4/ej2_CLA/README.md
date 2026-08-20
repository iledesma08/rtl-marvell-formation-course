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
(`cla16`), igual que pide la consigna.

## Los módulos

### `cla4.sv` — el bloque de 4 bits

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

### `cla16.sv` — el CLA jerárquico

Encadena cuatro bloques `cla4` con un `generate-for`. El carry-out de cada
bloque es el carry-in del siguiente:

```
cblk[0] = cin
cblk[i + 1] = carry-out del bloque i   ->   carry-in del bloque i + 1
```

Ese es el **lookahead inter-bloque por carry** que pide el enunciado: adentro
de cada bloque los carries se resuelven en paralelo, y entre bloques el carry
"salta" en un solo paso en vez de propagarse bit a bit. Cada bloque se
conecta con part-selects (`a[i*4 +: 4]`) así que agregar más bloques es solo
cambiar el `generate`.

## La verificación

El `tb_cla.sv` es un testbench **self-checking** que sigue el estilo del
ejercicio 1 y cubre lo que pide el enunciado:

1. **`cla4` exhaustivo**: las 512 combinaciones de `(a, b) × cin` (4 bits de
   cada uno), chequeadas contra `a + b + cin` en 5 bits. Con 4 bits es barato
   probarlo todo y no dejamos ninguna combinación afuera.
2. **`cla16` bordes**: `0 + 0`, `max + max` (carry-out = 1), `max + 0` con
   `cin = 1` y `max + 1`.
3. **`cla16` con 1000 vectores random**, comparados contra `a + b + cin`
   extendido a 17 bits.
4. **Cross-check contra el RCA16**: al mismo tiempo que verificamos contra el
   host, estimulamos el RCA del ejercicio 1 con los mismos vectores y
   exigimos que ambos sumadores den exactamente lo mismo. Dos implementaciones
   correctas de la misma operación tienen que coincidir siempre; si una difiere,
   hay un bug en alguna de las dos.

Como el DUT es estructural y tiene gate delays, después de cada estímulo
esperamos a que las salidas se estabilicen antes de chequear (lo más lento es
el RCA16, que tarda ~32 ns).

## El delay: CLA vs RCA

Para medir el delay usamos el mismo **peor caso** que en el ejercicio 1:
partimos de `0 + 0` y aplicamos `a = max`, `b = 1`. El bit 0 genera carry y
este tiene que llegar hasta el final. Con monitores dedicados medimos por
separado el camino hasta `cout` y hasta `sum[15]`, en el CLA y en el RCA, con
el mismo modelo de compuertas en ambos:

| Arquitectura | delay `cout` [ns] | delay `sum[15]` [ns] |
|--------------|-------------------|----------------------|
| **CLA16**    | 17                | 19                   |
| **RCA16**    | 32                | 32                   |

Resultado: el CLA16 es casi **40 % más rápido** en el camino crítico del
carry (17 vs 32 ns en `cout`). ¿De dónde sale la diferencia?

- En el **RCA**, el carry atraviesa 16 etapas de `and + or` (~2 ns c/u):
  16 × 2 = 32 ns. Crecimiento **lineal** con `N`.
- En el **CLA**, el carry atraviesa solo 4 fronteras de bloque: dentro de cada
  bloque de 4 bits el lookahead lo resuelve en paralelo (~8 ns en el primer
  bloque) y cada frontera entre bloques agrega ~3 ns. Crecimiento con la
  **cantidad de bloques** (`N/4`), no con `N`.

El path crítico del CLA sigue siendo el del carry (nada nuevo bajo el sol),
pero el carry ya no "ve" los 16 bits: ve un bloque de 4 y después salta de
bloque en bloque.

## Discusión: dónde gana CLA

- **Gana en delay cuando el carry es el camino crítico.** Para sumadores
  anchos el RCA paga `N` etapas de ripple; el CLA las transforma en saltos
  entre bloques. Nuestro CLA16 con un solo nivel de jerarquía ya casi
  duplica la velocidad del RCA16.
- **El scaling es la clave.** Con bloques fijos de 4 bits, el delay crece con
  la cantidad de bloques (`N/4`). Si `N` se hace grande conviene agregar un
  **segundo nivel de lookahead**: que cada bloque también produzca su `G` y su
  `P` de bloque, y que el carry entre bloques también se calcule con lookahead.
  Con dos niveles el delay crece con `log(N)`, que es justo el punto del
  enunciado.
- **A cambio de área.** El CLA usa muchas más compuertas que el RCA (cada
  carry expandido es un montón de `and`/`or`), y las redes de lookahead
  tienen *fan-out* y *fan-in* altos que en síntesis real complican el
  enrutamiento. Para `N` chico el RCA sigue siendo razonable; el CLA se
  justifica cuando el ancho crece o el tiempo de ciclo aprieta.
- **Regla práctica:** para un sumador de pocos bits la estructura importa
  poco; para sumadores anchos el camino del carry domina y ahí el CLA (y
  después el CSLA del ejercicio 3) le gana al RCA por lejos.

## Cómo correrlo

```bash
./run.sh
```

El script compila `cla4.sv + cla16.sv` junto con el RCA de referencia del
ejercicio 1 (para el cross-check y la tabla de delay) y corre el testbench.

Salida esperada (al final de la verificación):

```
RESULTADO: PASS  (cla4 exhaustivo, bordes, 1000 random y delay OK)
```

Las formas de onda quedan en `tb_cla.vcd`

## Conclusiones

- El CLA ataca el problema de fondo del RCA: **el carry ya no riplea bit a
  bit**, se calcula en paralelo con lookahead.
- Con un solo nivel de jerarquía (bloques de 4) el CLA16 casi duplica la
  velocidad del RCA16 (17 vs 32 ns en `cout`), y el delay pasa a crecer con la
  cantidad de bloques en vez de con `N`.
- Para `N` grandes, un segundo nivel de lookahead entre bloques lleva el
  delay a crecer con `log(N)`, que es la promesa clásica del CLA.
- La verificación exhaustiva del bloque de 4 bits + 1000 random + cross-check
  contra el RCA le da mucha confianza: si dos sumadores distintos coinciden en
  todo, es muy difícil que haya un bug en alguno.
- El costo es área y *fan-out*: el CLA es más rápido pero más caro que el RCA.
  El balance entre velocidad y costo es justamente lo que explora el
  ejercicio 3 (CSLA).