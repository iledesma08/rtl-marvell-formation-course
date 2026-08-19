# Ejercicio 1 — Ripple Carry Adder N-bit parametrizable

## De qué va esto

Acá armamos un sumador de `N` bits en estilo **estructural**: nada de escribir
`a + b` y listo, sino que encadenamos *full adders* reales de 1 bit, uno por
cada posición, dejando que el carry de salida de cada etapa sea el carry de
entrada de la siguiente. Ese "carry que va saltando" de bit en bit es lo que le
da el nombre al circuito.

La idea del ejercicio es doble: por un lado practicar el armado **parametrizable**
con `generate-for` (para que el mismo módulo sirva de 4, 8, 16 o 32 bits sin
tocar el código) y por el otro **medir el delay** que introduce esa cadena de
carries, para entender de dónde viene la famosa limitación del RCA.

## Los módulos

### `full_adder.sv` — la célula de 1 bit

El full adder de 1 bit se construyó con **compuertas primitivas** (`xor`, `and`,
`or`) y sus ecuaciones clásicas:

```
p    = a ^ b            // propaga el carry
g    = a & b            // genera el carry
cout = g | (p & cin)
sum  = p ^ cin          // = a ^ b ^ cin
```

A cada compuerta le pusimos un **delay de propagación explícito** porque sin eso
la simulación sería de delay cero y no habría nada que medir. Usamos valores
pedagógicos típicos: la `xor` tarda `2 ns` (es la más lenta) y `and`/`or`
tardan `1 ns`. Con esos delays el simulador se comporta como una red real y
podemos cronometrar el camino crítico.

### `rca.sv` — la cadena parametrizable

El módulo `rca` tiene el parámetro `N` (default `8`) y encadena `N` full adders
con un `generate-for`. El carry-in entra por `cin`, se va pasando de etapa en
etapa a través de un vector `carry[N:0]`, y el último sale por `cout`, ambos
explícitos como pide la consigna.

```systemverilog
genvar i;
generate
  for (i = 0; i < N; i = i + 1) begin : fa_chain
    full_adder u_fa (
      .a   (a[i]),
      .b   (b[i]),
      .cin (carry[i]),
      .sum (sum[i]),
      .cout(carry[i + 1])
    );
  end
endgenerate
```

Como el bloque del `generate` se etiquetó `fa_chain` y cada full adder se
instancia como `u_fa`, el simulador les asigna un **nombre jerárquico** de la
forma `<instancia del rca>.<fa_chain>[<i>].<u_fa>`. En nuestro testbench, donde
el RCA se instancia como `dut`, el cuarto full adder queda
`tb_rca.dut.fa_chain[3].u_fa`. Eso permite leer sus señales internas por
referencia directa (por ejemplo `tb_rca.dut.fa_chain[3].u_fa.cout`) y, en
GTKWave, navegar el árbol `tb_rca → dut → fa_chain[0..7] → u_fa` para ver no
solo `sum`/`cout` sino también los intermedios `p`, `g` y `pc`.

## La verificación

El `tb_rca.sv` es un testbench **self-checking**: para cada estímulo calcula el
esperado como `a + b + cin` extendido a `N+1` bits y compara contra la salida
del DUT (suma en los `N` bits bajos y `cout` en el bit extra). Cubre lo que pide
el enunciado:

1. **Borde inferior**: `0 + 0` → `sum = 0`, `cout = 0`.
2. **Borde superior**: `max + max` → `sum = 2^N - 2`, `cout = 1`.
3. **Casos con carry-out = 1**: `max + 1` (que además genera el ripple total),
   `max + 0` con `cin = 1`, etc.
4. **500 casos random** comparados contra la suma en el host.

Un detalle importante: como el DUT es estructural y tiene gate delays, después
de aplicar cada estímulo esperamos `2·N + 5 ns` a que las salidas se estabilicen
antes de chequear; si no, compararíamos con valores a medio propagar.

## El delay y el path crítico

Para medir el delay hay que inducir el **peor caso**: que el carry tenga que
atravesar todas las etapas. Eso pasa con `a = 2^N - 1` (todos unos) y `b = 1`:
el bit 0 genera carry y cada etapa siguiente solo lo va propagando, sin poder
"cortarlo". Lo aplicamos desde el estado `0 + 0` y registramos el instante en
que cada salida deja de cambiar, con monitores dedicados a `cout` y a
`sum[N-1]`.

Los resultados que obtuvimos:

| N | full adders | Delay peor caso [ns] |
|---|-------------|----------------------|
| 4 | 4 | 8 |
| 8 | 8 | 16 |
| 16 | 16 | 32 |
| 32 | 32 | 64 |

La medición da exactamente `2·N ns`, es decir **crecimiento lineal con N**, y la
gráfica (generada por `plot_delay.py`) lo deja
bien claro. Si lo pensamos, tiene todo el sentido:

- La `xor` que calcula `p` en cada etapa ya se resuelve al inicio (solo depende
  de `a` y `b`).
- El primer carry sale a los `2 ns` y cada etapa siguiente agrega `and + or = 2 ns`.
- El **path crítico** es entonces el del carry: `cin → cout` y `cin → sum[N-1]`,
  porque el bit más significativo no se resuelve hasta que el carry le llega.

En el testbench medimos esos dos caminos **por separado**, con un monitor
dedicado a `cout` y otro al bit `sum[N-1]`.

> Por eso, para sumadores anchos el RCA es lento: el delay crece con `N`, no con `log2(N)`. Esa es justamente la motivación de los ejercicios 2 y 3 (CLA y CSLA).

## Cómo correrlo

```bash
./run.sh
```

El script hace todo en cadena: compila y simula el testbench de verificación,
corre el barrido de delay para `N = {4, 8, 16, 32}`, y genera la gráfica.

Salida esperada (al final de la verificación):

```
RESULTADO: PASS  (borde inferior, borde superior, carry-out y 500 random OK)
```

Las formas de onda quedan en `tb_rca.vcd` y `tb_rca_delay.vcd` y la gráfica en `output_delay.png`.

## Conclusiones

- El RCA es **simple y regular**, pero su delay crece linealmente con `N`: cada
  full adder agrega ~2 ns al ripple del carry.
- El `generate-for` hace que un solo módulo sirva para cualquier ancho; la
  cantidad de full adders es siempre `N`.
- Verificar contra `a + b + cin` en el host es suficiente y robusto, porque
  cubre el desborde natural al comparar con `N+1` bits.
- El camino crítico está en la cadena de carries, así que para anchos grandes
  conviene mirar arquitecturas que aceleren esa propagación (CLA, CSLA).