#!/bin/bash

# SISTEMA AUTOMÁTICO DE RECUPERACIÓN DE DESASTRES (DR)
# Núcleo principal del sistema DR para Webmin/Virtualmin
# Versión: Enterprise Professional 2025

set -euo pipefail
IFS=$'\n\t'

# Cargar configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/dr_config.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Archivo de configuración no encontrado: $CONFIG_FILE"
    exit 1
fi

# Cargar configuración
source "$CONFIG_FILE"

# Variables globales
LOG_FILE="$LOG_DIR/dr_core.log"
PID_FILE="$DR_ROOT_DIR/dr_core.pid"
STATUS_FILE="$DR_ROOT_DIR/dr_status.json"

# Funciones de logging
log_debug() {
    [[ "$LOG_LEVEL" == "debug" ]] && echo "$(date '+%Y-%m-%d %H:%M:%S') [DEBUG] $*" >> "$LOG_FILE"
}

log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*" | tee -a "$LOG_FILE"
}

log_warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" >&2 | tee -a "$LOG_FILE"
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $*" | tee -a "$LOG_FILE"
}

# Función para verificar permisos de root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_warning "Ejecutándose sin privilegios de root - Modo limitado"
        return 1
    fi
    return 0
}

# Función para crear directorios necesarios
create_directories() {
    log_info "Creando directorios del sistema DR..."

    mkdir -p "$DR_ROOT_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$TEMP_DIR"
    mkdir -p "$CERT_PATH"

    # Configurar permisos
    if check_root; then
        chown root:root "$DR_ROOT_DIR" 2>/dev/null || true
        chmod 700 "$DR_ROOT_DIR"
    else
        chmod 755 "$DR_ROOT_DIR"
    fi

    chmod 755 "$LOG_DIR"
    chmod 755 "$CONFIG_DIR"
    chmod 755 "$TEMP_DIR"

    log_success "Directorios del sistema DR creados"
}

# Función para inicializar el sistema DR
initialize_dr_system() {
    log_info "Inicializando sistema de recuperación de desastres..."

    # Crear directorios
    create_directories

    # Generar clave de encriptación si no existe
    if [[ "$ENCRYPTION_ENABLED" == "true" && ! -f "$ENCRYPTION_KEY_FILE" ]]; then
        log_info "Generando clave de encriptación..."
        openssl rand -base64 32 > "$ENCRYPTION_KEY_FILE"
        chmod 600 "$ENCRYPTION_KEY_FILE"
        log_success "Clave de encriptación generada"
    fi

    # Crear archivo de estado inicial
    cat > "$STATUS_FILE" << EOF
{
    "system_status": "initialized",
    "timestamp": "$(date -Iseconds)",
    "version": "$DR_SYSTEM_VERSION",
    "replication_status": "stopped",
    "failover_status": "standby",
    "last_health_check": null,
    "active_tests": []
}
EOF

    log_success "Sistema DR inicializado"
}

# Función para verificar estado del sistema
check_system_health() {
    log_debug "Verificando estado del sistema..."

    local health_status="healthy"
    local issues=()

    # Verificar servicios críticos
    for service in "${CRITICAL_SERVICES[@]}"; do
        if ! systemctl is-active --quiet "$service" 2>/dev/null; then
            issues+=("service_$service")
            health_status="degraded"
        fi
    done

    # Verificar uso de recursos
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    local mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

    if (( $(echo "$cpu_usage > $FAILOVER_CPU_THRESHOLD" | bc -l) )); then
        issues+=("high_cpu:$cpu_usage%")
        health_status="critical"
    fi

    if (( mem_usage > FAILOVER_MEMORY_THRESHOLD )); then
        issues+=("high_memory:$mem_usage%")
        health_status="critical"
    fi

    if (( disk_usage > FAILOVER_DISK_THRESHOLD )); then
        issues+=("high_disk:$disk_usage%")
        health_status="critical"
    fi

    # Actualizar estado
    local current_status
    current_status=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")

    cat > "$STATUS_FILE" << EOF
{
    "system_status": "$health_status",
    "timestamp": "$(date -Iseconds)",
    "version": "$DR_SYSTEM_VERSION",
    "cpu_usage": "$cpu_usage",
    "memory_usage": "$mem_usage",
    "disk_usage": "$disk_usage",
    "issues": [$(printf '"%s",' "${issues[@]}" | sed 's/,$//')],
    "last_health_check": "$(date -Iseconds)"
}
EOF

    log_debug "Estado del sistema: $health_status"

    # Retornar código de salida basado en salud
    case "$health_status" in
        "healthy") return 0 ;;
        "degraded") return 1 ;;
        "critical") return 2 ;;
        *) return 3 ;;
    esac
}

