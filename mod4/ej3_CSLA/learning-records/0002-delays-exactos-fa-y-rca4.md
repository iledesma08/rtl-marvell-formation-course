# Delays exactos del full_adder y del rca4 (medidos y verificados)

Se corrigió una confusión en la lección 1 sobre los delays del modelo de compuertas del curso (xor=2ns, and/or/not=1ns). Datos verificados con simulación en iverilog:

- En el FA: `cin → sum` = **2 ns** (una sola xor: `sum = p ^ cin`; el `cin` no pasa por las dos xors de `a ^ b ^ cin`). `cin → cout` = 2 ns (and+or). `a → sum` = 4 ns (dos xors en serie).
- En el rca4: camino del carry `cin → cout` = **8 ns** (4 × 2). `cin → sum[3]` = 8 ns (la suma del último bit sale junto con el carry, en paralelo, no después). El peor caso del bloque (~10 ns, el que espera el testbench) ocurre cuando el carry lo arranca el bit 0 desde `a/b`: primer salto hasta 4 ns (xor+and+or) + 3 × 2 ns.

Implicación para futuras sesiones: al explicar el path crítico del CSLA (lección 4-6) hay que usar estos números — bloque0 ≈ 8-10 ns + 3 muxes ≈ 16 ns medidos — y no repetir el error de sumar un "xor final" al camino del carry (el xor de la suma va en paralelo con la última etapa del carry).