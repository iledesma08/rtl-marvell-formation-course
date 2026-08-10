# EJERCICIO NRO 1 - Conversion de float a fixed

## ENUNCIADO
Dado el número x = +9,625 en decimal:
1) Representar x en IEEE 754 simple precisión (32 bits): signo, exponente y mantisa.

2) Representar x en punto fijo S(8, 3).

3) Calcular el error de cuantización al pasar de float a fixed.



## RESOLUCION

### PUNTO 1:

Para la represetación de un número en numero flotante IEEE 754 se debe tener en cuenta la distribución y asignación de bits. La representación de precision simple esta conformada por 32 bits, el *MSB* (bit mas significativo) es el que representa el signo del número, los 8 bits siguientes representan al exponentes y los 23 restantes es la mantisa que es el número fijo al que se escala por el exponente. 

* Para representar el numero *x = 9,625* en representación de punto flotante primero se debe obtener su representación binaria: x = 9,625 = 1001,101. 

* Luego se normaliza para obtener el exponente: 1,001101 * 2^3

* La mantisa esta conformado por 001101, el exponente esta conformado por 3 + 127 = 130 = 1000 0010 de sesgo y el bit de signo es igual a 0 (positivo).

* El resultado final esta dado por: 

    x = 9,625 = 0 | 1000 0010 | 00110100000000000000000 

* NOTA: El sesgo es utilizado para poder representar de forma simplificada (para el hardware) los exponentes negativos sin utilizar bit de signo.


### PUNTO 2

Para la representación en punto fijo es necesario primeramente definir la cantidad de bits que se va a utilizar en total para la representación (NB), la cantidad de bits para la parte fraccional (NBF), la cantidad de bits para la parte entera (NBI) y si el número es signado o no. El ejercicio ya provee esto, *S(8, 3)*, el número debe ser signado, tiene 8 bits de representación y 3 corresponden a la representación fraccional lo que deja 4 para la representación entera puesto que el MSB es el de signo. 

* Para la representación de x = 9,625 primeramente definimos el bit de signo, MSB=0.

* Luego se define la parte entera: 9 = 1001 (es posible con 4 bits).

* Por ultimo la parte fraccional: 0.625=101 (es posible con 3 bits).

* Al uner los 3 puntos anteriores: x = 9,625 = 0|1001|101.


### PUNTO 3

Para obtener el error de cuantización debemos realizar la diferencia entre el numero representado con representación de punto flotante y el de representación de punto fijo, puesto que para ninguno de los dos fue necesario ni el redondeo, truncamiento o saturación, los numeros representados son iguales

 * Para el caso de representación de punto flotante: 0 | 1000 0010 | 00110100000000000000000 = 
 1,001101 * 2^3 = 1001,101 = 9,625.

 * Para la representación de punto fijo : 0|1001|101 = 9,625.

 * x(punto flotante) - x(punto fijo) = 9.625 - 9.625 = 0.

 El error de cuantización es 0. Esto porque el numero fraccional es representado de forma correcta con 3 bits fraccionales, por esto es que no se requirio de ninguna tecnica de cuantización para representarlo (como truncamiento o redondeo). El erro de cauntización es 0 en LSB y en valor absoluto igual.

