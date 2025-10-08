#!/bin/bash

# Script de integración con sistemas de monitoreo existentes
# Integra con advanced_monitoring.sh, monitor_sistema.sh, y otros sistemas

set -e

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
NOTIFICATION_SCRIPT="$SCRIPT_DIR/notification_system.sh"
LOG_DIR="/var/log/webmin_devops"
BI_SYSTEM_DIR="$PROJECT_ROOT/bi_system"
BI_DATA_COLLECTOR="$BI_SYSTEM_DIR/python/bi_data_collector.py"

# Variables
MONITORING_INTERVAL="${MONITORING_INTERVAL:-300}"  # 5 minutos por defecto
ALERT_THRESHOLD_CPU="${ALERT_THRESHOLD_CPU:-80}"
ALERT_THRESHOLD_MEMORY="${ALERT_THRESHOLD_MEMORY:-85}"
ALERT_THRESHOLD_DISK="${ALERT_THRESHOLD_DISK:-90}"

# Crear directorio de logs
mkdir -p "$LOG_DIR"

# Función de logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_DIR/monitoring_integration.log"
}

# Función para obtener métricas del sistema
get_system_metrics() {
    # CPU Usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')

    # Memory Usage
    local memory_info=$(free | grep Mem)
    local memory_used=$(echo "$memory_info" | awk '{print $3}')
    local memory_total=$(echo "$memory_info" | awk '{print $2}')
    local memory_usage=$(( (memory_used * 100) / memory_total ))

    # Disk Usage
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

    # Load Average
    local load_average=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d, -f1 | xargs)

    # Network I/O (simplified)
    local network_rx=$(cat /proc/net/dev | grep -E "^[[:space:]]*eth0|^[[:space:]]*enp" | head -1 | awk '{print $2}')
    local network_tx=$(cat /proc/net/dev | grep -E "^[[:space:]]*eth0|^[[:space:]]*enp" | head -1 | awk '{print $10}')

    echo "$cpu_usage $memory_usage $disk_usage $load_average $network_rx $network_tx"
}

# Función para verificar estado de servicios Webmin/Virtualmin
check_services_status() {
    local services_status=""

    # Verificar Webmin
    if systemctl is-active --quiet webmin 2>/dev/null; then
        services_status="${services_status}webmin:running,"
    else
        services_status="${services_status}webmin:stopped,"
    fi

    # Verificar Virtualmin (si existe)
    if systemctl is-active --quiet virtualmin 2>/dev/null; then
        services_status="${services_status}virtualmin:running,"
    elif [ -d "/etc/virtualmin" ]; then
        services_status="${services_status}virtualmin:stopped,"
    fi

    # Verificar Apache/Nginx
    if systemctl is-active --quiet apache2 2>/dev/null || systemctl is-active --quiet httpd 2>/dev/null; then
        services_status="${services_status}webserver:running,"
    else
        services_status="${services_status}webserver:stopped,"
    fi

    # Verificar MySQL/MariaDB
    if systemctl is-active --quiet mysql 2>/dev/null || systemctl is-active --quiet mariadb 2>/dev/null; then
        services_status="${services_status}database:running,"
    else
        services_status="${services_status}database:stopped,"
    fi

    # Verificar Postfix
    if systemctl is-active --quiet postfix 2>/dev/null; then
        services_status="${services_status}mailserver:running,"
    else
        services_status="${services_status}mailserver:stopped,"
    fi

    echo "${services_status%,}"
}

# Función para integrar con advanced_monitoring.sh
integrate_advanced_monitoring() {
    if [ -f "$PROJECT_ROOT/advanced_monitoring.sh" ]; then
        log "🔗 Integrating with advanced monitoring system..."

        # Ejecutar monitoreo avanzado si está disponible
        if bash "$PROJECT_ROOT/advanced_monitoring.sh" status >/dev/null 2>&1; then
            log "✅ Advanced monitoring system integrated"
            return 0
        else
            log "⚠️ Advanced monitoring system not responding"
            return 1
        fi
    else
        log "⚠️ Advanced monitoring script not found"
        return 1
    fi
}

