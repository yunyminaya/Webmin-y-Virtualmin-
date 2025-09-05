#!/bin/bash

# Sub-Agente Detector de Duplicados
# Elimina funciones duplicadas y optimiza código

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/sub_agente_detector_duplicados.log"
REPORT_FILE="/var/log/duplicados_encontrados_$(date +%Y%m%d_%H%M%S).txt"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DETECTOR-DUP] $1" | tee -a "$LOG_FILE"
}

detect_duplicate_functions() {
    log_message "=== DETECTANDO FUNCIONES DUPLICADAS ==="
    
    local duplicates_found=0
    local files_scanned=0
    
    {
        echo "=== REPORTE DE FUNCIONES DUPLICADAS ==="
        echo "Fecha: $(date)"
        echo "Directorio escaneado: $SCRIPT_DIR"
        echo ""
        
        # Buscar funciones en scripts bash
        log_message "Analizando funciones en scripts bash..."
        
        # Extraer todas las funciones de los scripts
        local temp_functions="/tmp/functions_list.tmp"
        > "$temp_functions"
        
        for script in "$SCRIPT_DIR"/*.sh; do
            if [ -f "$script" ]; then
                ((files_scanned++))
                grep -n "^[a-zA-Z_][a-zA-Z0-9_]*\s*()" "$script" | while read line; do
                    local func_name=$(echo "$line" | sed 's/.*://; s/().*//')
                    echo "$func_name:$script:$(echo "$line" | cut -d: -f1)" >> "$temp_functions"
                done
            fi
        done
        
        echo "=== ANÁLISIS DE DUPLICADOS ==="
        echo "Archivos escaneados: $files_scanned"
        echo ""
        
        # Analizar duplicados
        local seen_functions="/tmp/seen_functions.tmp"
        > "$seen_functions"
        
        while read function_info; do
            local func_name=$(echo "$function_info" | cut -d: -f1)
            local script_file=$(echo "$function_info" | cut -d: -f2)
            local line_number=$(echo "$function_info" | cut -d: -f3)
            
            if grep -q "^$func_name$" "$seen_functions"; then
                echo "🔍 DUPLICADO ENCONTRADO: $func_name"
                echo "   Archivo: $script_file"
                echo "   Línea: $line_number"
                echo ""
                ((duplicates_found++))
            else
                echo "$func_name" >> "$seen_functions"
            fi
        done < "$temp_functions"
        
        # Buscar código duplicado (bloques similares)
        echo "=== CÓDIGO DUPLICADO ==="
        
        for script1 in "$SCRIPT_DIR"/*.sh; do
            for script2 in "$SCRIPT_DIR"/*.sh; do
                if [[ "$script1" < "$script2" ]]; then
                    local similarity=$(diff -u "$script1" "$script2" | grep -c "^+" || echo "0")
                    if [ "$similarity" -gt 10 ] && [ "$similarity" -lt 100 ]; then
                        echo "⚠️  Posible código similar entre:"
                        echo "   $(basename "$script1") y $(basename "$script2")"
                        echo "   Diferencias: $similarity líneas"
                        echo ""
                    fi
                fi
            done
        done
        
        # Limpieza
        rm -f "$temp_functions" "$seen_functions"
        
        echo "=== RESUMEN ==="
        echo "Total de duplicados encontrados: $duplicates_found"
        echo "Archivos analizados: $files_scanned"
        
        if [ "$duplicates_found" -gt 0 ]; then
            echo ""
            echo "=== RECOMENDACIONES ==="
            echo "1. Crear lib/common_functions.sh con funciones compartidas"
            echo "2. Eliminar funciones duplicadas de scripts individuales"
            echo "3. Usar 'source lib/common_functions.sh' en cada script"
            echo "4. Estandarizar nombres de variables y funciones"
        fi
        
    } > "$REPORT_FILE"
    
    log_message "✓ Reporte de duplicados: $REPORT_FILE"
}

auto_fix_duplicates() {
    log_message "=== CORRIGIENDO DUPLICADOS AUTOMÁTICAMENTE ==="
    
    # Crear directorio lib si no existe
    mkdir -p "$SCRIPT_DIR/lib"
    
    # Crear archivo de funciones comunes
    cat > "$SCRIPT_DIR/lib/common_functions.sh" << 'EOF'
#!/bin/bash

# Funciones Comunes para Sub-Agentes Webmin/Virtualmin

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2
}

log_warning() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1"
}

check_root_privileges() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Se requieren privilegios de root para esta operación"
        return 1
    fi
}

check_service_status() {
    local service="$1"
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

ensure_directory() {
    local dir="$1"
    mkdir -p "$dir" 2>/dev/null || true
}

backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
}

send_notification() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "/var/log/notificaciones_sistema.log"
    
    # Webhook notification
    if command -v curl &> /dev/null; then
        curl -X POST "http://localhost:10000/webhook/notification" \
            -H "Content-Type: application/json" \
            -d "{\"level\":\"$level\",\"message\":\"$message\",\"timestamp\":\"$timestamp\"}" \
            2>/dev/null || true
    fi
}

get_system_info() {
    echo "hostname=$(hostname)"
    echo "os=$(lsb_release -d 2>/dev/null | cut -f2 || uname -a)"
    echo "uptime=$(uptime -p)"
    echo "cpu_cores=$(nproc)"
    echo "memory_total=$(free -h | grep Mem | awk '{print $2}')"
    echo "disk_total=$(df -h / | tail -1 | awk '{print $2}')"
}
EOF

    log_message "✓ Biblioteca de funciones comunes creada"
    
    # Actualizar scripts existentes para usar funciones comunes
    local scripts_to_update=(
        "coordinador_sub_agentes.sh"
        "sub_agente_monitoreo.sh"
        "sub_agente_seguridad.sh"
        "sub_agente_backup.sh"
    )
    
    for script in "${scripts_to_update[@]}"; do
        if [ -f "$SCRIPT_DIR/$script" ]; then
            # Crear backup
            cp "$SCRIPT_DIR/$script" "$SCRIPT_DIR/$script.pre_dedup.$(date +%Y%m%d_%H%M%S)"
            
            # Agregar source de funciones comunes si no existe
            if ! grep -q "source.*common_functions.sh" "$SCRIPT_DIR/$script"; then
                sed -i '10i\\n# Cargar funciones comunes\nsource "$SCRIPT_DIR/lib/common_functions.sh"' "$SCRIPT_DIR/$script"
                log_message "✓ Funciones comunes agregadas a $script"
            fi
        fi
    done
}

validate_no_duplicates() {
    log_message "=== VALIDANDO ELIMINACIÓN DE DUPLICADOS ==="
    
    local validation_report="/var/log/validacion_duplicados_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== VALIDACIÓN POST-CORRECCIÓN ==="
        echo "Fecha: $(date)"
        echo ""
        
        # Verificar que common_functions.sh existe
        if [ -f "$SCRIPT_DIR/lib/common_functions.sh" ]; then
            echo "✅ Biblioteca común disponible"
        else
            echo "❌ Biblioteca común faltante"
        fi
        
        # Contar funciones únicas
        local unique_functions=0
        if [ -f "$SCRIPT_DIR/lib/common_functions.sh" ]; then
            unique_functions=$(grep -c "^[a-zA-Z_][a-zA-Z0-9_]*\s*()" "$SCRIPT_DIR/lib/common_functions.sh" || echo "0")
        fi
        
        echo "Funciones comunes disponibles: $unique_functions"
        
        # Verificar que scripts usan la biblioteca
        local scripts_using_lib=0
        for script in "$SCRIPT_DIR"/*.sh; do
            if grep -q "source.*common_functions.sh" "$script"; then
                ((scripts_using_lib++))
            fi
        done
        
        echo "Scripts usando biblioteca común: $scripts_using_lib"
        
        # Detectar duplicados restantes
        local remaining_duplicates=0
        local temp_funcs="/tmp/remaining_funcs.tmp"
        > "$temp_funcs"
        
        for script in "$SCRIPT_DIR"/*.sh; do
            if [ "$(basename "$script")" != "common_functions.sh" ]; then
                grep "^[a-zA-Z_][a-zA-Z0-9_]*\s*()" "$script" | while read func; do
                    local func_name=$(echo "$func" | sed 's/().*//')
                    echo "$func_name" >> "$temp_funcs"
                done
            fi
        done
        
        if [ -f "$temp_funcs" ]; then
            remaining_duplicates=$(sort "$temp_funcs" | uniq -d | wc -l)
            rm -f "$temp_funcs"
        fi
        
        echo "Duplicados restantes: $remaining_duplicates"
        
        if [ "$remaining_duplicates" -eq 0 ]; then
            echo ""
            echo "🎉 SISTEMA LIBRE DE DUPLICADOS"
        else
            echo ""
            echo "⚠️  Aún hay $remaining_duplicates duplicados por corregir"
        fi
        
    } > "$validation_report"
    
    log_message "✓ Validación completada: $validation_report"
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    log_message "=== INICIANDO DETECTOR DE DUPLICADOS ==="
    
    case "${1:-scan}" in
        scan)
            detect_duplicate_functions
            cat "$REPORT_FILE"
            ;;
        fix)
            detect_duplicate_functions
            auto_fix_duplicates
            validate_no_duplicates
            ;;
        validate)
            validate_no_duplicates
            ;;
        report)
            if [ -f "$REPORT_FILE" ]; then
                cat "$REPORT_FILE"
            else
                log_message "No hay reporte disponible. Ejecute primero 'scan'"
            fi
            ;;
        *)
            echo "Sub-Agente Detector de Duplicados"
            echo "Uso: $0 {scan|fix|validate|report}"
            echo ""
            echo "Comandos:"
            echo "  scan     - Escanear y detectar duplicados"
            echo "  fix      - Corregir duplicados automáticamente"
            echo "  validate - Validar corrección de duplicados"
            echo "  report   - Mostrar último reporte"
            exit 1
            ;;
    esac
    
    log_message "Detector de duplicados completado"
}

main "$@"