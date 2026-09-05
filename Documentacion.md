# Documentación de la implementación

## Codificador Educativo de Instrucciones RISC-V

Proyecto Individual  
CE-4301 Arquitectura de Computadores I
José Daniel González Chaves
2022279667
---

## 1. Descripción de la arquitectura del código y decisiones de diseño

### 1.1 Descripción general

La herramienta desarrollada codifica un subconjunto de 12 instrucciones de la arquitectura RISC-V RV32I. A partir de una instrucción escrita en lenguaje ensamblador, el programa identifica su formato, interpreta sus operandos y construye la palabra de instrucción de 32 bits correspondiente.

Las instrucciones soportadas son:

| Instrucción | Formato |
|---|---|
| `add` | R |
| `sub` | R |
| `and` | R |
| `or` | R |
| `addi` | I |
| `andi` | I |
| `lw` | I |
| `lb` | I |
| `sw` | S |
| `sb` | S |
| `beq` | B |
| `bne` | B |

La implementación principal se encuentra en el archivo `encoder_skeleton.py`.

El programa se dividió en varias funciones con responsabilidades específicas. Esto permite separar la interpretación de los operandos, la codificación de la instrucción y la generación de la salida explicativa.

---

### 1.2 Tabla de instrucciones

Los datos constantes de las instrucciones se almacenan en el diccionario `INSTRUCTIONS`.

Cada entrada contiene:

- El formato de la instrucción
- El `opcode`
- El campo `funct3`
- El campo `funct7`, cuando corresponde

Por ejemplo, para `add` se almacena:

```python
"add": {
    "format": "R",
    "opcode": 0b0110011,
    "funct3": 0b000,
    "funct7": 0b0000000,
}
```

Se tomó la decisión de almacenar esta información en una única estructura para separar los valores definidos por la ISA de la lógica utilizada para construir las palabras de 32 bits.

Esto evita repetir los valores de `opcode`, `funct3` y `funct7` en diferentes partes del programa y facilita identificar el formato correspondiente a cada instrucción.

---

### 1.3 Interpretación de registros

La función:

```python
parse_register()
```

interpreta registros escritos con la sintaxis:

```text
x0
x1
...
x31
```

La función elimina espacios, comprueba que el operando comience con `x`, convierte la parte numérica a entero y verifica que el número esté en el rango permitido.

El rango válido es:

```text
x0 <= registro <= x31
```

Si el registro no cumple estas condiciones, se genera un `ValueError`.

Los registros se representan mediante campos de 5 bits debido a que:

```text
2^5 = 32
```

por lo que es posible identificar los 32 registros de propósito general de RV32I.

---

### 1.4 Interpretación de inmediatos

La función:

```python
parse_immediate()
```

se utiliza para interpretar los valores inmediatos de las instrucciones de formato I y S.

Los inmediatos utilizados por estas instrucciones tienen 12 bits con signo, por lo que el rango aceptado es:

```text
-2048 a 2047
```

La función también permite interpretar números escritos en diferentes bases mediante:

```python
int(text, 0)
```

Para colocar un inmediato con signo dentro de una palabra binaria se conservan únicamente sus 12 bits inferiores:

```python
imm12 = imm & 0xFFF
```

La máscara `0xFFF` corresponde a 12 bits en uno:

```text
111111111111
```

Este procedimiento también permite obtener correctamente la representación en complemento a dos de los inmediatos negativos.

---

### 1.5 Interpretación de operandos de memoria

Las instrucciones:

```text
lw
lb
sw
sb
```

utilizan operandos de la forma:

```text
desplazamiento(registro)
```

Por ejemplo:

```text
8(x30)
```

La función:

```python
parse_memory_operand()
```

separa este operando en dos componentes:

```text
inmediato = 8
registro base = x30
```

Después reutiliza las funciones `parse_immediate()` y `parse_register()` para validar ambos valores.

Esta decisión evita duplicar la lógica de validación utilizada en otras partes del programa.

---

### 1.6 Interpretación de desplazamientos de branch

Las instrucciones:

```text
beq
bne
```

utilizan un desplazamiento relativo al contador de programa.

La función:

```python
parse_branch_immediate()
```

comprueba que dicho desplazamiento se encuentre en el rango:

```text
-4096 a 4094 bytes
```

y que sea múltiplo de 2.