# Función para integrar con monitor_sistema.sh
integrate_system_monitor() {
    if [ -f "$PROJECT_ROOT/monitor_sistema.sh" ]; then
        log "🔗 Integrating with system monitor..."

        # Ejecutar monitoreo del sistema
        if timeout 30 bash "$PROJECT_ROOT/monitor_sistema.sh" >/dev/null 2>&1; then
            log "✅ System monitor integrated"
            return 0
        else
            log "⚠️ System monitor execution failed or timed out"
            return 1
        fi
    else
        log "⚠️ System monitor script not found"
        return 1
    fi
}

# Función para verificar alertas y enviar notificaciones
check_alerts_and_notify() {
    local cpu_usage="$1"
    local memory_usage="$2"
    local disk_usage="$3"
    local services_status="$4"

    # Verificar alertas de recursos
    if (( $(echo "$cpu_usage > $ALERT_THRESHOLD_CPU" | bc -l 2>/dev/null || echo "0") )); then
        bash "$NOTIFICATION_SCRIPT" alert "High CPU Usage" "CPU usage at ${cpu_usage}% (threshold: ${ALERT_THRESHOLD_CPU}%)" critical
    fi

    if [ "$memory_usage" -gt "$ALERT_THRESHOLD_MEMORY" ]; then
        bash "$NOTIFICATION_SCRIPT" alert "High Memory Usage" "Memory usage at ${memory_usage}% (threshold: ${ALERT_THRESHOLD_MEMORY}%)" critical
    fi

    if [ "$disk_usage" -gt "$ALERT_THRESHOLD_DISK" ]; then
        bash "$NOTIFICATION_SCRIPT" alert "High Disk Usage" "Disk usage at ${disk_usage}% (threshold: ${ALERT_THRESHOLD_DISK}%)" warning
    fi

    # Verificar servicios críticos
    IFS=',' read -ra SERVICE_ARRAY <<< "$services_status"
    for service_status in "${SERVICE_ARRAY[@]}"; do
        IFS=':' read -r service state <<< "$service_status"
        if [ "$state" = "stopped" ]; then
            case "$service" in
                webmin|database)
                    bash "$NOTIFICATION_SCRIPT" alert "Critical Service Down" "Service $service is stopped" critical
                    ;;
                *)
                    bash "$NOTIFICATION_SCRIPT" alert "Service Down" "Service $service is stopped" warning
                    ;;
            esac
        fi
    done
}

# Función para generar reporte de estado
generate_status_report() {
    local cpu_usage="$1"
    local memory_usage="$2"
    local disk_usage="$3"
    local load_average="$4"
    local services_status="$5"

    local report_file="$LOG_DIR/status_report_$(date +%Y%m%d_%H%M%S).json"

    cat > "$report_file" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "system_metrics": {
    "cpu_usage_percent": $cpu_usage,
    "memory_usage_percent": $memory_usage,
    "disk_usage_percent": $disk_usage,
    "load_average": $load_average
  },
  "services_status": "$services_status",
  "monitoring_integrations": {
    "advanced_monitoring": $(integrate_advanced_monitoring && echo "true" || echo "false"),
    "system_monitor": $(integrate_system_monitor && echo "true" || echo "false")
  },
  "alerts_checked": true
}
EOF

    log "📊 Status report generated: $report_file"
}

# Función para integrar con el sistema BI
integrate_bi_system() {
    if [ -f "$BI_DATA_COLLECTOR" ] && [ -x "$BI_DATA_COLLECTOR" ]; then
        log "🔗 Integrating with BI system..."

        # Ejecutar colección de datos BI
        if python3 "$BI_DATA_COLLECTOR" --once >/dev/null 2>&1; then
            log "✅ BI system data collection completed"
            return 0
        else
            log "⚠️ BI system data collection failed"
            return 1
        fi
    else
        log "⚠️ BI data collector not found or not executable: $BI_DATA_COLLECTOR"
        return 1
    fi
}

