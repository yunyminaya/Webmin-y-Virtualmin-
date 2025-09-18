#!/bin/bash

# ============================================================================
# Auto-Reparación Inteligente - Virtualmin/Webmin
# ============================================================================
# Reparación automática solo para problemas críticos del servidor
# Versión: 1.0.0
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== INCLUIR BIBLIOTECA COMÚN =====
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
    source "${SCRIPT_DIR}/lib/common.sh"
else
    echo "ERROR: No se encuentra la biblioteca común"
    exit 1
fi

# Variables de configuración
CRITICAL_LOG="${CRITICAL_LOG:-./logs/critical_repair.log}"
STATUS_FILE="${STATUS_FILE:-./logs/system_status.txt}"
LAST_CHECK="${LAST_CHECK:-./logs/last_critical_check.txt}"

# Umbrales críticos
CRITICAL_MEMORY_USAGE=95  # 95% de RAM usada
CRITICAL_DISK_USAGE=98     # 98% de disco usado
CRITICAL_LOAD_AVERAGE=10   # Load average > 10
MAX_CRITICAL_PROCESSES=50  # Más de 50 procesos críticos
MIN_FREE_MEMORY_MB=100     # Menos de 100MB libres

# ============================================================================
# FUNCIONES DE DETECCIÓN DE PROBLEMAS CRÍTICOS
# ============================================================================

# Función para detectar problemas críticos de memoria
detect_critical_memory() {
    local mem_usage
    mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')

    if [[ $mem_usage -gt $CRITICAL_MEMORY_USAGE ]]; then
        log_critical "CRÍTICO: Uso de memoria muy alto: ${mem_usage}% (umbral: ${CRITICAL_MEMORY_USAGE}%)"
        return 0  # Hay problema
    fi

    local free_mem_mb
    free_mem_mb=$(free -m | awk 'NR==2{print $4}')

    if [[ $free_mem_mb -lt $MIN_FREE_MEMORY_MB ]]; then
        log_critical "CRÍTICO: Memoria libre muy baja: ${free_mem_mb}MB (mínimo: ${MIN_FREE_MEMORY_MB}MB)"
        return 0  # Hay problema
    fi

    return 1  # No hay problema
}

# Función para detectar problemas críticos de disco
detect_critical_disk() {
    local disk_usage
    disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

    if [[ $disk_usage -gt $CRITICAL_DISK_USAGE ]]; then
        log_critical "CRÍTICO: Uso de disco muy alto: ${disk_usage}% (umbral: ${CRITICAL_DISK_USAGE}%)"
        return 0  # Hay problema
    fi

    # Verificar espacio libre absoluto
    local free_space_mb
    free_space_mb=$(df -BM / | tail -1 | awk '{print $4}' | sed 's/M//')

    if [[ $free_space_mb -lt 500 ]]; then  # Menos de 500MB libres
        log_critical "CRÍTICO: Espacio libre muy bajo: ${free_space_mb}MB (mínimo recomendado: 500MB)"
        return 0  # Hay problema
    fi

    return 1  # No hay problema
}

# Función para detectar problemas críticos de CPU/load
detect_critical_cpu() {
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')

    # Comparar load average con núcleos de CPU
    local cpu_cores
    cpu_cores=$(nproc 2>/dev/null || echo "1")

    # Si load average > núcleos de CPU * 2, es crítico
    if (( $(echo "$load_avg > $cpu_cores * 2" | bc -l 2>/dev/null || echo "0") )); then
        log_critical "CRÍTICO: Load average muy alto: $load_avg (núcleos CPU: $cpu_cores)"
        return 0  # Hay problema
    fi

    if (( $(echo "$load_avg > $CRITICAL_LOAD_AVERAGE" | bc -l 2>/dev/null || echo "0") )); then
        log_critical "CRÍTICO: Load average extremadamente alto: $load_avg"
        return 0  # Hay problema
    fi

    return 1  # No hay problema
}