Esto se debe a que el bit menos significativo del desplazamiento no se almacena explícitamente en el formato B.

---

### 1.7 Codificación del formato R

Las instrucciones implementadas en formato R son:

```text
add
sub
and
or
```

La distribución de los campos es:

```text
31          25 24      20 19      15 14    12 11       7 6        0
+-------------+----------+----------+--------+----------+----------+
|   funct7    |   rs2    |   rs1    | funct3 |    rd    |  opcode  |
+-------------+----------+----------+--------+----------+----------+
```

Los campos se colocan dentro de la palabra utilizando desplazamientos de bits:

```python
word = (
    (info["funct7"] << 25)
    | (rs2 << 20)
    | (rs1 << 15)
    | (info["funct3"] << 12)
    | (rd << 7)
    | info["opcode"]
)
```

El operador `<<` desplaza cada campo hasta su posición correspondiente y el operador OR bit a bit `|` combina los campos para formar una única palabra de 32 bits.

---

### 1.8 Codificación del formato I

Las instrucciones implementadas en formato I son:

```text
addi
andi
lw
lb
```

La distribución utilizada es:

```text
31                    20 19      15 14    12 11       7 6        0
+-----------------------+----------+--------+----------+----------+
|       imm[11:0]       |   rs1    | funct3 |    rd    |  opcode  |
+-----------------------+----------+--------+----------+----------+
```

Para `addi` y `andi`, los operandos tienen la forma:

```text
instruccion rd, rs1, inmediato
```

Por ejemplo:

```text
addi x10, x1, -12
```

Para `lw` y `lb` se utiliza:

```text
instruccion rd, desplazamiento(rs1)
```

Por ejemplo:

```text
lw x29, 8(x30)
```

Una vez obtenidos `rd`, `rs1` y el inmediato, las cuatro instrucciones utilizan el mismo procedimiento para construir la palabra:

```python
word = (
    (imm12 << 20)
    | (rs1 << 15)
    | (info["funct3"] << 12)
    | (rd << 7)
    | info["opcode"]
)
```

---

### 1.9 Codificación del formato S

Las instrucciones implementadas en formato S son:

```text
sw
sb
```

La distribución de los campos es:

```text
31          25 24      20 19      15 14    12 11       7 6        0
+-------------+----------+----------+--------+----------+----------+
|  imm[11:5]  |   rs2    |   rs1    | funct3 | imm[4:0] |  opcode  |
+-------------+----------+----------+--------+----------+----------+
```

A diferencia del formato I, el inmediato se divide en dos partes.

Primero se genera su representación de 12 bits:

```python
imm12 = imm & 0xFFF
```

Después se separan sus campos:

```python
imm_11_5 = (imm12 >> 5) & 0b1111111
imm_4_0 = imm12 & 0b11111
```

Finalmente se construye la palabra:

```python
word = (
    (imm_11_5 << 25)
    | (rs2 << 20)
    | (rs1 << 15)
    | (info["funct3"] << 12)
    | (imm_4_0 << 7)
    | info["opcode"]
)
```

En las instrucciones de almacenamiento, `rs2` contiene el dato que será almacenado y `rs1` contiene la dirección base de memoria.

---

### 1.10 Codificación del formato B

Las instrucciones implementadas en formato B son:

```text
beq
bne
```

La distribución del formato es:

```text
31 30          25 24      20 19      15 14    12 11        8 7 6        0
+--+--------------+----------+----------+--------+-----------+-+----------+
|12|  imm[10:5]   |   rs2    |   rs1    | funct3 | imm[4:1] |11| opcode  |
+--+--------------+----------+----------+--------+-----------+-+----------+
```

El inmediato del formato B utiliza 13 bits conceptuales, pero el bit 0 no se almacena debido a que el desplazamiento es múltiplo de 2.

La representación de 13 bits se obtiene mediante:

```python
imm13 = imm & 0x1FFF
```

Los diferentes componentes se extraen de la siguiente forma:

```python
imm_12 = (imm13 >> 12) & 0b1
imm_10_5 = (imm13 >> 5) & 0b111111
imm_4_1 = (imm13 >> 1) & 0b1111
imm_11 = (imm13 >> 11) & 0b1
```

Después se colocan en las posiciones definidas por el formato B:

```python
word = (
    (imm_12 << 31)
    | (imm_10_5 << 25)
    | (rs2 << 20)
    | (rs1 << 15)
    | (info["funct3"] << 12)
    | (imm_4_1 << 8)
    | (imm_11 << 7)
    | info["opcode"]
)
```

El formato B requirió un tratamiento particular debido a que los bits del inmediato no aparecen almacenados de manera consecutiva dentro de la instrucción.

---

### 1.11 Generación de la salida explicativa

La función:

```python
explain_instruction()
```

genera la salida educativa de la herramienta.

En lugar de utilizar únicamente los operandos obtenidos inicialmente, la función extrae nuevamente los campos desde la palabra de 32 bits ya codificada.

Para ello se utilizan desplazamientos y máscaras.

Por ejemplo, en formato R:

```python
rd = (word >> 7) & 0b11111
funct3 = (word >> 12) & 0b111
rs1 = (word >> 15) & 0b11111
rs2 = (word >> 20) & 0b11111
funct7 = (word >> 25) & 0b1111111
```

Esta decisión permite que la explicación mostrada corresponda directamente con los bits que realmente fueron generados.

La salida incluye:

- Formato de la instrucción
- Palabra binaria completa de 32 bits
- Posiciones de los campos
- Valores binarios
- Registros asociados
- Valores inmediatos
- Función de cada campo
- Codificación hexadecimal

La línea final tiene el formato requerido:

```text
HEX: 0xXXXXXXXX
```

---

### 1.12 Flujo general del programa

El flujo de ejecución puede resumirse de la siguiente forma:

```text
Instrucción ingresada
        |
        v
Separación de operandos
        |
        v
Identificación del mnemónico
        |
        v
Consulta de INSTRUCTIONS
        |
        v
Identificación del formato
   R / I / S / B
        |
        v
Interpretación y validación
de registros e inmediatos
        |
        v
Construcción de los 32 bits
        |
        v
Generación de explicación
        |
        v
HEX: 0xXXXXXXXX
```

---

## 2. Fuentes consultadas para los campos de codificación

La principal referencia utilizada para determinar los formatos de instrucción y los valores de `opcode`, `funct3` y `funct7` fue la especificación oficial de RISC-V.

### 2.1 Fuente principal

**RISC-V International**, *The RISC-V Instruction Set Manual, Volume I: Unprivileged Architecture*, sección **RV32I Base Integer Instruction Set, Version 2.1**.

La documentación oficial establece los formatos de instrucciones de 32 bits y las codificaciones utilizadas por las instrucciones de la ISA RV32I.

También se utilizó la tabla oficial **RV32/64G Instruction Set Listings** para comprobar los campos correspondientes a las instrucciones implementadas.

La documentación puede consultarse en el sitio oficial de especificaciones de **RISC-V International, docs.riscv.org**.

---

### 2.2 Campos utilizados

Los valores implementados fueron:

| Instrucción | Formato | opcode | funct3 | funct7 |
|---|---|---|---|---|
| `add` | R | `0110011` | `000` | `0000000` |
| `sub` | R | `0110011` | `000` | `0100000` |
| `and` | R | `0110011` | `111` | `0000000` |
| `or` | R | `0110011` | `110` | `0000000` |
| `addi` | I | `0010011` | `000` | No aplica |
| `andi` | I | `0010011` | `111` | No aplica |
| `lw` | I | `0000011` | `010` | No aplica |
| `lb` | I | `0000011` | `000` | No aplica |
| `sw` | S | `0100011` | `010` | No aplica |
| `sb` | S | `0100011` | `000` | No aplica |
| `beq` | B | `1100011` | `000` | No aplica |
| `bne` | B | `1100011` | `001` | No aplica |

---

### 2.3 Formatos utilizados

#### Formato R

```text
funct7 | rs2 | rs1 | funct3 | rd | opcode
31:25    24:20 19:15 14:12    11:7 6:0
```

#### Formato I

```text
imm[11:0] | rs1 | funct3 | rd | opcode
31:20       19:15 14:12    11:7 6:0
```

#### Formato S

```text
imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode
31:25       24:20 19:15 14:12    11:7       6:0
```

#### Formato B

```text
imm[12] | imm[10:5] | rs2 | rs1 | funct3 | imm[4:1] | imm[11] | opcode
31        30:25       24:20 19:15 14:12    11:8       7         6:0
```