# Función para iniciar replicación
start_replication() {
    log_info "Iniciando replicación de datos..."

    local replication_script="$SCRIPT_DIR/replication_manager.sh"

    if [[ ! -x "$replication_script" ]]; then
        log_error "Script de replicación no encontrado: $replication_script"
        return 1
    fi

    # Ejecutar script de replicación
    if "$replication_script" start; then
        log_success "Replicación iniciada exitosamente"
        return 0
    else
        log_error "Error al iniciar replicación"
        return 1
    fi
}

# Función para detener replicación
stop_replication() {
    log_info "Deteniendo replicación de datos..."

    local replication_script="$SCRIPT_DIR/replication_manager.sh"

    if [[ -x "$replication_script" ]]; then
        "$replication_script" stop
    fi

    log_success "Replicación detenida"
}

# Función para ejecutar failover
execute_failover() {
    log_info "Ejecutando procedimiento de failover..."

    local failover_script="$SCRIPT_DIR/failover_orchestrator.sh"

    if [[ ! -x "$failover_script" ]]; then
        log_error "Script de failover no encontrado: $failover_script"
        return 1
    fi

    if "$failover_script" failover; then
        log_success "Failover ejecutado exitosamente"
        return 0
    else
        log_error "Error en procedimiento de failover"
        return 1
    fi
}

# Función para ejecutar recuperación
execute_recovery() {
    local recovery_type=${1:-"full"}

    log_info "Ejecutando procedimiento de recuperación: $recovery_type"

    local recovery_script="$SCRIPT_DIR/recovery_procedures.sh"

    if [[ ! -x "$recovery_script" ]]; then
        log_error "Script de recuperación no encontrado: $recovery_script"
        return 1
    fi

    if "$recovery_script" recover "$recovery_type"; then
        log_success "Recuperación ejecutada exitosamente"
        return 0
    else
        log_error "Error en procedimiento de recuperación"
        return 1
    fi
}

# Función para ejecutar pruebas DR
run_dr_tests() {
    local test_type=${1:-"full"}

    log_info "Ejecutando pruebas de recuperación de desastres: $test_type"

    local testing_script="$SCRIPT_DIR/dr_testing.sh"

    if [[ ! -x "$testing_script" ]]; then
        log_error "Script de testing no encontrado: $testing_script"
        return 1
    fi

    if "$testing_script" test "$test_type"; then
        log_success "Pruebas DR ejecutadas exitosamente"
        return 0
    else
        log_error "Error en pruebas DR"
        return 1
    fi
}

# Función para generar reportes
generate_reports() {
    log_info "Generando reportes de cumplimiento y auditoría..."

    local reporting_script="$SCRIPT_DIR/compliance_reporting.sh"

    if [[ ! -x "$reporting_script" ]]; then
        log_error "Script de reportes no encontrado: $reporting_script"
        return 1
    fi

    if "$reporting_script" generate; then
        log_success "Reportes generados exitosamente"
        return 0
    else
        log_error "Error al generar reportes"
        return 1
    fi
}

