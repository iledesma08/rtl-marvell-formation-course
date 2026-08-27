# Notas de enseñanza

## Preferencias del usuario
- Idioma: español (términos técnicos en inglés cuando el código los usa).
- Parte desde cero en arquitecturas de sumadores; no re-asumir conocimiento de RCA/CLA.
- Presentación esta semana, dedicación full-time. Lecciones cortas y accionables.
- Quiere teoría + código + verificación mezclados; cada lección debe aterrizar en "qué decir en la presentación".
- Quiere poder responder preguntas del profesor: cubrir el "por qué" de cada decisión de implementación (por qué sin mux en bloque 0, por qué estructural, por qué delays de 1ns, etc.).
- Tiene los ejercicios 1 y 2 resueltos (RCA, CLA v1/v2) y el tb del ej3 cross-checkea contra ellos: usarlos como anclas.

## Plan de lecciones (esquema)
1. ✅ Suma binaria, FA, RCA y el path crítico (O(N)) — la base del problema.
2. ✅ Generate/Propagate y CLA (O(log N)) — por qué el CLA ya mejora.
3. ✅ La idea del CSLA: suma especulativa, mux de selección, estructura de bloques.
4. ✅ El código de csla16.sv / rca4.sv línea por línea (generate-for, part-selects, mux estructural, delays).
5. ✅ Verificación: tb_csla.sv, exhaustivo/random, cross-check, medición de delay y conteo de gates.
6. ✅ Comparativa final CSLA vs CLA vs RCA + cómo armar la presentación y responder preguntas.

## Para recordar
- Los delays del modelo son xor=2ns, and/or/not=1ns (ej1). Todo delay se deriva de ahí.
- Tabla medida con `./run.sh` (peor caso 0xFFFF+1, delays en ns):
  | Arq | cout | sum[15] | gates |
  |-----|------|---------|-------|
  | CSLA16 | 16 | 17 | 200 |
  | CLA16 v1 | 17 | 19 | 140 |
  | CLA16 v2 | 13 | 16 | 167 |
  | RCA16 | 32 | 32 | 80 |
- Conteo de gates verificado con Yosys: CSLA=200, CLA v1=140, CLA v2=167, RCA=80. OK en run.sh.
- El RCA4 del bloque estabiliza en ~10 ns (4×2 carry + xor final).