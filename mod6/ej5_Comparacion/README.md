# Ejercicio 5:  Comparación: FIR folded (Ej. 3) vs FIR pipelineado (Ej. 4)

| Métrica | Versión Folded (1×, 1+ compartidos) | Versión Pipelineada (cut-set, 2 registros) |
|---|---|---|
| **Latencia** | 6 ciclos (`in_valid → out_valid`) | 5 registros de atraso (3 de la línea de retardo original + 2 del cut-set) |
| **Throughput** | $1/5$ muestras/ciclo (limitado por el multiplicador compartido, que se reutiliza 4 veces por muestra) | En régimen (pipeline lleno), 1 muestra por ciclo de reloj → throughput $= F_{max} = 1/T_{crit} = 1/4$ (en u.t.) |
| **Área** | Mínima: **1 multiplicador 8×8** (~64 celdas) + **1 sumador 18 bits** (~18 celdas) + registros de control/estado | Mayor: **4 multiplicadores 8×8** (~256 celdas) + **3 sumadores** + 2 registros extra de pipeline |
| **Potencia** | Menor (correlaciona con el área: menos celdas activas, menos capacidad conmutada por ciclo) | Mayor (más multiplicadores y sumadores trabajando en paralelo, mayor capacidad total conmutando por ciclo, aunque corra a mayor $F_{max}$) |

## Lectura del trade-off

- **Folded** gana en área y potencia porque resuelve todo el filtro con solo 2 operadores físicos, pagando el costo en throughput (serializa las 4 multiplicaciones) y en latencia (necesita ciclos extra de control/FSM para orquestar la reutilización).
- **Pipeline** gana en throughput porque una vez lleno el pipeline entrega una muestra por ciclo, a costa de replicar hardware (4 multiplicadores en vez de 1) — de ahí el mayor área y, en consecuencia, mayor potencia estimada.
- Ambas técnicas atacan objetivos distintos del mismo DFG: folding optimiza **área/potencia** sacrificando velocidad; pipelining optimiza **velocidad/throughput** sacrificando área/potencia. No son excluyentes.