# Función principal de monitoreo
perform_monitoring_cycle() {
    log "🔍 Starting monitoring cycle..."

    # Obtener métricas del sistema
    local metrics
    metrics=$(get_system_metrics)
    read -r cpu_usage memory_usage disk_usage load_average network_rx network_tx <<< "$metrics"

    log "📈 System Metrics - CPU: ${cpu_usage}%, Memory: ${memory_usage}%, Disk: ${disk_usage}%, Load: ${load_average}"

    # Verificar estado de servicios
    local services_status
    services_status=$(check_services_status)
    log "🔧 Services Status: $services_status"

    # Verificar alertas y enviar notificaciones
    check_alerts_and_notify "$cpu_usage" "$memory_usage" "$disk_usage" "$services_status"

    # Generar reporte de estado
    generate_status_report "$cpu_usage" "$memory_usage" "$disk_usage" "$load_average" "$services_status"

    # Integrar con sistema BI
    integrate_bi_system

    log "✅ Monitoring cycle completed"
}

# Función para ejecutar monitoreo continuo
run_continuous_monitoring() {
    log "🔄 Starting continuous monitoring (interval: ${MONITORING_INTERVAL}s)"

    while true; do
        perform_monitoring_cycle
        sleep "$MONITORING_INTERVAL"
    done
}

# Función para verificar configuración de integración
check_integration_config() {
    log "🔧 Checking monitoring integration configuration..."

    local issues_found=0

    # Verificar scripts de notificación
    if [ ! -x "$NOTIFICATION_SCRIPT" ]; then
        log "❌ Notification script not found or not executable: $NOTIFICATION_SCRIPT"
        issues_found=$((issues_found + 1))
    else
        log "✅ Notification script ready"
    fi

    # Verificar scripts de monitoreo existentes
    local monitoring_scripts=(
        "$PROJECT_ROOT/advanced_monitoring.sh"
        "$PROJECT_ROOT/monitor_sistema.sh"
        "$BI_DATA_COLLECTOR"
    )

    for script in "${monitoring_scripts[@]}"; do
        if [ -f "$script" ]; then
            if [ -x "$script" ]; then
                log "✅ Monitoring script found: $(basename "$script")"
            else
                log "⚠️ Monitoring script not executable: $(basename "$script")"
            fi
        else
            log "⚠️ Monitoring script not found: $(basename "$script")"
        fi
    done

    # Verificar permisos de directorio de logs
    if [ -w "$LOG_DIR" ]; then
        log "✅ Log directory writable"
    else
        log "❌ Log directory not writable: $LOG_DIR"
        issues_found=$((issues_found + 1))
    fi

    # Verificar herramientas necesarias
    local required_commands=("curl" "systemctl" "top" "free" "df")
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log "✅ Command available: $cmd"
        else
            log "⚠️ Command not available: $cmd"
            issues_found=$((issues_found + 1))
        fi
    done

    if [ $issues_found -eq 0 ]; then
        log "🎉 All integration checks passed"
        return 0
    else
        log "⚠️ $issues_found integration issues found"
        return 1
    fi
}

# Mostrar ayuda
show_help() {
    cat << EOF
Sistema de Integración de Monitoreo Webmin/Virtualmin DevOps

Uso: $0 <comando>

Comandos disponibles:
  check-config          Verificar configuración de integración
  monitor-once          Ejecutar un ciclo de monitoreo único
  monitor-continuous    Ejecutar monitoreo continuo
  test-integration      Probar integración con sistemas existentes

Variables de entorno:
  MONITORING_INTERVAL   Intervalo entre ciclos de monitoreo (segundos, default: 300)
  ALERT_THRESHOLD_CPU   Umbral de alerta CPU (%) (default: 80)
  ALERT_THRESHOLD_MEMORY Umbral de alerta memoria (%) (default: 85)
  ALERT_THRESHOLD_DISK  Umbral de alerta disco (%) (default: 90)

Ejemplos:
  $0 check-config
  $0 monitor-once
  MONITORING_INTERVAL=60 $0 monitor-continuous
EOF
}

# Procesar argumentos
case "${1:-help}" in
    check-config)
        check_integration_config
        ;;
    monitor-once)
        perform_monitoring_cycle
        ;;
    monitor-continuous)
        run_continuous_monitoring
        ;;
    test-integration)
        log "🧪 Testing monitoring integration..."
        integrate_advanced_monitoring
        integrate_system_monitor
        integrate_bi_system
        log "✅ Integration test completed"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "❌ Comando desconocido: $1"
        echo ""
        show_help
        exit 1
        ;;
esac