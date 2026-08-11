# NOTAS DEL RTL, MODELO Y RUN

* Esta pensado el RTL para trabajar con bit de magnitud-signo en lugar de C2.

* Como el RTL está pensado con valores fijos de ancho de formato y el ejercicio solicita dos puntos de distintos anchos, para poder realizar la prueba correctamente fue necesario diferenciar en el script de python 2 tipos de vectores a generar, con distinto ancho, de acuerdo a la operación que se desee realizar. Por ello tambien fue necesario dos archivos de Tb, que son compilados y ejecutados por separado en RUN.sh a causa de que ambos contienen $finish que es global. 

* Sin embargo, el resultado es el esperado: 2048/2048 vectores PASS en 
truncamiento/redondeo, y 4096/4096 vectores PASS en saturacion/wrap-around.