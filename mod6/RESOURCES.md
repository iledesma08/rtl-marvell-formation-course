# Módulo 6 — Recursos (Ej. 1–5: FIR, DFG, scheduling, folding, pipeline, PPA)

## Knowledge

- [Libro: *VLSI Digital Signal Processing Systems* — K. K. Parhi](https://www.wiley.com/en-us/VLSI+Digital+Signal+Processing+Systems%3A+Design+and+Implementation-p-9780471241867)
  Texto canónico del módulo: DFG, ASAP/ALAP, folding, pipelining con cut-set, IPB. Usar para: toda afirmación de scheduling y transformaciones.
- [Libro: *Digital Signal Processing* — Proakis & Manolakis](https://www.pearson.com/en-us/subject-catalog/p/digital-signal-processing-principles-algorithms-and-applications/P200000003465)
  Referencia de filtros FIR, convolución discreta y forma directa. Usar para: ecuación y[n]=Σh·x[n−k] y tapped delay line.
- [Apuntes del curso: README ej1_DFG, ej2_ASAP-ALAP, ej3_folding, ej4_Cut-Set, ej5_Comparacion](./enunciados.md)
  Fuente primaria local del trabajo a presentar. Usar para: datos, tablas y resultados a defender (latencia 4/5/6, Tcrit, PPA).
- [Artículo: "High-Level Synthesis scheduling" — documentação Vivado HLS / Vitis HLS](https://docs.amd.com/)
  Puente industria: ASAP/ALAP y movilidad aplicados en HLS real. Usar para: mostrar que lo manual del ej. 2 es lo que automatiza HLS.

## Wisdom (Communities)

- Consultas en clase del curso Marvell / grupo de estudio — usar para: ensayar la presentación y recibir preguntas tipo examen.
- [r/FPGA](https://www.reddit.com/r/FPGA/) — foro activo con moderación razonable. Usar para: dudas de pipeline/folding en hardware real.

## Gaps

- Sin fuente local única que tabule costos de área en celdas para 8×8 mult / sumador 18b: las cifras del ej. 5 son estimaciones relativas, no síntesis.
