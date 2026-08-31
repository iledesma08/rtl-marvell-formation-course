# Ejercicio 1 — CORDIC iterativo en Verilog

## Enunciado

**Implementar un CORDIC modo rotación *folded* en Verilog para calcular sen(θ) y cos(θ).**

Debe operar sobre punto fijo S(16,14) y completar 14 iteraciones en 14 ciclos.

### Datos
- NB = 16, NBF = 14 (formato S(16,14))
- N_ITER = 14
- K ≈ 0.60725 → x₀ = K en S(16,14)
- Rango θ: [−π/2, +π/2]

### Entregables
- (a) RTL del datapath folded
- (b) ROM con arctan(2⁻ⁱ) tabulado
- (c) FSM de control (idle/iter/done)
- (d) Testbench con θ = π/6, π/4, π/3

> Tabular arctan(2⁻ⁱ) en S(16,14) en una ROM de 14 entradas.

---

## Idea general del algoritmo

CORDIC (COordinate Rotation DIgital Computer) calcula funciones trigonométricas usando solo sumas, restas y corrimientos de bits, evitando multiplicadores. En **modo rotación**, se parte de un vector $(x_0, y_0) = (K, 0)$ y se lo rota un ángulo $\theta$ mediante 14 micro-rotaciones sucesivas, cuyo ángulo va disminuyendo:

$$x_{i+1} = x_i - d_i \cdot y_i \cdot 2^{-i}$$
$$y_{i+1} = y_i + d_i \cdot x_i \cdot 2^{-i}$$
$$z_{i+1} = z_i - d_i \cdot \arctan(2^{-i})$$

con $d_i = +1$ si $z_i \geq 0$, y $d_i = -1$ si $z_i < 0$. Al cabo de 14 iteraciones, $x_{14} \approx \cos\theta$ e $y_{14} \approx \sin\theta$ (con $K$ ya compensando la ganancia del algoritmo).

## Punto fijo S(16,14)

Cada valor se representa con 16 bits totales, con signo, 14 de ellos fraccionarios. El hardware nunca "sabe" que un número tiene parte fraccionaria: opera siempre con enteros crudos (complemento a 2). 

Para tabular una constante en S(16,14): se la expresa en radianes, se multiplica por $2^{14}=16384$, se redondea al entero más cercano, y ese entero se escribe en hexadecimal/binario de 16 bits con signo.

---

## `ROM.sv` — Tabla de arctan(2⁻ⁱ)

**Decisiones de diseño:**
- Es **combinacional puro** (sin `clk`): es una tabla de solo lectura, no tiene estado propio.
- Se implementó con **`case`** en vez de `localparam` + array (`'{...}`), porque esa segunda forma **no es soportada por Icarus Verilog**. El `case` es soportado sin dudas tanto en simulación como en síntesis con Yosys.
- `cordic_index` es **sin signo** (nunca hay índices negativos).
- El `default` cubre los índices 14 y 15 (que nunca deberían ocurrir) para evitar que el sintetizador infiera un latch por caminos del `case` sin cubrir.

---

## `CORDIC.sv` — Datapath folded

### Decisiones de diseño y bugs resueltos

**1. Separación `_base` / `_next` (patrón combinacional + registro)**
`X_base`/`Y_base`/`Z_base` seleccionan con qué operandos trabaja *esta* iteración: si `start=1`, vienen de las constantes ($K$, $0$, $\theta$); si no, vienen de los registros actuales. `X_next`/`Y_next`/`Z_next` son el resultado de aplicar la ecuación de CORDIC a esos operandos base. El `always_ff` solo copia `_next` a los registros — nunca calcula nada nuevo, solo decide *cuándo* el resultado combinacional pasa a ser el nuevo estado. Esto permite que el ciclo de `start` ya haga la iteración $i=0$ en el mismo ciclo, sin gastar un ciclo extra solo para "cargar".

**2. Contador `i`**
Debe representar 0 a 13.

**3. `cos`/`sen` como registros (`cos_reg`/`sen_reg`), no combinacionales**
La primera versión asignaba `cos`/`sen` combinacionalmente solo cuando `i==13`. Problema: ese es el único ciclo donde el valor es correcto, pero es también el ciclo donde la FSM (todavía en estado `ITER`) *no los está mirando*. Al pasar a registros actualizados en cada ciclo con `X_next`/`Y_next`, el valor correcto queda disponible recién en el ciclo siguiente — exactamente cuando la FSM pasa a `DONE` y sí los lee. Además, al ser un registro con default (`=0` en declaración) y actualización condicionada, no hay riesgo de latch.

