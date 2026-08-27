# Recursos — Sumadores binarios y Carry Select Adder

## Conocimiento

- [Wikipedia: Carry-select adder](https://en.wikipedia.org/wiki/Carry-select_adder)
  La construcción del CSLA, el bloque básico (dos RCAs + mux), uniform vs variable sizing, y por qué el delay es O(√n). Uso: teoría de fondo del ejercicio.
- [Wikipedia: Carry-lookahead adder](https://en.wikipedia.org/wiki/Carry-lookahead_adder)
  Generate/propagate y el análisis de gate-delay de un CLA16. Uso: base para comparar con el CLA del ejercicio 2.
- [Wikipedia: Ripple-carry adder](https://en.wikipedia.org/wiki/Ripple-carry_adder)
  Qué es el ripple, por qué el peor caso obliga a recorrer los N bits. Uso: lección 1.
- [EcrioniX — Carry Propagation Adder](https://ecrionix.org/digital-electronics/carry-propagation-adder)
  RCA/CLA/CSLA explicados con Verilog y tabla de delay/área comparativa. Uso: referencia rápida y ejemplos de código.
- [EcrioniX — Half Adder & Full Adder](https://ecrionix.org/digital-electronics/adders)
  Truth tables, circuitos y Verilog de HA/FA. Uso: lección 1.
- [vlsi-notes — Carry select adder](https://ahegazy.github.io/vlsi-notes/arithmetic-circuits/5-carry-select-adder.html)
  Notas de clase VLSI sobre el CSLA: sacrificar área por performance, dos cadenas de ripple por bloque. Uso: lección 3.
- [Weste & Harris, _CMOS VLSI Design_](https://www.cmosvlsi.com/)
  Capítulo de arithmetic circuits: RCA/CLA/CSLA con fórmulas de delay y área, modelos de gate delay. Uso: fundamento riguroso de delay y path crítico.
- [Parhami, _Computer Arithmetic: Algorithms and Hardware Designs_](https://www.amazon.com/Computer-Arithmetic-Hardware-Behrooz-Parhami/dp/0195125835)
  Tratamiento formal de sumadores y carry. Uso: profundización si el profesor pregunta algo muy teórico.

## Sabiduría (Comunidades)

- Aún no hay comunidades. El usuario no pidió sumarse a ninguna; si aparece una pregunta que requiera sabiduría real (p. ej. "¿cómo se implementa esto en un producto real?"), buscar foros de diseño digital (r/chipdesign, Stack Overflow de Verilog) y proponérselos.

## Gaps

- Material específico sobre presentar este ejercicio al profesor: se cubre con las secciones "Para tu presentación" de cada lección, derivadas de los archivos del repo.
- No hay fuente dedicada al conteo estructural de gates como lo hace `run.sh` con Yosys; se documenta en la lección de verificación con el propio `run.sh` como fuente.