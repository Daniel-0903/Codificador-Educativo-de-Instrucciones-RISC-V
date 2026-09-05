#!/usr/bin/env bash

set -u

CASOS="casos_prueba.txt"
TEMP_DIR=".validacion_tmp"

mkdir -p "$TEMP_DIR"

total=0
correctos=0
incorrectos=0

echo "============================================================"
echo " VALIDACION DEL CODIFICADOR RISC-V"
echo " Nuestro encoder vs GNU RISC-V objdump"
echo "============================================================"
echo

while IFS= read -r instruction || [ -n "$instruction" ]; do

    if [ -z "$instruction" ]; then
        continue
    fi

    total=$((total + 1))

    asm_file="$TEMP_DIR/test.s"
    obj_file="$TEMP_DIR/test.o"

    # Obtener el mnemonico
    mnemonic=$(echo "$instruction" | awk '{print $1}')

    # ==========================================================
    # CASO ESPECIAL: BRANCH
    # ==========================================================
    if [ "$mnemonic" = "beq" ] || [ "$mnemonic" = "bne" ]; then

        # Quitar comas para separar fácilmente los operandos
        clean_instruction=$(echo "$instruction" | tr ',' ' ')

        read -r branch_mnemonic rs1 rs2 imm <<< "$clean_instruction"

        # ------------------------------------------------------
        # Desplazamiento positivo
        # ------------------------------------------------------
        if [ "$imm" -gt 0 ]; then

            padding=$((imm - 4))

            cat > "$asm_file" << EOF
.option norvc
.text
.globl _start

_start:
    $branch_mnemonic $rs1, $rs2, .Ltarget

    .space $padding

.Ltarget:
EOF

        # ------------------------------------------------------
        # Desplazamiento negativo
        # ------------------------------------------------------
        elif [ "$imm" -lt 0 ]; then

            distance=$((-imm))

            cat > "$asm_file" << EOF
.option norvc
.text
.globl _start

.Ltarget:
    .space $distance

_start:
    $branch_mnemonic $rs1, $rs2, .Ltarget
EOF

        # ------------------------------------------------------
        # Desplazamiento cero
        # ------------------------------------------------------
        else

            cat > "$asm_file" << EOF
.option norvc
.text
.globl _start

_start:
.Ltarget:
    $branch_mnemonic $rs1, $rs2, .Ltarget
EOF

        fi

    # ==========================================================
    # RESTO DE INSTRUCCIONES
    # ==========================================================
    else

        cat > "$asm_file" << EOF
.option norvc
.text
.globl _start

_start:
    $instruction
EOF

    fi

    # ==========================================================
    # ENSAMBLAR
    # ==========================================================
    if ! riscv64-unknown-elf-as \
        -march=rv32i \
        -mabi=ilp32 \
        "$asm_file" \
        -o "$obj_file" 2>/dev/null
    then
        echo "[$total] $instruction"
        echo "    ERROR: el ensamblador oficial rechazó la instrucción"
        echo
        incorrectos=$((incorrectos + 1))
        continue
    fi

    # ==========================================================
    # OBTENER HEX DEL TOOLCHAIN
    # ==========================================================
    if [ "$mnemonic" = "beq" ] || [ "$mnemonic" = "bne" ]; then

        official_hex=$(
            riscv64-unknown-elf-objdump \
                -d \
                -M numeric,no-aliases \
                "$obj_file" |
            awk -v mnemonic="$mnemonic" \
                '$3 == mnemonic {print $2; exit}'
        )

    else

        official_hex=$(
            riscv64-unknown-elf-objdump \
                -d \
                -M numeric,no-aliases \
                "$obj_file" |
            awk '/^[[:space:]]*[0-9a-f]+:/ {print $2; exit}'
        )

    fi

    official_hex="0x${official_hex,,}"

    # ==========================================================
    # EJECUTAR NUESTRO ENCODER
    # ==========================================================
    our_hex=$(
        ./run.sh "$instruction" |
        sed -n 's/^HEX: //p' |
        head -n 1
    )

    our_hex="${our_hex,,}"

    # ==========================================================
    # COMPARAR
    # ==========================================================
    echo "[$total] $instruction"
    echo "    Encoder : $our_hex"
    echo "    Objdump : $official_hex"

    if [ "$our_hex" = "$official_hex" ]; then
        echo "    RESULTADO: PASS"
        correctos=$((correctos + 1))
    else
        echo "    RESULTADO: FAIL"
        incorrectos=$((incorrectos + 1))
    fi

    echo

done < "$CASOS"

echo "============================================================"
echo " RESUMEN"
echo "============================================================"
echo "Total      : $total"
echo "Correctos  : $correctos"
echo "Incorrectos: $incorrectos"
echo

if [ "$incorrectos" -eq 0 ] && [ "$total" -eq 36 ]; then
    echo "VALIDACION EXITOSA: 36/36 casos coinciden."
    exit 0
else
    echo "VALIDACION INCOMPLETA O CON ERRORES."
    exit 1
fi