# Función para detectar procesos problemáticos
detect_critical_processes() {
    local critical_count=0

    # Procesos que consumen mucha CPU
    local high_cpu_processes
    high_cpu_processes=$(ps aux --no-headers -o pid,%cpu,comm | awk '$2 > 90 {print $1 ":" $2 ":" $3}' | wc -l)

    if [[ $high_cpu_processes -gt 0 ]]; then
        log_critical "CRÍTICO: $high_cpu_processes procesos con CPU > 90%"
        ((critical_count++))
    fi

    # Procesos zombie
    local zombie_processes
    zombie_processes=$(ps aux | awk '{print $8}' | grep -c "Z" 2>/dev/null || echo "0")

    if [[ $zombie_processes -gt 5 ]]; then
        log_critical "CRÍTICO: $zombie_processes procesos zombie detectados"
        ((critical_count++))
    fi

    # Procesos huérfanos
    local orphan_processes
    orphan_processes=$(ps aux | awk '$3 == 1 && $1 != "root" {print}' | wc -l 2>/dev/null || echo "0")

    if [[ $orphan_processes -gt 20 ]]; then
        log_critical "CRÍTICO: $orphan_processes procesos huérfanos detectados"
        ((critical_count++))
    fi

    return $((critical_count > 0 ? 0 : 1))
}

# Función para detectar problemas críticos de red
detect_critical_network() {
    # Verificar conectividad básica
    if ! check_url_connectivity "8.8.8.8" 5; then
        log_critical "CRÍTICO: Sin conectividad de red básica (no puede resolver 8.8.8.8)"
        return 0  # Hay problema
    fi

    # Verificar si hay procesos de red colgados
    local network_processes_hung
    network_processes_hung=$(netstat -tuln 2>/dev/null | grep -c "LISTEN" || echo "0")

    if [[ $network_processes_hung -eq 0 ]]; then
        log_critical "CRÍTICO: No hay servicios de red escuchando (posible problema de red)"
        return 0  # Hay problema
    fi

    return 1  # No hay problema
}

# Función para detectar archivos críticos faltantes
detect_critical_files() {
    local missing_files=()

    # Archivos críticos del sistema
    local critical_system_files=(
        "/etc/passwd"
        "/etc/shadow"
        "/etc/group"
        "/etc/hosts"
        "/etc/resolv.conf"
        "/etc/fstab"
    )

    for file in "${critical_system_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done

    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_critical "CRÍTICO: Archivos del sistema faltantes: ${missing_files[*]}"
        return 0  # Hay problema
    fi

    return 1  # No hay problema
}

# ============================================================================
# FUNCIONES DE REPARACIÓN CRÍTICA
# ============================================================================

# Función para reparar problemas críticos de memoria
repair_critical_memory() {
    log_repair "REPAIR" "Ejecutando reparación crítica de memoria..."

    # Liberar memoria cache si es posible
    if [[ $EUID -eq 0 ]]; then
        echo 3 > /proc/sys/vm/drop_caches 2>/dev/null && log_repair "SUCCESS" "Memoria cache liberada"
    else
        log_repair "WARNING" "Se requieren permisos de root para liberar memoria cache"
    fi

    # Matar procesos que consumen demasiada memoria (con precaución)
    local high_mem_processes
    high_mem_processes=$(ps aux --no-headers -o pid,%mem,comm --sort=-%mem | head -3)

    while IFS= read -r process; do
        local pid mem cmd
        pid=$(echo "$process" | awk '{print $1}')
        mem=$(echo "$process" | awk '{print $2}')
        cmd=$(echo "$process" | awk '{print $3}')

        # Solo matar procesos con más del 80% de memoria y que no sean críticos del sistema
        if (( $(echo "$mem > 80" | bc -l 2>/dev/null || echo "0") )) && [[ "$cmd" != "systemd" ]] && [[ "$cmd" != "init" ]]; then
            log_repair "WARNING" "Terminando proceso de alta memoria: $cmd (PID: $pid, MEM: $mem%)"
            kill -15 "$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null
        fi
    done <<< "$high_mem_processes"
}

# Función para reparar problemas críticos de disco
repair_critical_disk() {
    log_repair "REPAIR" "Ejecutando reparación crítica de disco..."

    if [[ $EUID -eq 0 ]]; then
        # Limpiar archivos temporales del sistema
        find /tmp -name "*.tmp" -type f -mtime +7 -delete 2>/dev/null && log_repair "SUCCESS" "Archivos temporales antiguos eliminados"
        find /var/log -name "*.gz" -type f -mtime +30 -delete 2>/dev/null && log_repair "SUCCESS" "Logs antiguos comprimidos eliminados"

        # Limpiar cache de paquetes si existe
        if command_exists apt-get; then
            apt-get autoclean >/dev/null 2>&1 && log_repair "SUCCESS" "Cache de paquetes APT limpiado"
        elif command_exists yum; then
            yum clean all >/dev/null 2>&1 && log_repair "SUCCESS" "Cache de paquetes YUM limpiado"
        fi
    else
        log_repair "WARNING" "Se requieren permisos de root para limpieza completa de disco"
    fi
}

