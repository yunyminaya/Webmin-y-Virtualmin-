#!/bin/bash

# Script para corregir errores de sintaxis en archivos optimizados
# Fecha: $(date +'%Y-%m-%d %H:%M:%S')

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -euo pipefail

# Colores
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

# Función de logging
# DUPLICADA: log() { # Usar common_functions.sh
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# DUPLICADA: log_error() { # Usar common_functions.sh
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# DUPLICADA: log_warning() { # Usar common_functions.sh
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Función para corregir errores de sintaxis comunes
corregir_errores_sintaxis() {
    local archivo="$1"
    local temp_file="${archivo}.tmp"
    local correcciones=0
    
    log "Corrigiendo errores de sintaxis en: $archivo"
    
    # Crear copia temporal
    cp "$archivo" "$temp_file"
    
    # Corregir funciones mal comentadas
    # Patrón: # DUPLICADA: function_name() { # comentario
    sed -i '' '/^# DUPLICADA: [a-zA-Z_][a-zA-Z0-9_]*() { #/{
        s/.*/# DUPLICADA: Función reemplazada por common_functions.sh/
        :loop
        n
        /^}/{
            s/.*/# Fin de función duplicada/
            b end
        }
        /^[[:space:]]*$/b loop
        s/.*/# Contenido de función duplicada/
        b loop
        :end
    }' "$temp_file"
    
    # Verificar si se hicieron cambios
    if ! cmp -s "$archivo" "$temp_file"; then
        mv "$temp_file" "$archivo"
        correcciones=1
        log "✅ Correcciones aplicadas a: $archivo"
    else
        rm "$temp_file"
        log "ℹ️  No se necesitaron correcciones en: $archivo"
    fi
    
    return $correcciones
}

# Función para verificar sintaxis
verificar_sintaxis() {
    local archivo="$1"
    
    if bash -n "$archivo" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Función principal
main() {
    echo -e "${BLUE}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "🔧 CORRECCIÓN DE ERRORES DE SINTAXIS"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    
    local archivos_corregidos=0
    local archivos_con_errores=0
    local total_archivos=0
    
    # Buscar todos los archivos .sh
    while IFS= read -r -d '' archivo; do
        ((total_archivos++))
        
        # Verificar sintaxis inicial
        if ! verificar_sintaxis "$archivo"; then
            log_warning "Errores de sintaxis detectados en: $archivo"
            
            # Intentar corregir
            if corregir_errores_sintaxis "$archivo"; then
                # Verificar si la corrección funcionó
                if verificar_sintaxis "$archivo"; then
                    log "✅ Archivo corregido exitosamente: $archivo"
                    ((archivos_corregidos++))
                else
                    log_error "❌ No se pudo corregir: $archivo"
                    ((archivos_con_errores++))
                fi
            else
                log "ℹ️  No se necesitaron correcciones en: $archivo"
            fi
        else
            log "✅ Sintaxis correcta: $archivo"
        fi
        
    done < <(find . -name "*.sh" -type f -print0)
    
    # Resumen
    echo
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}📊 RESUMEN DE CORRECCIONES${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo
    echo "📁 Total de archivos analizados: $total_archivos"
    echo "✅ Archivos corregidos: $archivos_corregidos"
    echo "❌ Archivos con errores persistentes: $archivos_con_errores"
    echo "✨ Archivos con sintaxis correcta: $((total_archivos - archivos_corregidos - archivos_con_errores))"
    echo
    
    if [ $archivos_con_errores -eq 0 ]; then
        log "🎉 Todos los archivos tienen sintaxis correcta!"
        return 0
    else
        log_error "⚠️  Algunos archivos aún tienen errores de sintaxis"
        return 1
    fi
}

# Ejecutar función principal
main "$@"