**4. `Busy` como señal registrada, no combinacional**
La primera versión calculaba `Busy = (i==13) ? 0 : 1` dentro del `always_comb` — es decir, sensible a *nivel*. Esto hacía que `Busy` cayera a 0 durante *todo* el ciclo en que `i` vale 13 (no solo al final), y por lo tanto, en el flanco de clock que debía comprometer el resultado de la iteración 13 a los registros, la condición `start||Busy` ya daba falso — esa actualización final **nunca se ejecutaba**, dejando `i` pegado en 13 y corrompiendo los cómputos siguientes. La solución fue convertir `Busy` en un **registro** (actualizado dentro del `always_ff`), sensible a *flanco*: en el ciclo crítico, `Busy` todavía vale 1 (heredado del ciclo anterior), y recién en ese mismo flanco se calcula el `0` que regirá para el ciclo *siguiente*. Un registro separa naturalmente "cuándo se calcula el próximo valor" de "cuándo ese valor entra en vigencia".

---

## `FSM.sv` — Control (IDLE / ITER / DONE)

### Decisiones de diseño

- **3 estados** (no 4): `Start_cordic` se calcula **combinacionalmente** dentro de `IDLE` (`start_cordic = start`), en vez de usar un estado dedicado solo para pulsar el arranque — esto evita gastar un ciclo extra, ya que `start_cordic` llega a CORDIC en el mismo ciclo en que la FSM todavía está en `IDLE`, justo a tiempo para que la iteración $i=0$ se calcule correctamente.
- **`DONE` dura un solo ciclo**: siempre transiciona de vuelta a `IDLE` en el ciclo siguiente, sin condición. Esto permite encadenar varios cómputos (varios ángulos) sin necesidad de resetear el circuito entre uno y otro. Contrato asumido: quien maneja `start` debe bajarlo a 0 antes de que la FSM vuelva a `IDLE`, para no disparar un cómputo nuevo sin querer.

---

## `top.sv` — Integración estructural

`top.sv` es **puramente estructural**: no tiene ningún `always`, solo instancia `FSM` y `CORDIC` como bloques hermanos y los conecta mediante wires internos (`w_*`). Esto respeta la separación de responsabilidades pedida en el enunciado (bloques (a), (b), (c) por separado) y facilita testear cada módulo de forma aislada si hiciera falta.

---

## `tb_top.sv` — Testbench



### Decisiones de diseño

- **`$itor(sen_out) / 16384.0`**: convierte el entero crudo con signo a tipo `real` (con `$itor`) y divide por $2^{14}$ para obtener el número real que ese entero representa en S(16,14) — únicamente para poder mostrarlo/compararlo en el `$display`. Sin `$itor` (o sin el `.0` en el divisor), SV haría división entera y truncaría toda la parte fraccionaria a 0.
- **`#1` después de cada `@(posedge clk)` crítico**: El pequeño delay asegura leer *después* de que todo ya esté estable.
- **`contador_ciclo`**: verifica que el cómputo tarda exactamente 14 iteraciones. Se inicializa en 1 (por la iteración $i=0$, que ocurre en el flanco de `start`, antes de que el `while` empiece a contar), se incrementa una vez por cada vuelta del `while` (iteraciones $i=1$ a $i=12$), y se le suma 1 al final (por la iteración $i=13$, que se compromete en el flanco *siguiente* al que hace que `done` se active, ya que `done` sube apenas el registro `i` llega a 13, un instante antes de que ese valor final quede grabado).

---

## Resultados de simulación

Con los 3 ángulos de prueba:

| Ángulo | sen obtenido | sen esperado | cos obtenido | cos esperado |
|---|---|---|---|---|
| π/6 | 0.499451 | 0.500000 | 0.866516 | 0.866025 |
| π/4 | 0.706726 | 0.707107 | 0.707397 | 0.707107 |
| π/3 | 0.865845 | 0.866025 | 0.500183 | 0.500000 |

Imagen: 

![Resultados en terminal](Display.png)

## Compilación y ejecución

```bash
bash run.sh
```