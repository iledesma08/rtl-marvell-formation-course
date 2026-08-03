# Ejercicio 5 — Pipeline de 3 etapas con Valid/Ready (SystemVerilog)

## Enunciado

Nos piden implementar un pipeline síncrono de 3 etapas que calcule:

$$
y = ((x + A) \cdot B) \gg 4
$$

con las etapas bien definidas:

* **Etapa 1:** suma $x + A$;
* **Etapa 2:** multiplica el resultado por $B$;
* **Etapa 3:** *shift* aritmético a la derecha de 4 posiciones.

La interfaz usa un handshake AXI-Stream: por la entrada tenemos `x_in`, `valid_in` y `ready_out`; por la salida `y_out`, `valid_out` y `ready_in`. cuando `ready_in = 0` el pipeline **debe** bloquearse (*stall*), y si en ese momento llega `valid_in = 1`, `ready_out` tiene que valer 0. Las constantes están fijas: $A = 8'sd5$ y $B = 8'sd3$, con `x_in` de 8 bits y `y_out` de 16 bits. La latencia esperada es de 3 ciclos y el throughput teórico, sin stalls, de 1 muestra/ciclo.

---

## Cómo lo resolvemos

La idea central es que un pipeline es una cadena de registros: en cada flanco cada etapa captura lo que dejó lista la etapa anterior y calcula la parte que le toca. Para que el handshake funcione, además de los datos registramos un `valid` por etapa. Así el pipeline sabe "tengo un dato válido en vuelo" en cada punto del camino, y puede propagar esa información hasta la salida.

### Los anchos de las etapas

Acá conviene pensar un poco antes de escribir código, porque si nos quedamos cortos de bits perdemos precisión:

* `x` y `A` son de 8 bits *signed* → la suma $x + A$ necesita **9 bits** (`XW + 1`);
* ese resultado de 9 bits multiplicado por `B` (8 bits *signed*) necesita **17 bits** (`XW + 1 + XW`);
* el *shift* `>>>` de 4 posiciones no cambia el ancho: seguimos con 17 bits y al final recortamos a los 16 bits de `y_out`.

Dejamos los anchos como `localparam` calculados a partir de `XW`, así si algún día cambia el ancho de la entrada el pipeline se re-acomoda solo.

### El handshake y el back-pressure

El punto más fino del ejercicio es el *stall*. Nuestro pipeline es síncrono y balanceado: las tres etapas tardan un ciclo, así que no hace falta un `ready` por etapa. Directamente propagamos la presión de punta a punta:

```systemverilog
assign ready_out = ready_in;   // la presión de back-pressure se propaga
```

Cuando `ready_in = 0`, congelamos **todos** los flip-flops con un `CE` común. En SystemVerilog esto se traduce en un solo `else if (ready_in)` dentro del `always_ff`:

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    s1_valid <= 1'b0;
    s2_valid <= 1'b0;
    s3_valid <= 1'b0;
    r1 <= '0;  r2 <= '0;  r3 <= '0;
  end else if (ready_in) begin
    // Etapa 3: captura el producto de la etapa 2 y aplica el shift aritmético.
    s3_valid <= s2_valid;
    r3       <= r2 >>> SHIFT;
    // Etapa 2: captura la suma de la etapa 1 y multiplica por B.
    s2_valid <= s1_valid;
    r2       <= r1 * B;
    // Etapa 1: captura la entrada y suma A.
    s1_valid <= valid_in;
    r1       <= x_in + A;
  end