# Función para reparar procesos críticos
repair_critical_processes() {
    log_repair "REPAIR" "Ejecutando reparación crítica de procesos..."

    if [[ $EUID -eq 0 ]]; then
        # Matar procesos zombie
        local zombie_pids
        zombie_pids=$(ps aux | awk '$8 == "Z" {print $2}')

        for pid in $zombie_pids; do
            log_repair "WARNING" "Eliminando proceso zombie PID: $pid"
            kill -9 "$pid" 2>/dev/null
        done

        # Reiniciar servicios críticos si es necesario
        if ! service_running "sshd" && command_exists systemctl; then
            systemctl restart sshd 2>/dev/null && log_repair "SUCCESS" "Servicio SSH reiniciado"
        fi
    else
        log_repair "WARNING" "Se requieren permisos de root para reparar procesos del sistema"
    fi
}

# Función para reparar problemas críticos de red
repair_critical_network() {
    log_repair "REPAIR" "Ejecutando reparación crítica de red..."

    if [[ $EUID -eq 0 ]]; then
        # Reiniciar servicios de red
        if command_exists systemctl; then
            systemctl restart networking 2>/dev/null && log_repair "SUCCESS" "Servicio de red reiniciado"
            systemctl restart NetworkManager 2>/dev/null && log_repair "SUCCESS" "NetworkManager reiniciado"
        elif command_exists service; then
            service networking restart 2>/dev/null && log_repair "SUCCESS" "Servicio de red reiniciado"
        fi

        # Limpiar cache de DNS
        if command_exists systemd-resolve; then
            systemd-resolve --flush-caches 2>/dev/null && log_repair "SUCCESS" "Cache DNS limpiado"
        fi
    else
        log_repair "WARNING" "Se requieren permisos de root para reparar configuración de red"
    fi
}

# ============================================================================
# FUNCIÓN PRINCIPAL DE AUTO-REPARACIÓN CRÍTICA
# ============================================================================

auto_repair_critical() {
    log_repair "INFO" "🔍 Iniciando verificación de problemas críticos..."

    # Crear directorios necesarios
    ensure_directory "$(dirname "$CRITICAL_LOG")"

    # Inicializar contadores
    local critical_issues=0
    local repairs_performed=0

    # Verificar si ya se ejecutó recientemente (evitar spam)
    if [[ -f "$LAST_CHECK" ]]; then
        local last_check_time
        last_check_time=$(cat "$LAST_CHECK")
        local current_time
        current_time=$(date +%s)
        local time_diff=$((current_time - last_check_time))

        if [[ $time_diff -lt 300 ]]; then  # Menos de 5 minutos
            log_repair "INFO" "Verificación crítica ejecutada recientemente ($time_diff segundos atrás). Saltando..."
            return 0
        fi
    fi

    # DETECTAR PROBLEMAS CRÍTICOS
    log_repair "INFO" "🔍 Detectando problemas críticos..."

    # 1. Memoria crítica
    if detect_critical_memory; then
        log_repair "CRITICAL" "🚨 PROBLEMA CRÍTICO DE MEMORIA DETECTADO"
        ((critical_issues++))
        repair_critical_memory
        ((repairs_performed++))
    fi

    # 2. Disco crítico
    if detect_critical_disk; then
        log_repair "CRITICAL" "🚨 PROBLEMA CRÍTICO DE DISCO DETECTADO"
        ((critical_issues++))
        repair_critical_disk
        ((repairs_performed++))
    fi

    # 3. CPU/Load crítico
    if detect_critical_cpu; then
        log_repair "CRITICAL" "🚨 PROBLEMA CRÍTICO DE CPU DETECTADO"
        ((critical_issues++))
        # Para CPU, solo loggeamos, no intervenimos automáticamente
        log_repair "WARNING" "Problema de CPU detectado - se requiere intervención manual"
    fi

    # 4. Procesos críticos
    if detect_critical_processes; then
        log_repair "CRITICAL" "🚨 PROBLEMAS CRÍTICOS DE PROCESOS DETECTADOS"
        ((critical_issues++))
        repair_critical_processes
        ((repairs_performed++))
    fi

    # 5. Red crítica
    if detect_critical_network; then
        log_repair "CRITICAL" "🚨 PROBLEMA CRÍTICO DE RED DETECTADO"
        ((critical_issues++))
        repair_critical_network
        ((repairs_performed++))
    fi

    # 6. Archivos críticos faltantes
    if detect_critical_files; then
        log_repair "CRITICAL" "🚨 ARCHIVOS CRÍTICOS FALTANTES DETECTADOS"
        ((critical_issues++))
        # Para archivos críticos, solo alertamos
        log_repair "WARNING" "Archivos críticos faltantes - se requiere intervención manual urgente"
    fi

    # RESULTADOS FINALES
    if [[ $critical_issues -eq 0 ]]; then
        log_repair "SUCCESS" "✅ No se detectaron problemas críticos en el sistema"
        echo "OK - $(get_timestamp)" > "$STATUS_FILE"
    else
        log_repair "WARNING" "⚠️ Se detectaron $critical_issues problemas críticos"
        log_repair "INFO" "Se realizaron $repairs_performed reparaciones automáticas"

        if [[ $repairs_performed -gt 0 ]]; then
            log_repair "SUCCESS" "✅ Reparaciones críticas completadas exitosamente"
        fi

        echo "CRITICAL - $(get_timestamp) - Issues: $critical_issues, Repairs: $repairs_performed" > "$STATUS_FILE"
    fi

    # Actualizar timestamp de última verificación
    date +%s > "$LAST_CHECK"

    return $critical_issues
}

