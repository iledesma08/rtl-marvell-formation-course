# Misión: Presentar el ejercicio CSLA (Carry Select Adder) del curso Marvell

## Por qué
El usuario tiene que presentar el ejercicio 3 (CSLA de 16 bits en bloques de 4) del módulo 4 del curso de diseño RTL de Marvell: mostrar y explicar el código, correr la simulación, explicar los resultados comparando con los ejercicios 1 (RCA) y 2 (CLA), y responder preguntas del profesor, tanto teóricas como de implementación. Parte desde cero en arquitecturas de sumadores, así que necesita construir el entendimiento desde la base para defender el trabajo con confianza.

## El éxito se ve así
- Explicar `csla16.sv` y `rca4.sv` línea por línea, incluido el `generate-for`, los part-selects y el mux estructural
- Correr `./run.sh` y explicar cada parte de la salida (verificación, cross-check, tabla comparativa, conteo de gates con Yosys)
- Explicar el path crítico del CSLA (un RCA de 4 bits + 3 muxes) y por qué es O(√N) en lugar de O(N)
- Defender la comparación CSLA vs CLA vs RCA en delay y área, y dar una recomendación de arquitectura
- Responder preguntas tipo: ¿por qué el bloque 0 no lleva mux?, ¿por qué dos RCAs por bloque?, ¿qué es la suma especulativa?, ¿qué pasa si cambio el tamaño de bloque?, ¿cuánto área se paga?

## Restricciones
- Presentación esta semana (dedicación full-time disponible)
- Parte desde cero: no domina RCA/CLA/CSLA todavía
- Quiere teoría + código + verificación juntos, sin prioridad entre ellos
- Material de estudio en español; los términos técnicos en inglés cuando el código los usa
- Tiempo de cada lección corto: mejor varias lecciones breves que una larga

## Fuera de alcance
- Multiplicadores (ejercicios 4 a 6 del módulo)
- Síntesis con herramientas ASIC/FPGA reales
- Verilog avanzado ajeno a este ejercicio