end
```

Si `ready_in = 0`, ningún `<=` se ejecuta y todo queda congelado. Como `ready_out = ready_in`, el pipeline además le "avisa" al productor que no puede aceptar: con *stall* y `valid_in = 1`, `ready_out` vale 0, tal como pide el enunciado. Notar que usamos `>>>` (arreglo aritmético) y no `>>`, porque `x` puede ser negativo y queremos conservar el signo.

> **Un detalle del `valid`:** el `valid_out` lo sacamos del `valid` de la tercera etapa (`s3_valid`), que es un registro más. Por eso, cuando el consumidor no está listo, `valid_out` queda "colgado" en 1 todo el tiempo que dura el *stall* (el dato no se pierde, simplemente espera). Esa es la semántica correcta de AXI-Stream: la transferencia recién ocurre cuando `valid_out && ready_in`.

---

## Verificación

Para no quedarnos con la teoría, armamos un testbench que verifica tres cosas.

### El golden model en software

En el testbench escribimos una función que replica la aritmética de forma independiente del RTL:

```systemverilog
function automatic logic signed [15:0] golden_y(input logic signed [7:0] x);
  logic signed [16:0] tmp;
  tmp = (($signed(x) + 8'sd5) * 8'sd3) >>> 4;
  return tmp[15:0];
endfunction
```

Y para saber *qué* muestra debe salir en cada momento, mantenemos un FIFO con las muestras que el pipeline fue aceptando. Como el pipeline es estrictamente en orden, cuando `valid_out && ready_in` el resultado que aparece corresponde a la muestra más vieja del FIFO: la sacamos y la comparamos contra `golden_y`. De esta forma el modelo en software no re-implementa el RTL, sino que modela el comportamiento de un pipeline en orden (primero entra, primero sale).

### Prueba con *stall* (`ready_in` alternando 1/0)

El enunciado nos pide probar el *stall*, así que además de la fase sin *stalls* corremos una segunda fase con `ready_in` alternando `1/0` de a un ciclo. Mientras `valid_in = 1` todo el tiempo, esperamos que:

* el pipeline acepte muestras solo cuando `ready_in = 1`;
* con `ready_in = 0` y `valid_in = 1`, `ready_out` sea 0 (lo chequeamos explícitamente ciclo a ciclo y reportamos cualquier violación);
* no se pierda ni una muestra: al final, lo aceptado debe ser igual a lo producido.

### Throughput observado vs. teórico

Definimos el throughput como la cantidad de muestras por ciclo. En régimen sin *stalls* cada ciclo el pipeline avanza y acepta una muestra: 1 muestra/ciclo. Con la alternancia `1/0`, el pipeline solo avanza la mitad de los ciclos, así que el teórico es 0.5 muestras/ciclo.

Los números que obtuvimos de la simulación:

| Métrica                          | Fase 1 (sin *stalls*) | Fase 2 (con *stalls*) |
|----------------------------------|:---------------------:|:---------------------:|
| Ciclos de ventana                | 40                    | 200                   |
| Ciclos con `ready_in = 1`        | 40                    | 100                   |
| Muestras aceptadas               | 40                    | 100                   |
| Muestras producidas              | 40                    | 100                   |
| Violaciones de handshake         | 0                     | 0                     |
| **Throughput observado**         | **1.000** m/ciclo     | **0.500** m/ciclo     |
| **Throughput teórico**           | **1.000** m/ciclo     | **0.500** m/ciclo     |

Lo observado coincide con lo teórico en ambas fases: el pipeline no pierde datos con los *stalls*, solo los ralentiza. La latencia medida (primera muestra aceptada → primera salida válida) dio exactamente **3 ciclos**.

> El throughput de la tabla se mide sobre la ventana de alimentación (aceptadas / ciclos de ventana). Si en vez de eso midiéramos producidas / (ventana + drenaje), el número quedaría un poco por debajo del  teórico (≈ 0.498 en la fase 2), porque el llenado y el drenaje del pipeline agregan un costo fijo de 3 ciclos que se amortigua a medida que la ventana crece. Con ventanas largas, la medición converge al valor teórico.
>
> Osea, el pipeline al principio tarda en "llenarse" y al final tarda en "vaciarse". Si se considera el tiempo de llenado y de vaciado, el número que se mide queda un poquito más bajo de lo que el pipeline rinde "de verdad" cuando ya está trabajando a pleno (estado estacionario). Cuanto más larga sea la ventana, os 3 ciclos fijos de llenado/drenaje pesan cada vez menos en el promedio, y la medición se acerca cada vez más a 0.5. Por eso decimos que "converge al valor teórico" (nunca llega exacto, pero se acerca cada vez más).

---

## Archivos

| Archivo               | Contenido                                                        |
|-----------------------|------------------------------------------------------------------|
| `pipeline_3stage.sv`  | Pipeline de 3 etapas con handshake AXI-Stream y `CE` común        |
| `tb_pipeline.sv`      | Golden model en software, test de *stall* y medición de throughput |
| `run.sh`              | Compila + simula con iverilog/vvp (`-g2012`)                     |

El VCD obtenido es el siguiente:

<div style="text-align: center; width: 720px; margin: 0 auto;">

![/img/gtkwave-1.png](gtkwave.png)

</div>

<div style="text-align: center; width: 720px; margin: 0 auto;">

![img/gtkwave-2.png](gtkwave.png)

</div>

<div style="text-align: center; width: 720px; margin: 0 auto;">

![img/gtkwave-3.png](gtkwave.png)

</div>

<div style="text-align: center; width: 720px; margin: 0 auto;">

![img/gtkwave-4.png](gtkwave.png)

</div>

<div style="text-align: center; width: 720px; margin: 0 auto;">

![img/gtkwave-5.png](gtkwave.png)

</div>

<div style="text-align: center; width: 720px; margin: 0 auto;">

![img/gtkwave-6.png](gtkwave.png)

</div>

<div style="text-align: center; width: 720px; margin: 0 auto;">

![img/gtkwave-7.png](gtkwave.png)

</div>

<div style="text-align: center; width: 720px; margin: 0 auto;">

![img/gtkwave-8.png](gtkwave.png)

</div>
