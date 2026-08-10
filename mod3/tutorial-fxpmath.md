# **Apéndice: Modelo de Referencia en Python (`fxpmath`) e Integración con SystemVerilog**

Los ejercicios 2 a 6 de esta colección implementan **testbenches self-checking**. En lugar de inspeccionar visualmente formas de onda en el visor de ondas, el entorno compara automáticamente la salida del **DUT** (*Device Under Test*) contra un modelo de referencia **Golden** generado en Python.

## **La Librería `fxpmath`**

La librería utilizada para modelar la aritmética es [`fxpmath`](https://francof2a.github.io/fxpmath/). Esta herramienta reproduce con exactitud la representación en punto fijo signado $S(NB, NBF)$, permitiendo un control fino sobre el desbordamiento (*overflow*) y el truncado/redondeo (*rounding*).

### Instalación

Compatible con Python $\ge 3.7$. No requiere compilación adicional (es Python puro apoyado en `NumPy`).

```bash
pip3 install --user fxpmath
```

### Uso Básico

```python
from fxpmath import Fxp

# Definición de x = +9.625 en S(8, 3)
x = Fxp(9.625, signed=True, n_word=8, n_frac=3)

print(x.bin())     # Resultado: '01001101'
print(x.hex())     # Resultado: '4d'
print(x.get_val()) # Resultado: 9.625
```

### Parámetros Principales del Constructor

| Parámetro | Valores | Descripción |
| --- | --- | --- |
| `signed` | `True` / `False` | Indica si la aritmética usa complemento a 2 o es sin signo. |
| `n_word` | entero $\ge 1$ | Número total de bits ($NB$). |
| `n_frac` | entero | Número de bits fraccionarios ($NBF$). |
| `overflow` | `"wrap"` / `"saturate"` | Estrategia ante desbordamiento de rango. |
| `rounding` | `"trunc"` / `"around"` | Estrategia para descartar bits LSB sobrantes. |

---

## **Ejemplos de Aritmética con `fxpmath`**

### Suma en Punto Fijo (Ejercicio 2)

```python
from fxpmath import Fxp

A = Fxp(-0.875, signed=True, n_word=6, n_frac=4)
B = Fxp(0.9375, signed=True, n_word=8, n_frac=5)

# Resultado de A + B
S = Fxp(A.get_val() + B.get_val(), signed=True, n_word=9, n_frac=5)
print(S.bin(), S.get_val()) # Output: 000000010 0.0625

```

### Truncado vs. Redondeo y Wrap vs. Saturación (Ejercicio 3)

```python
x = 5.5625

# Truncado + Wrap
tw = Fxp(x, signed=True, n_word=7, n_frac=3, overflow='wrap', rounding='trunc')

# Redondeo + Saturación
rs = Fxp(x, signed=True, n_word=7, n_frac=3, overflow='saturate', rounding='around')

print(tw.get_val(), rs.get_val()) # Output: 5.5 5.625

```

### Multiplicación Signada (Ejercicios 4 y 5)

```python
A = Fxp(6, signed=True, n_word=4)
B = Fxp(-5, signed=True, n_word=4)

P = Fxp(A.get_val() * B.get_val(), signed=True, n_word=8)
print(P.get_val()) # Output: -30

```

---

## **Flujo de Integración y Verificación (SystemVerilog / Verilog)**

1. `gen_vectors.py` crea los vectores de entrada (`a.hex`, `b.hex`, etc.) y las salidas doradas esperadas (`expected.hex`).
2. El Testbench en SystemVerilog usa `$readmemh` para cargar las memorias internas con estos vectores.
3. Para cada vector de prueba, el Testbench aplica el estímulo al RTL y compara la salida observada contra `expected.hex`.
4. El proceso concluye imprimiendo una directiva `PASS` o `FAIL` indicando la cantidad de aciertos y errores encontrados.

De esta forma, cada directorio de trabajo (`verilog/ejNN_xxx/`) cuenta con la siguiente estructura de archivos:

| Archivo | Función |
| --- | --- |
| `gen_vectors.py` | Genera los patrones de entrada y resultados esperados en archivos `.hex` usando `fxpmath`. |
| `*.v` / `*.sv` | Módulo RTL a verificar (Design Under Test). |
| `tb_*.v` / `tb_*.sv` | Testbench *self-checking* que lee los `.hex` y valida el hardware. |
| `run.sh` | Script de automatización: Generación $\rightarrow$ Compilación $\rightarrow$ Simulación $\rightarrow$ GTKWave. |

```
  ┌─────────────────┐
  │ gen_vectors.py  │
  └────────┬────────┘
           │ (Genera .hex)
           ▼
  ┌─────────────────┐      ┌──────────────────┐
  │   archivos.hex  ├─────►│ Testbench (.sv)  │◄────► [ RTL / DUT ]
  └─────────────────┘      └────────┬─────────┘
                                    │ (Verificación)
                                    ▼
                             PASS / FAIL

```

### Comandos de Ejecución

#### Ejecución Automática mediante Script

```bash
# Cobertura estándar
./run.sh

# Cobertura personalizada definiendo cantidad de vectores aleatorios
N_VECTORS=100 ./run.sh     # Modo rápido / Debug
N_VECTORS=10000 ./run.sh   # Modo exhaustivo

```

> *Nota:* En ejercicios donde el espacio de estados es acotado (como en los ejercicios 5 y 6), la generación por defecto cubre la totalidad de las combinaciones posibles ($256$ y $\sim 105$ casos respectivamente).

#### Comandos Manuales Paso a Paso

```bash
# 1. Generar vectores desde el Golden Model
python3 gen_vectors.py

# 2. Compilar con Icarus Verilog (Soporte para SystemVerilog con -g2012)
iverilog -g2012 -o sim.out tb_*.sv *.sv

# 3. Simular la verificación
vvp sim.out

# 4. Inspeccionar formas de onda en caso de error
gtkwave *.vcd &

```

---

## 5. Referencias

* **Documentación Oficial de `fxpmath`:** [https://francof2a.github.io/fxpmath/](https://francof2a.github.io/fxpmath/)
* **Repositorio de Código Fuente:** [https://github.com/francof2a/fxpmath](https://github.com/francof2a/fxpmath)
