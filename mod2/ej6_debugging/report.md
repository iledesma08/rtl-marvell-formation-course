# Analisis del bug generado en el archivo "alu_bad.v"
+ El problema que se genera en la descripción de la ALU realizada en el archivo: *"alu_bad.v"* (propuesto por el ejercicio), está dado por no asignarle un valor de salida a todos los casos de la sentencia case, o de lo contario un valor default. Este bug genera que en el caso donde la asignacion no está definida se mantenga el valor previo. Por el hecho de mantener el valor previo por mas que exista un cambio en la señal de control, el sintetizador infiere un *LATCH* y de alli el nombre al *BUG*. En el caso de la descripción propuesta por el ejercicio es que se definen 4 combinaciones o casos posibles (00,01,10,11) pero solo en 3 de ellos a la salida se le asigna un valor, el último (11) repite el valor anterior. El sintetizador la unica forma que tiene de darle un sentido a esto es infiriendo un *LATCH* en lugar de realizar una operación en función de las salidas.

+ La forma de solucionarlo es relativamente sencilla, se asigna un valor para todos los casos o se le da a la salida una salida predefinida antes de entrar a la sentencia case, lo que seria equivalente a un caso default.

* *REGLA DE ORO:* En logica combinacional, toda salida debe tener un valor definido para
cualquier combinacion de las entradas.