# Función para monitoreo continuo
continuous_monitoring() {
    log_info "Iniciando monitoreo continuo del sistema DR..."

    while true; do
        # Verificar salud del sistema
        if ! check_system_health; then
            local health_code=$?

            case $health_code in
                1) # Degradado
                    log_warning "Sistema degradado detectado"
                    ;;
                2) # Crítico
                    log_error "Sistema crítico detectado - Iniciando failover automático"
                    if [[ "$FAILOVER_METHOD" == "automatic" ]]; then
                        execute_failover
                    fi
                    ;;
            esac
        fi

        # Generar reportes programados (diariamente)
        if [[ $(date +%H%M) == "0200" ]]; then
            generate_reports
        fi

        # Ejecutar pruebas programadas
        if [[ "$DR_TEST_FREQUENCY" == "daily" && $(date +%H%M) == "0300" ]] ||
           [[ "$DR_TEST_FREQUENCY" == "weekly" && $(date +%u%H%M) == "70200" ]] ||
           [[ "$DR_TEST_FREQUENCY" == "monthly" && $(date +%d%H%M) == "010200" ]]; then
            run_dr_tests
        fi

        sleep "$HEALTH_CHECK_INTERVAL"
    done
}

# Función para mostrar estado del sistema
show_status() {
    echo "=========================================="
    echo "  ESTADO DEL SISTEMA DE RECUPERACIÓN DR"
    echo "=========================================="

    if [[ -f "$STATUS_FILE" ]]; then
        cat "$STATUS_FILE" | jq . 2>/dev/null || cat "$STATUS_FILE"
    else
        echo "Sistema DR no inicializado"
    fi

    echo
    echo "Procesos activos:"
    pgrep -f "dr_core.sh" | wc -l | xargs echo "Procesos DR:"

    echo
    echo "Espacio usado: $(du -sh "$DR_ROOT_DIR" 2>/dev/null | cut -f1)"
    echo "Logs recientes:"
    tail -5 "$LOG_FILE" 2>/dev/null || echo "No hay logs disponibles"
}

# Función principal
main() {
    local action=${1:-"status"}

    echo "=========================================="
    echo "  SISTEMA DE RECUPERACIÓN DE DESASTRES"
    echo "  Webmin/Virtualmin Enterprise"
    echo "=========================================="
    echo

    case "$action" in
        "init"|"initialize")
            initialize_dr_system
            ;;

        "start")
            log_info "Iniciando sistema DR completo..."

            # Verificar que esté inicializado
            if [[ ! -f "$STATUS_FILE" ]]; then
                initialize_dr_system
            fi

            # Iniciar replicación
            start_replication

            # Iniciar monitoreo continuo en background
            continuous_monitoring &
            echo $! > "$PID_FILE"

            log_success "Sistema DR iniciado completamente"
            ;;

        "stop")
            log_info "Deteniendo sistema DR..."

            # Detener replicación
            stop_replication

            # Detener monitoreo
            if [[ -f "$PID_FILE" ]]; then
                kill "$(cat "$PID_FILE")" 2>/dev/null || true
                rm -f "$PID_FILE"
            fi

            log_success "Sistema DR detenido"
            ;;

        "failover")
            execute_failover
            ;;

        "recover")
            execute_recovery "${2:-full}"
            ;;

        "test")
            run_dr_tests "${2:-full}"
            ;;

        "reports")
            generate_reports
            ;;

        "monitor")
            continuous_monitoring
            ;;

        "status")
            show_status
            ;;

        "health")
            check_system_health && echo "Sistema saludable" || echo "Problemas detectados"
            ;;

        *)
            echo "Uso: $0 {init|start|stop|failover|recover|test|reports|monitor|status|health}"
            echo
            echo "Comandos disponibles:"
            echo "  init      - Inicializar sistema DR"
            echo "  start     - Iniciar sistema DR completo"
            echo "  stop      - Detener sistema DR"
            echo "  failover  - Ejecutar failover manual"
            echo "  recover   - Ejecutar recuperación (full|partial)"
            echo "  test      - Ejecutar pruebas DR"
            echo "  reports   - Generar reportes"
            echo "  monitor   - Monitoreo continuo"
            echo "  status    - Mostrar estado del sistema"
            echo "  health    - Verificar salud del sistema"
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"