# EJERCICIO 3: TRUNCADO - REDONDEO - SATURACIÓN

## ENUNCIADO


1) Se tiene x = 5,5625 en formato S(10, 6). Recortarlo a 
S(7, 3) por truncado y por redondeo.

Calcular el error en cada caso.

2) Se tiene y = 8,75 en formato S(11, 6). Recortarlo a S(5, 3) usando wrap-around y saturación.

Comparar los resultados.  // YO MODIFIQUE A 11 BITS NB


## RESOLUCION

### EJERCICIO 1

En principio se debe obtener la representacion del numero *x = 5,5625* en binario utilizando el formato S (10,6): x = 5,5625 = 0|101|100100.

* Por el metodo de truncado se quitan los bits menos significativos simplemente, existe un redondeo o sesgo hacia -infinito. S(7,3): x = 0|101|100 = 5,5. El error para este caso esta dado por: 5,5625 - 5,5 = *0,0625*.

* Por el metodo de redondeo, Debido a que el primer bit a descartar es 1, es necesario sumarle al siguiente bit (el de mayor peso) un bit puesto que esto nos indica que el redondeo debe ser hacia arriba para que el error sea minimo. x = 5,5625 = 0|101|100100 -> 0|101|101 = 5,625. El error para este caso esta dao por: 5,5625 - 5,625 = *-0.0625*.

* En términos absolutos es el mismo error para ambos métodos.

### EJERCICIO 2

Se obtiene primeramente la representación del número *y=8,75* en formato S(11,6): y = 8,75 = 0|1000|110000.

* Al recortarlo en formato S(5,3) utilizando la técnica Wrap-around lo que sucede es que se van descartando los MSB de acuerdo al ancho del recorte, S(5,3): 0|1000|110000 -> 0|0|110 = 0,75. Este metodo es poco predecible porque depende del recorte.

* En el caso de saturacion toma el maximo valor posible, S(5,3): 0|1|111 = 1,875. Este metodo es predecible porque en caso de overflow siempre va al máximo valor de representación posible.




*PROBLEMA CON EL EJERCICIO 2, NO PUEDO REPRESENTAR EL NRO CON LO QUE ME PIDE LA CONSIGNA, VOY A MODIFICARLO PARA QUE SEAN 11 BITS* 