# ============================================================================
# FUNCIONES DE LOGGING CRÍTICO
# ============================================================================

log_critical() {
    local message="$1"
    local timestamp
    timestamp=$(get_timestamp)

    # Crear directorio si no existe
    ensure_directory "$(dirname "$CRITICAL_LOG")"

    # Escribir en log crítico
    echo "[$timestamp] CRITICAL: $message" >> "$CRITICAL_LOG"

    # También mostrar en pantalla
    echo -e "${RED}[$timestamp CRITICAL]${NC} 🚨 $message"
}

# Función para mostrar estado del sistema
show_system_status() {
    if [[ -f "$STATUS_FILE" ]]; then
        cat "$STATUS_FILE"
    else
        echo "UNKNOWN - Sistema no verificado aún"
    fi
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    local action="${1:-check}"

    case "$action" in
        "check")
            # Solo verificar, no reparar
            log_repair "INFO" "🔍 MODO VERIFICACIÓN: Solo detectar problemas críticos"
            auto_repair_critical
            ;;
        "repair")
            # Verificar y reparar
            log_repair "INFO" "🔧 MODO REPARACIÓN: Detectar y reparar problemas críticos"
            auto_repair_critical
            ;;
        "status")
            # Mostrar estado actual
            echo "Estado del sistema:"
            show_system_status
            ;;
        "log")
            # Mostrar log crítico
            if [[ -f "$CRITICAL_LOG" ]]; then
                echo "=== LOG DE PROBLEMAS CRÍTICOS ==="
                tail -20 "$CRITICAL_LOG"
            else
                echo "No hay log de problemas críticos"
            fi
            ;;
        "help"|*)
            echo "Uso: $0 [acción]"
            echo ""
            echo "Acciones disponibles:"
            echo "  check   - Solo detectar problemas críticos (sin reparar)"
            echo "  repair  - Detectar y reparar problemas críticos automáticamente"
            echo "  status  - Mostrar estado actual del sistema"
            echo "  log     - Mostrar log de problemas críticos"
            echo "  help    - Mostrar esta ayuda"
            echo ""
            echo "Ejemplos:"
            echo "  $0 check    # Verificar si hay problemas"
            echo "  $0 repair   # Reparar problemas críticos detectados"
            echo "  $0 status   # Ver estado actual"
            echo ""
            echo "Umbrales críticos configurados:"
            echo "  Memoria: >${CRITICAL_MEMORY_USAGE}% uso o <${MIN_FREE_MEMORY_MB}MB libres"
            echo "  Disco: >${CRITICAL_DISK_USAGE}% uso"
            echo "  CPU Load: >${CRITICAL_LOAD_AVERAGE}"
            ;;
    esac
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
