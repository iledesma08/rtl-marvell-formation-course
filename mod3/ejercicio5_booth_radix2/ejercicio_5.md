# EJERCICIO 3 - Booth Radix-2

## ENUNCIADO

Multiplicar A · B usando el algoritmo de Booth radix-2 con:
A = +6 (4 bits, C2)
B = −5 (4 bits, C2)

1) Expresar A y B en complemento a 2 (4 bits).

2) Aplicar Booth radix-2: tabla de pares (bi , bi−1), acción y producto parcial.

3) Verificar que el resultado coincide con A · B = −30.

## EXPLICACION

 El algoritmo de Booth examina pares de bits adyacentes en representación de complemento a 2 con signo, ademas incluye un bit implicito a la derecha del bit menos significativo igual a 0. Se va recorriendo el numero binario desde sus bits menos significativos hasta el MSB, se toma de pares adyacentes (b(i) y b(i-1)), cuando estos bits son iguales el acumulador de producto permanece constate (no se suma nada). Si la combinacion formada es "10" (b(i)=1,b(i-1)=0), el multiplicando (A para nuestro caso) se resta multiplicandose por 2^i; si la combinación obtenida fuese "01" (b(i)=0,b(i-1)=1) sucede lo anterior pero con una suma en lugar de una suma. 

## RESOLUCIÓN

### EJERCICIO 1

* Para la representación de un numero binario en su complemento a 2 el MSB bit determina su signo (0 positivo, 1 negativo) y para hacer el paso de positiva <-> negativo es necesario hacer la inversión de todos los bits y sumarle 1.

* A = *0110*

* B = 0101 (+5) -> 1010 -> *1011 (-5)* 

### EJERCICIO 2

* Tabla de accion:

| bᵢ bᵢ₋₁ | Acción        |
|---------|---------------|
| 0 0     | No hacer nada |
| 0 1     | Sumar A       |
| 1 0     | Restar A      |
| 1 1     | No hacer nada |

* Algoritmo:

| bᵢ bᵢ₋₁ |  Operación  |   Acción     |
|---------|-------------|--------------|
| 1 0     |   -A<<0     |-6            |
| 1 1     |     0       |0             |
| 0 1     |   A<<2      |6*2^2= 24     |
| 1 0     |   -A<<3     |-6* 2^3= -48  |

* Acumulación final:

P = -6 + 24 - 48 = *-30* -> Verificado con el planteado por el ejercicio

* Representación binaria:

P = 011110 (30) -> 100001 -> *11100010 (-30)*