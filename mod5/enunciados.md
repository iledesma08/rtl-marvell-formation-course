# Ejercicios Prácticos

## Ejercicio 1 — CORDIC iterativo en Verilog

### ENUNCIADO

Implementar un CORDIC modo rotación folded en Verilog para calcular $\operatorname{sen}(\theta)$ y $\cos(\theta)$.

Debe operar sobre punto fijo $S(16,14)$ y completar 14 iteraciones en 14 ciclos.

### DATOS

* $\text{NB} = 16$, $\text{NBF} = 14$ (formato $S(16,14)$)
* $\text{N\_ITER} = 14$
* $K \approx 0.60725 \rightarrow x_0 = K$ en $S(16,14)$
* Rango $\theta$: $[-\pi/2, +\pi/2]$

### ENTREGABLES

* (a) RTL del datapath folded
* (b) ROM con $\operatorname{atan}(2^{-i})$ tabulado
* (c) FSM de control (idle/iter/done)
* (d) Testbench con $\theta = \pi/6, \pi/4, \pi/3$

> 💡 *Tabular $\operatorname{atan}(2^{-i})$ en $S(16,14)$ en una ROM de 14 entradas*

---

## Ejercicio 2 — Comparar folded vs pipeline

### ENUNCIADO

Tomar el CORDIC del ejercicio 1 y construir una versión pipeline (unfolded).

Comparar área, $f_{\max}$ y latencia entre ambas implementaciones usando una herramienta de síntesis (Vivado, Yosys o similar).

### DATOS

* Mismo formato $S(16,14)$, $N=14$
* Tecnología: FPGA Artix-7 o ASIC 45/130nm
* Constraint inicial: 100 MHz
* Reporte LUTs/FFs o área $\mu\text{m}^2$

### ENTREGABLES

* (a) RTL pipeline (14 etapas)
* (b) Tabla comparativa $A\ /\ F_{\max}\ /\ \text{latencia}$
* (c) Cálculo de throughput
* (d) Conclusión: ¿cuándo usar cuál?

> 💡 *Reportar throughput = samples/segundo, no solo latencia*

---

## Ejercicio 3 — CORDIC Vectoring para magnitud

### ENUNCIADO

Implementar CORDIC modo vectoring para calcular $R = \sqrt{x^2 + y^2}$ y $\varphi = \operatorname{atan}(y/x)$.

Comparar con la implementación directa usando un multiplicador y una ROM grande.

### DATOS

* Entrada: $x$, $y$ en $S(16,15)$
* Salida: $R$ en $S(16,15)$, $\varphi$ en $S(16,14)$
* $\text{N\_ITER} = 16$
* Vectores de test: cuadrantes I, II, III, IV

### ENTREGABLES

* (a) RTL CORDIC vectoring
* (b) Implementación de referencia con mult
* (c) Comparación área + precisión
* (d) Error vs cuadrante

> 💡 *Pre-rotar $180^\circ$ si $x < 0$ para mantener $\vert{}z\vert{}$ dentro del rango de convergencia*

---

## Ejercicio 4 — Newton-Raphson para 1/x

### ENUNCIADO

Implementar un divisor por NR que calcule $y = 1/a$ con 16 bits de precisión.

Usar una LUT chica de 8 entradas para $y_0$ y completar la convergencia con 3-4 iteraciones NR.

### DATOS

* $a$ normalizado a $[0.5, 1.0)$
* Formato $U(16,16)$ en $y$
* LUT inicial: $y_0(a)$ con 8 índices
* Multiplicador: $16 \times 16 \rightarrow 32\text{ bits}$

### ENTREGABLES

* (a) Generador de LUT (Python)
* (b) RTL del datapath NR folded
* (c) FSM con flag "done" tras N iters
* (d) Análisis: error vs N iteraciones

> 💡 *Pre-normalizar $a \rightarrow [0.5, 1.0)$ sumando el desplazamiento al exponente*