---

## 3. Ejemplos de salida explicativa

Se presenta un ejemplo para cada uno de los cuatro formatos implementados.

---

### 3.1 Ejemplo de formato R

Comando:

```bash
./run.sh "add x5, x6, x7"
```

Salida:

```text
Formato: R
Binario: 00000000011100110000001010110011

funct7 [31:25] = 0000000
  -> Ayuda a identificar la operación add
rs2    [24:20] = 00111 (x7)
  -> x7 es el segundo registro fuente
rs1    [19:15] = 00110 (x6)
  -> x6 es el primer registro fuente
funct3 [14:12] = 000
  -> Ayuda a seleccionar la operación add
rd     [11:7]  = 00101 (x5)
  -> x5 recibe el resultado de la operación
opcode [6:0]   = 0110011
  -> Identifica la familia de instrucciones registro-registro

HEX: 0x007302b3
```

---

### 3.2 Ejemplo de formato I

Comando:

```bash
./run.sh "addi x10, x1, -12"
```

Salida:

```text
Formato: I
Binario: 11111111010000001000010100010011

imm    [31:20] = 111111110100 (-12)
  -> Valor inmediato con signo utilizado por addi
rs1    [19:15] = 00001 (x1)
  -> x1 es el registro fuente
funct3 [14:12] = 000
  -> Selecciona la operación específica addi
rd     [11:7]  = 01010 (x10)
  -> x10 recibe el resultado de la operación
opcode [6:0]   = 0010011
  -> Identifica la familia de la instrucción

HEX: 0xff408513
```

---

### 3.3 Ejemplo de formato S

Comando:

```bash
./run.sh "sw x8, -4(x2)"
```

Salida:

```text
Formato: S
Binario: 11111110100000010010111000100011

imm[11:5] [31:25] = 1111111
  -> Parte superior del desplazamiento -4
rs2       [24:20] = 01000 (x8)
  -> x8 contiene el dato que se almacena en memoria
rs1       [19:15] = 00010 (x2)
  -> x2 contiene la dirección base de memoria
funct3    [14:12] = 010
  -> Selecciona la operación específica sw
imm[4:0]  [11:7]  = 11100
  -> Parte inferior del desplazamiento -4
opcode    [6:0]   = 0100011
  -> Identifica la familia de instrucciones de almacenamiento

Inmediato reconstruido: 111111111100 (-4)
Dirección efectiva: x2 + (-4)

HEX: 0xfe812e23
```

---

### 3.4 Ejemplo de formato B

Comando:

```bash
./run.sh "beq x1, x2, 8"
```

Salida:

```text
Formato: B
Binario: 00000000001000001000010001100011

imm[12]    [31]    = 0
  -> Bit de signo del desplazamiento
imm[10:5] [30:25] = 000000
  -> Parte del desplazamiento del salto
rs2       [24:20] = 00010 (x2)
  -> Segundo registro utilizado en la comparación
rs1       [19:15] = 00001 (x1)
  -> Primer registro utilizado en la comparación
funct3    [14:12] = 000
  -> Selecciona la operación beq
imm[4:1]  [11:8]  = 0100
  -> Parte del desplazamiento del salto
imm[11]   [7]     = 0
  -> Bit reubicado del desplazamiento
opcode    [6:0]   = 1100011
  -> Identifica la familia de saltos condicionales

Inmediato reconstruido: 0000000001000 (8)
Condición: salta si x1 == x2
Destino: PC + (8) bytes

HEX: 0x00208463
```

---

## 4. Evidencia de la validación contra el toolchain oficial

### 4.1 Metodología de validación

La codificación producida por la herramienta fue comparada con el resultado generado por las herramientas GNU para RISC-V.

Se utilizaron:

```text
riscv64-unknown-elf-as
riscv64-unknown-elf-objdump
```

El ensamblador fue configurado específicamente para RV32I mediante:

```text
-march=rv32i
-mabi=ilp32
```

Para cada caso de prueba se realizaron los siguientes pasos:

1. Se ejecutó la instrucción utilizando el codificador desarrollado.
2. Se obtuvo la línea `HEX: 0xXXXXXXXX`.
3. Se generó un pequeño archivo en ensamblador con la misma instrucción.
4. El archivo fue ensamblado utilizando GNU RISC-V.
5. Se obtuvo la codificación mediante `objdump`.
6. Se compararon ambas codificaciones.
7. El caso fue marcado como `PASS` si ambas coincidían.

