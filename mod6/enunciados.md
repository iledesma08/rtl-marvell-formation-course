# Ejercicios Prácticos

## Ejercicio 1 — Construir el DFG

### ENUNCIADO

Dibujar el DFG de un FIR de 4 coeficientes en forma directa.

Identificar nodos, aristas y registros ($z^{-1}$).

### DATOS

* Filtro FIR de 4 coeficientes
* Implementación en forma directa
* Aplicar sobre un FIR simple

### ENTREGABLES

* Diagrama DFG del filtro FIR
* Identificación explícita de nodos (operaciones), aristas (flujo de datos) y registros ($z^{-1}$)

> 💡 *Aplicar lo aprendido sobre un FIR simple.*

---

## Ejercicio 2 — Aplicar ASAP y ALAP

### ENUNCIADO

Asignar cada nodo a un ciclo bajo recursos ilimitados.

Calcular la movilidad de cada operación.

### DATOS

* DFG del FIR de 4 coeficientes (Ejercicio 1)
* Recursos ilimitados
* Programación por ASAP (*As Soon As Possible*) y ALAP (*As Late As Possible*)

### ENTREGABLES

* Asignación de ciclos por ASAP
* Asignación de ciclos por ALAP
* Cálculo y reporte de la movilidad para cada operación

> 💡 *La movilidad de una operación determina la holgura temporal para la asignación de recursos.*

---

## Ejercicio 3 — Versión iterativa

### ENUNCIADO

Reescribir con 1 sumador y 1 multiplicador compartidos.

Diseñar la FSM de control y estimar latencia y throughput.

### DATOS

* Recursos compartidos: 1 multiplicador, 1 sumador
* Reutilización de hardware en múltiples ciclos de reloj

### ENTREGABLES

* RTL o esquemático de la arquitectura iterativa
* Diseño de la FSM de control
* Estimación teórica de latencia y throughput

> 💡 *Compartir recursos minimiza área a expensas de requerir múltiples ciclos por muestra.*

---

## Ejercicio 4 — Versión pipeline

### ENUNCIADO

Aplicar un cut-set feed-forward para insertar 2 etapas de pipeline.

Calcular el nuevo camino crítico y comparar fmax.

### DATOS

* DFG del FIR original
* Inserción de 2 etapas de pipeline mediante cut-set feed-forward

### ENTREGABLES

* Diagrama del circuito con cut-sets y registros agregados
* Cálculo del nuevo camino crítico
* Comparación de frecuencia máxima ($f_{\max}$) frente a la versión sin pipeline

> 💡 *El pipelining divide el camino crítico combinacional para aumentar la frecuencia de reloj sin alterar la funcionalidad feed-forward.*

---

## Ejercicio 5 — Comparar PPA

### ENUNCIADO

Tabular latencia, throughput, área (estimada en celdas) y consumo relativo entre las dos versiones.

### DATOS

* Versión iterativa (Ejercicio 3)
* Versión pipeline (Ejercicio 4)
* Métricas PPA: Power, Performance, Area

### ENTREGABLES

* Tabla comparativa de PPA entre la versión iterativa y la versión pipeline
* Análisis de compromisos (*trade-offs*) entre ambas implementaciones

> 💡 *Comparar latencia, throughput, área estimada y consumo relativo.*

---

## Ejercicio 6 — Identificar IPB

### ENUNCIADO

Convertir el FIR a un IIR de 1er orden y calcular IPB.

Discutir cómo bajarlo con Shannon o C-Slow.

### DATOS

* Transformación de FIR a IIR de 1er orden (inclusión de lazo de realimentación)
* Métricas: Iteration Period Bound (IPB)
* Técnicas de optimización de lazo: Shannon expansion o C-Slow retiming

### ENTREGABLES

* Ecuación y topología del IIR de 1er orden
* Cálculo analítico del IPB del lazo crítico
* Discusión técnica sobre cómo reducir el IPB aplicando Shannon o C-Slow

> 💡 *El IPB impone el límite fundamental de throughput en sistemas con realimentación.*