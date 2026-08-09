# Ejercicios Prácticos

## Ejercicio 1 — Conversión Float ↔ Fixed

### ENUNCIADO
Dado el número x = +9,625 en decimal:

(a) Representar x en IEEE 754 simple precisión (32 bits): signo, exponente y mantisa.  
(b) Representar x en punto fijo S(8, 3) [unsigned: U(8, 3) si conviene].  
(c) Calcular el error de cuantización al pasar de float a fixed.

### DATOS

- x = 9,625
- Formato float: IEEE 754 (S=1, E=8, M=23)
- Formato fixed: S(8, 3)

### ENTREGABLES

- Pasos de cada conversión
- Bits explícitos en ambos formatos
- Cálculo del error de cuantización en LSB y en valor absoluto

> 💡 *Normalizar primero el binario; recordar el sesgo 127 del exponente.*

---

## Ejercicio 2 — Suma en punto fijo

### ENUNCIADO

Dadas dos señales en formato signado:

- A = S(6, 4), valor: -1,75 (bits: 110010)
- B = S(8, 5), valor: +0,9375 (bits: 00011110)

(a) Determinar el formato S(NB_out, NBF_out) del resultado A + B.  
(b) Calcular la suma binaria alineada y verificar el resultado decimal.

### DATOS

- A: S(6, 4) → 110010
- B: S(8, 5) → 00011110
- Reglas: NBF_out = max, NBI_out = max + 1

### ENTREGABLES

- Bits de A y B alineados a la coma
- Suma en complemento a 2
- Verificación del valor decimal

> 💡 *Antes de sumar, extender signo y rellenar con ceros para alinear NBF.*

---

## Ejercicio 3 — Truncado, Redondeo y Saturación

### ENUNCIADO

Se tiene x = 5,5625 en formato S(10, 6).

(a) Recortar x a S(7, 3) por truncado y por redondeo. ¿Cuál es el error en cada caso?  
(b) Se tiene y = 8,75 en S(10, 6). Recortarlo a S(5, 3) usando wrap-around y saturación. ¿Cuál es el resultado en cada caso?

### DATOS

- x = 5,5625 en S(10, 6)
- y = 8,75 en S(10, 6)
- Destino x: S(7, 3)
- Destino y: S(5, 3)

### ENTREGABLES

- Bits y valores recortados
- Errores: trunc vs round
- Resultado: wrap vs saturación

> 💡 *Rango de S(5,3): [-2, +1,875]. Si y > 1,875 → overflow.*

---

## Ejercicio 4 — CSD — recodificación

### ENUNCIADO

Implementar la multiplicación por la constante K = 23 en hardware:

(a) Expresar K = 23 en binario estándar.  
(b) Recodificar K en CSD canónico (dígitos {-1, 0, +1}, sin no-ceros consecutivos).  
(c) Escribir la expresión Y = X · 23 como sumas/restas y shifts. Comparar la cantidad de sumadores en cada forma.

### DATOS

- K = 23
- Objetivo: minimizar cantidad de sumadores en Y = X · K

### ENTREGABLES

- K en binario
- K en CSD
- Expresión Y = X · K con shifts y ±
- Comparación de sumadores

> 💡 *Reglas CSD: reemplazar "0111" por "100-1" (= 8 - 1 = 7).*

---

## Ejercicio 5 — Booth radix-2

### ENUNCIADO

Multiplicar A · B usando el algoritmo de Booth radix-2:

- A = +6 (4 bits, C2)
- B = -5 (4 bits, C2)

(a) Expresar A y B en complemento a 2 (4 bits).  
(b) Aplicar Booth radix-2: tabla de pares (bᵢ, bᵢ₋₁), acción y producto parcial.  
(c) Verificar que el resultado coincide con A · B = -30.

### DATOS

- A = +6 (4 bits, C2)
- B = -5 (4 bits, C2)
- Agregar bit b₋₁ = 0

### ENTREGABLES

- Bits A, B en C2
- Tabla de pasos Booth
- Suma de productos parciales
- Verificación A · B = -30

> 💡 *Pares (bᵢ, bᵢ₋₁): 01 → +A<<i, 10 → -A<<i, 00/11 → 0.*

---

## Ejercicio 6 — RNS — multiplicación modular

### ENUNCIADO

Trabajando en RNS con módulos { 3, 5, 7 } (M = 105):

(a) Representar X = 14 e Y = 6 en RNS.  
(b) Calcular X · Y residuo a residuo, en paralelo.  
(c) Recomponer el resultado decimal y verificar que coincida con X · Y = 84.

### DATOS

- Módulos: {3, 5, 7}
- M = 3 · 5 · 7 = 105
- X = 14, Y = 6

### ENTREGABLES

- X e Y en RNS
- Producto modular residuo a residuo
- Recomposición (puede ser por inspección dado que 84 < 105)

> 💡 *cᵢ = (aᵢ · bᵢ) mod mᵢ, sin propagación de carry entre canales.*