Este procedimiento se automatizó mediante el archivo:

```text
validar.sh
```

Los casos utilizados se encuentran en:

```text
casos_prueba.txt
```

y la evidencia completa de ejecución se almacenó en:

```text
evidencia_validacion.txt
```

---

### 4.2 Casos de prueba

Se diseñaron 36 casos propios:

```text
12 instrucciones x 3 casos por instrucción = 36 casos
```

Los casos fueron diferentes a los vectores de ejemplo suministrados con el proyecto.

La selección buscó comprobar diferentes situaciones según el formato.

| Instrucción | Caso 1 | Caso 2 | Caso 3 |
|---|---|---|---|
| `add` | `add x0, x1, x2` | `add x31, x0, x30` | `add x15, x15, x15` |
| `sub` | `sub x0, x31, x1` | `sub x31, x31, x31` | `sub x12, x0, x8` |
| `and` | `and x0, x0, x0` | `and x31, x30, x29` | `and x13, x13, x4` |
| `or` | `or x31, x0, x1` | `or x0, x31, x30` | `or x17, x17, x17` |
| `addi` | `addi x5, x6, 25` | `addi x10, x1, -25` | `addi x31, x0, -2048` |
| `andi` | `andi x4, x5, 127` | `andi x20, x7, -1` | `andi x0, x31, 2047` |
| `lw` | `lw x5, 16(x6)` | `lw x10, -32(x8)` | `lw x31, -2048(x0)` |
| `lb` | `lb x3, 31(x4)` | `lb x8, -17(x20)` | `lb x0, 2047(x31)` |
| `sw` | `sw x5, 20(x6)` | `sw x10, -36(x8)` | `sw x31, -2048(x0)` |
| `sb` | `sb x3, 15(x4)` | `sb x8, -19(x20)` | `sb x0, 2047(x31)` |
| `beq` | `beq x1, x2, 8` | `beq x31, x0, -4096` | `beq x0, x0, 0` |
| `bne` | `bne x5, x6, -8` | `bne x0, x31, 4094` | `bne x31, x31, 0` |

Para las instrucciones de formato R se probaron registros extremos como `x0` y `x31`, además de registros repetidos.

Para los formatos I y S se incluyeron inmediatos positivos, negativos y valores límite.

Para el formato B se incluyeron desplazamientos positivos, negativos, cero y los extremos del rango aceptado.

---

### 4.3 Consideración especial para las instrucciones B

Durante la validación de `beq` y `bne` se utilizaron etiquetas locales para representar los destinos de salto.

Esto permitió controlar exactamente la distancia entre la instrucción branch y su destino.

Por ejemplo, para comprobar:

```text
beq x1, x2, 8
```

se utilizó conceptualmente:

```asm
_start:
    beq x1, x2, .Ltarget
    .space 4

.Ltarget:
```

De esta forma, la etiqueta se encuentra exactamente 8 bytes después de la dirección de la instrucción.

Para los desplazamientos negativos se colocó la etiqueta antes de la instrucción.

Este procedimiento permitió comparar directamente el inmediato codificado por la herramienta con la codificación producida por el ensamblador oficial.

---

### 4.4 Resultado

La ejecución completa se realizó mediante:

```bash
./validar.sh | tee evidencia_validacion.txt
```

El resultado final obtenido fue:

```text
============================================================
 RESUMEN
============================================================
Total      : 36
Correctos  : 36
Incorrectos: 0

VALIDACION EXITOSA: 36/36 casos coinciden.
```

Por lo tanto:

```text
36 de 36 casos de prueba coincidieron con GNU RISC-V.
```

Esto corresponde a una coincidencia del:

```text
100 %
```

entre las codificaciones producidas por la implementación y las obtenidas mediante el toolchain utilizado como referencia.

La salida completa de los 36 casos se conserva en:

```text
evidencia_validacion.txt
```

---

## 5. Instalación del toolchain y preparación y uso de la herramienta

### 5.1 Entorno utilizado

La implementación fue desarrollada en Python 3.

La validación con el toolchain GNU RISC-V se realizó utilizando Linux mediante Windows Subsystem for Linux (WSL).

La herramienta principal solamente requiere:

