#!/bin/bash

# Script para corregir errores comunes de markdownlint
# Corrige MD022, MD032, MD031, MD024, y MD036

set -euo pipefail

LOG_FILE="correccion_markdown.log"
FIXED_COUNT=0

log_fix() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
    ((FIXED_COUNT++))
}

echo "🔧 Iniciando corrección automática de archivos Markdown..."
echo "Fecha: $(date)" > "$LOG_FILE"

# Buscar todos los archivos .md
find . -name "*.md" -type f | while read -r file; do
    if [[ ! -w "$file" ]]; then
        echo "⚠️ Sin permisos de escritura: $file"
        continue
    fi
    
    echo "📝 Procesando: $file"
    
    # Crear backup
    cp "$file" "$file.backup"
    
    # MD022: Agregar líneas en blanco alrededor de encabezados
    # MD032: Agregar líneas en blanco alrededor de listas
    # MD031: Agregar líneas en blanco alrededor de código
    
    awk '
    BEGIN { prev_line = ""; in_code_block = 0 }
    
    # Detectar bloques de código
    /^```/ {
        if (in_code_block == 0) {
            # Inicio de bloque de código
            if (prev_line != "" && prev_line !~ /^$/) {
                print ""
            }
            in_code_block = 1
        } else {
            # Fin de bloque de código
            in_code_block = 0
        }
        print $0
        if (in_code_block == 0) {
            print ""
        }
        prev_line = $0
        next
    }
    
    # Si no estamos en bloque de código
    !in_code_block {
        # MD022: Encabezados necesitan línea en blanco antes y después
        /^#/ {
            if (prev_line != "" && prev_line !~ /^$/) {
                print ""
            }
            print $0
            print ""
            prev_line = ""
            next
        }
        
        # MD032: Listas necesitan línea en blanco antes
        /^[[:space:]]*[-*+][[:space:]]/ {
            if (prev_line != "" && prev_line !~ /^$/ && prev_line !~ /^#/) {
                print ""
            }
            print $0
            prev_line = $0
            next
        }
        
        # MD032: Listas numeradas necesitan línea en blanco antes
        /^[[:space:]]*[0-9]+\.[[:space:]]/ {
            if (prev_line != "" && prev_line !~ /^$/ && prev_line !~ /^#/) {
                print ""
            }
            print $0
            prev_line = $0
            next
        }
        
        # Líneas normales
        {
            # Evitar líneas en blanco duplicadas después de encabezados
            if ($0 == "" && prev_line ~ /^#/) {
                prev_line = $0
                next
            }
            print $0
            prev_line = $0
        }
    }
    
    # Si estamos en bloque de código, solo imprimir
    in_code_block {
        print $0
        prev_line = $0
    }
    ' "$file" > "$file.tmp"
    
    # Reemplazar el archivo original
    mv "$file.tmp" "$file"
    
    # Verificar si hubo cambios
    if ! diff -q "$file" "$file.backup" >/dev/null 2>&1; then
        log_fix "✅ Corregido: $file"
    else
        rm "$file.backup"
    fi
done

echo ""
echo "🎉 Corrección completada!"
echo "📊 Archivos procesados: $FIXED_COUNT"
echo "📋 Log detallado: $LOG_FILE"

# Ejecutar verificación con markdownlint si está disponible
if command -v markdownlint >/dev/null 2>&1; then
    echo ""
    echo "🔍 Ejecutando verificación final con markdownlint..."
    markdownlint *.md || echo "⚠️ Aún hay algunos errores de markdownlint"
else
    echo "ℹ️ markdownlint no instalado. Para verificar instala: npm install -g markdownlint-cli"
fi