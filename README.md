# Codificador Educativo de Instrucciones RISC-V

Proyecto individual del curso CE-4301 Arquitectura de Computadores I.

La herramienta codifica un subconjunto de instrucciones RISC-V RV32I y muestra su representación binaria, hexadecimal y el significado de sus campos.

## Requisitos

Para ejecutar la herramienta se requiere:

- Python 3
- Bash

No se requieren bibliotecas externas de Python ni dependencias adicionales.

Para verificar que Python 3 está instalado:

```bash
python3 --version
```

## Preparación

Si el archivo `run.sh` no tiene permisos de ejecución, ejecute una única vez:

```bash
chmod +x run.sh
```

## Uso

La herramienta debe ejecutarse mediante:

```bash
./run.sh "<instruccion>"
```

Por ejemplo:

```bash
./run.sh "add x5, x6, x7"
```

La salida incluye el formato de la instrucción, la representación binaria de 32 bits, el desglose de sus campos y una línea final con la codificación hexadecimal:

```
HEX: 0xXXXXXXXX
```

## Instrucciones soportadas

La herramienta soporta las siguientes instrucciones RV32I:

- `add`
- `sub`
- `and`
- `or`
- `addi`
- `andi`
- `lw`
- `lb`
- `sw`
- `sb`
- `beq`
- `bne`