```text
Python 3
Bash
```

No utiliza bibliotecas externas de Python.

---

### 5.2 Instalación del toolchain RISC-V

En una distribución basada en Ubuntu se actualizaron inicialmente los índices de paquetes:

```bash
sudo apt update
```

Después se instalaron las herramientas GNU para RISC-V:

```bash
sudo apt install gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf
```

Se comprobó la instalación mediante:

```bash
riscv64-unknown-elf-as --version
```

y:

```bash
riscv64-unknown-elf-objdump --version
```

Aunque las herramientas instaladas utilizan el prefijo `riscv64-unknown-elf`, el ensamblador se configuró explícitamente para generar instrucciones RV32I utilizando:

```bash
-march=rv32i
-mabi=ilp32
```

---

### 5.3 Preparación de la herramienta

Se debe comprobar que Python 3 esté disponible:

```bash
python3 --version
```

Si `run.sh` no tiene permisos de ejecución, se deben asignar mediante:

```bash
chmod +x run.sh
```

No es necesario instalar paquetes mediante `pip`.

---

### 5.4 Uso del codificador

La herramienta se ejecuta exclusivamente mediante:

```bash
./run.sh "<instruccion>"
```

Por ejemplo:

```bash
./run.sh "add x5, x6, x7"
```

Otro ejemplo con un operando de memoria:

```bash
./run.sh "lw x29, 8(x30)"
```

Y un ejemplo de branch:

```bash
./run.sh "beq x1, x2, 8"
```

La salida siempre termina con una línea de la forma:

```text
HEX: 0xXXXXXXXX
```

---

### 5.5 Ejecución de la validación

Para ejecutar todos los casos de prueba:

```bash
chmod +x validar.sh
```

y posteriormente:

```bash
./validar.sh
```

Para ejecutar la validación y almacenar simultáneamente la evidencia:

```bash
./validar.sh | tee evidencia_validacion.txt
```

Al finalizar correctamente se espera:

```text
Total      : 36
Correctos  : 36
Incorrectos: 0

VALIDACION EXITOSA: 36/36 casos coinciden.
```

---

## 6. Archivos relevantes

La entrega contiene los siguientes archivos principales:

```text
.
├── encoder_skeleton.py
├── run.sh
├── README.md
├── documentacion.md
├── casos_prueba.txt
├── validar.sh
└── evidencia_validacion.txt
```

### `encoder_skeleton.py`

Contiene la implementación del codificador, el análisis de operandos y la generación de la salida explicativa.

### `run.sh`

Punto de entrada de la herramienta.

### `README.md`

Contiene únicamente la preparación básica necesaria para ejecutar la herramienta.

### `documentacion.md`

Contiene la documentación técnica de la implementación.

### `casos_prueba.txt`

Contiene los 36 casos de prueba propios utilizados durante la validación.

### `validar.sh`

Automatiza la comparación entre la herramienta desarrollada y GNU RISC-V.

### `evidencia_validacion.txt`

Contiene el registro de los 36 casos de validación y sus resultados.

---

## 7. Conclusiones

Se implementó un codificador educativo capaz de procesar las 12 instrucciones solicitadas del subconjunto RV32I utilizando los formatos R, I, S y B.

La solución se estructuró separando los datos correspondientes a la ISA de la lógica de codificación. Los operandos se interpretan mediante funciones específicas para registros, inmediatos, direcciones de memoria y branches.

La construcción de las instrucciones se realiza mediante operaciones de desplazamiento y máscaras de bits, reproduciendo directamente la distribución de campos establecida por RISC-V.

La función de explicación extrae posteriormente los campos desde la palabra codificada y permite visualizar tanto su posición como su significado.

Finalmente, la implementación fue comparada contra el toolchain GNU para RISC-V mediante 36 casos de prueba propios. Los 36 casos coincidieron con la codificación de referencia, obteniéndose un resultado de 36/36 pruebas correctas.

---

## Referencias

[1] RISC-V International, *The RISC-V Instruction Set Manual, Volume I: Unprivileged Architecture*, RV32I Base Integer Instruction Set, Version 2.1.

[2] RISC-V International, *RV32/64G Instruction Set Listings*, RISC-V Ratified Specifications Library.

[3] GNU Project, *GNU Binutils Documentation*, documentación de GNU Assembler y GNU Objdump.