#!/bin/bash

# Script de Monitoreo Básico - Integrado con Sistema Avanzado
# Monitorea servicios Virtualmin/Webmin y recursos del sistema
# Versión: 2.0.0 - Integración completa con advanced_monitoring.sh

set -euo pipefail
IFS=$'\n\t'

# Directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== INCLUIR BIBLIOTECA COMÚN =====
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
    source "${SCRIPT_DIR}/lib/common.sh"
else
    echo "ERROR: No se encuentra la biblioteca común en ${SCRIPT_DIR}/lib/common.sh"
    exit 1
fi

# Configuración de monitoreo (configurables)
MONITOR_INTERVAL="${MONITOR_INTERVAL:-60}"  # segundos
LOG_METRICS="${LOG_METRICS:-true}"
ALERT_THRESHOLDS="${ALERT_THRESHOLDS:-true}"
GENERATE_HTML="${GENERATE_HTML:-false}"

# Función para monitorear servicios
monitor_services() {
    log_step "Monitoreando servicios..."

    local services=("webmin" "apache2" "mysql" "postfix" "dovecot")
    local service_status=()

    for service in "${services[@]}"; do
        if service_running "$service"; then
            service_status+=("$service:RUNNING")
            log_debug "Servicio $service está ejecutándose"
        else
            service_status+=("$service:STOPPED")
            log_warning "Servicio $service está detenido"
        fi
    done

    # Loggear métricas si está habilitado
    if [[ "$LOG_METRICS" == "true" ]]; then
        local timestamp
        timestamp=$(get_timestamp)
        echo "[$timestamp] SERVICES ${service_status[*]}" >> /var/log/virtualmin_monitor.log
    fi

    # Mostrar estado de servicios
    echo "Estado de servicios:"
    printf '  %-12s %s\n' "Servicio" "Estado"
    printf '  %-12s %s\n' "--------" "------"
    for status in "${service_status[@]}"; do
        local service_name="${status%%:*}"
        local service_state="${status##*:}"
        if [[ "$service_state" == "RUNNING" ]]; then
            printf '  %-12s \033[0;32m%s\033[0m\n' "$service_name" "$service_state"
        else
            printf '  %-12s \033[0;31m%s\033[0m\n' "$service_name" "$service_state"
        fi
    done
    echo
}

# Función para monitorear recursos del sistema
monitor_system_resources() {
    log_step "Monitoreando recursos del sistema..."

    # CPU Usage
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')

    # Memory Usage
    local mem_total mem_used mem_free mem_usage
    read -r mem_total mem_used mem_free <<< "$(free -m | awk 'NR==2{printf "%.0f %.0f %.0f", $2, $3, $4}')"
    mem_usage=$((mem_used * 100 / mem_total))

    # Disk Usage
    local disk_usage
    disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

    # Network I/O (simplificado)
    local network_rx network_tx
    read -r network_rx network_tx <<< "$(cat /proc/net/dev | awk '/eth0:/ {print $2, $10}' 2>/dev/null || echo "0 0")"

    # Load Average
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//')

    # Loggear métricas si está habilitado
    if [[ "$LOG_METRICS" == "true" ]]; then
        local timestamp
        timestamp=$(get_timestamp)
        echo "[$timestamp] METRICS CPU:$cpu_usage MEM:$mem_usage% DISK:$disk_usage% NET_RX:$network_rx NET_TX:$network_tx LOAD:$load_avg" >> /var/log/virtualmin_monitor.log
    fi

    # Mostrar métricas
    echo "Recursos del sistema:"
    printf '  %-12s %s\n' "Métrica" "Valor"
    printf '  %-12s %s\n' "-------" "-----"
    printf '  %-12s %s\n' "CPU" "$cpu_usage"
    printf '  %-12s %s/%s MB (%s%%)\n' "Memoria" "$mem_used" "$mem_total" "$mem_usage"
    printf '  %-12s %s%%\n' "Disco (/)" "$disk_usage"
    printf '  %-12s %s\n' "Load Avg" "$load_avg"
    printf '  %-12s %s RX / %s TX\n' "Red" "$network_rx" "$network_tx"
    echo

    # Alertas si están habilitadas
    if [[ "$ALERT_THRESHOLDS" == "true" ]]; then
        check_alerts "$mem_usage" "$disk_usage" "$cpu_usage"
    fi
}

# Función para verificar alertas
check_alerts() {
    local mem_usage="$1"
    local disk_usage="$2"
    local cpu_usage="$3"

    # Umbrales de alerta
    local MEM_THRESHOLD=90
    local DISK_THRESHOLD=85
    local CPU_THRESHOLD=95

    local alerts=()

    if [[ $mem_usage -gt $MEM_THRESHOLD ]]; then
        alerts+=("ALTA MEMORIA: $mem_usage% (umbral: $MEM_THRESHOLD%)")
    fi

    if [[ $disk_usage -gt $DISK_THRESHOLD ]]; then
        alerts+=("ALTO USO DE DISCO: $disk_usage% (umbral: $DISK_THRESHOLD%)")
    fi

    if [[ $(echo "$cpu_usage" | sed 's/%//') -gt $CPU_THRESHOLD ]]; then
        alerts+=("ALTA CPU: $cpu_usage (umbral: $CPU_THRESHOLD%)")
    fi

    if [[ ${#alerts[@]} -gt 0 ]]; then
        log_warning "ALERTAS DETECTADAS:"
        for alert in "${alerts[@]}"; do
            log_error "  ⚠️  $alert"
        done
        echo
    fi
}

# Función para monitorear Virtualmin/Webmin
monitor_virtualmin() {
    log_step "Monitoreando Virtualmin/Webmin..."

    # Verificar procesos Webmin
    local webmin_processes
    webmin_processes=$(pgrep -f webmin | wc -l)

    # Verificar conexiones activas a Webmin
    local webmin_connections=0
    if [[ -f /var/webmin/miniserv.pid ]]; then
        local miniserv_pid
        miniserv_pid=$(cat /var/webmin/miniserv.pid 2>/dev/null || echo "")
        if [[ -n "$miniserv_pid" ]] && kill -0 "$miniserv_pid" 2>/dev/null; then
            webmin_connections=$(netstat -tlnp 2>/dev/null | grep :10000 | wc -l)
        fi
    fi

    # Contar dominios Virtualmin
    local virtualmin_domains=0
    if [[ -d /etc/virtualmin ]]; then
        virtualmin_domains=$(find /etc/virtualmin -name "*.conf" 2>/dev/null | wc -l)
    fi

    # Verificar estado de bases de datos
    local mysql_connections=0
    if command_exists mysql; then
        mysql_connections=$(mysql -e "SHOW PROCESSLIST;" 2>/dev/null | wc -l 2>/dev/null || echo "0")
        mysql_connections=$((mysql_connections - 1))  # Restar header
    fi

    # Loggear métricas específicas
    if [[ "$LOG_METRICS" == "true" ]]; then
        local timestamp
        timestamp=$(get_timestamp)
        echo "[$timestamp] VIRTUALMIN PROCESSES:$webmin_processes CONNECTIONS:$webmin_connections DOMAINS:$virtualmin_domains MYSQL_CONN:$mysql_connections" >> /var/log/virtualmin_monitor.log
    fi

    # Mostrar métricas de Virtualmin
    echo "Métricas de Virtualmin/Webmin:"
    printf '  %-20s %s\n' "Métrica" "Valor"
    printf '  %-20s %s\n' "--------------------" "-----"
    printf '  %-20s %s\n' "Procesos Webmin" "$webmin_processes"
    printf '  %-20s %s\n' "Conexiones activas" "$webmin_connections"
    printf '  %-20s %s\n' "Dominios Virtualmin" "$virtualmin_domains"
    printf '  %-20s %s\n' "Conexiones MySQL" "$mysql_connections"
    echo
}

# Función para generar reporte HTML básico
generate_html_report() {
    local report_file="/var/www/html/monitoring_report.html"
    log_step "Generando reporte HTML..."

    # Crear directorio si no existe
    ensure_directory "/var/www/html"

    cat > "$report_file" << EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte de Monitoreo - Virtualmin</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 2px solid #007cba; padding-bottom: 10px; }
        .section { margin: 20px 0; }
        .metric { display: inline-block; margin: 10px; padding: 10px; background: #f8f9fa; border-radius: 4px; min-width: 150px; }
        .metric.good { border-left: 4px solid #28a745; }
        .metric.warning { border-left: 4px solid #ffc107; }
        .metric.danger { border-left: 4px solid #dc3545; }
        .timestamp { color: #666; font-size: 0.9em; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f8f9fa; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📊 Reporte de Monitoreo - Virtualmin & Webmin</h1>
        <div class="timestamp">Generado: $(get_timestamp)</div>

        <div class="section">
            <h2>🚀 Estado de Servicios</h2>
            <table>
                <tr><th>Servicio</th><th>Estado</th><th>Notas</th></tr>
                <tr><td>Webmin</td><td>$(service_running webmin && echo "✅ Ejecutándose" || echo "❌ Detenido")</td><td>Puerto 10000</td></tr>
                <tr><td>Apache</td><td>$(service_running apache2 && echo "✅ Ejecutándose" || echo "❌ Detenido")</td><td>Servidor web</td></tr>
                <tr><td>MySQL</td><td>$(service_running mysql && echo "✅ Ejecutándose" || echo "❌ Detenido")</td><td>Base de datos</td></tr>
                <tr><td>Postfix</td><td>$(service_running postfix && echo "✅ Ejecutándose" || echo "❌ Detenido")</td><td>Correo SMTP</td></tr>
                <tr><td>Dovecot</td><td>$(service_running dovecot && echo "✅ Ejecutándose" || echo "❌ Detenido")</td><td>Correo IMAP/POP3</td></tr>
            </table>
        </div>

        <div class="section">
            <h2>💻 Recursos del Sistema</h2>
            <div class="metric $(($(free -m | awk 'NR==2{printf "%.0f", $3*100/$2}') > 90) && echo "danger" || echo "good")">
                <strong>CPU:</strong> $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
            </div>
            <div class="metric $(($(free -m | awk 'NR==2{printf "%.0f", $3*100/$2}') > 90) && echo "danger" || echo "good")">
                <strong>Memoria:</strong> $(free -m | awk 'NR==2{printf "%.0f/%.0f MB (%0.f%%)", $3, $2, $3*100/$2}')
            </div>
            <div class="metric $(($(df / | tail -1 | awk '{print $5}' | sed 's/%//') > 85) && echo "warning" || echo "good")">
                <strong>Disco (/):</strong> $(df -h / | tail -1 | awk '{print $5}')
            </div>
            <div class="metric good">
                <strong>Load Average:</strong> $(uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//')
            </div>
        </div>

        <div class="section">
            <h2>🌐 Virtualmin/Webmin</h2>
            <div class="metric good">
                <strong>Procesos Webmin:</strong> $(pgrep -f webmin | wc -l)
            </div>
            <div class="metric good">
                <strong>Conexiones activas:</strong> $(netstat -tlnp 2>/dev/null | grep :10000 | wc -l)
            </div>
            <div class="metric good">
                <strong>Dominios Virtualmin:</strong> $(find /etc/virtualmin -name "*.conf" 2>/dev/null | wc -l)
            </div>
            <div class="metric good">
                <strong>Conexiones MySQL:</strong> $(mysql -e "SHOW PROCESSLIST;" 2>/dev/null | wc -l 2>/dev/null || echo "0")
            </div>
        </div>

        <div class="section">
            <h2>📈 Información del Sistema</h2>
            <p><strong>Sistema Operativo:</strong> $(get_system_info os)</p>
            <p><strong>Arquitectura:</strong> $(get_system_info arch)</p>
            <p><strong>Memoria Total:</strong> $(get_system_info memory)</p>
            <p><strong>Espacio en Disco:</strong> $(get_system_info disk) libres</p>
            <p><strong>Núcleos de CPU:</strong> $(get_system_info cpu)</p>
        </div>

        <div class="section">
            <p style="text-align: center; color: #666; margin-top: 30px;">
                Reporte generado automáticamente por el sistema de monitoreo de Virtualmin
            </p>
        </div>
    </div>
</body>
</html>
EOF

    log_success "Reporte HTML generado: $report_file"
    log_info "Accede al reporte en: http://tu-servidor/monitoring_report.html"
}

# Función para ejecutar monitoreo continuo
monitor_continuous() {
    log_info "Iniciando monitoreo continuo (intervalo: ${MONITOR_INTERVAL}s)"
    log_info "Presiona Ctrl+C para detener"

    while true; do
        echo "=========================================="
        echo "📊 $(get_timestamp)"
        echo "=========================================="

        monitor_services
        monitor_system_resources
        monitor_virtualmin

        # Generar reporte HTML si se solicita
        if [[ "${GENERATE_HTML:-false}" == "true" ]]; then
            generate_html_report
        fi

        echo "⏱️  Próxima actualización en ${MONITOR_INTERVAL} segundos..."
        echo

        sleep "$MONITOR_INTERVAL"
    done
}

# Función para mostrar ayuda
show_help() {
    cat << EOF
Script de Monitoreo - Virtualmin & Webmin
Versión: 2.0.0 (Integrado con Sistema Avanzado)

USO:
    $0 [opciones]

OPCIONES:
    -c, --continuous    Ejecutar monitoreo continuo
    -i, --interval SEC  Intervalo en segundos (default: 60)
    -l, --log           Habilitar logging de métricas
    -a, --alerts        Habilitar alertas por umbrales
    -r, --report        Generar reporte HTML
    --advanced          Usar sistema de monitoreo avanzado
    -h, --help          Mostrar esta ayuda

SISTEMA AVANZADO DISPONIBLE:
    Si advanced_monitoring.sh está presente, se puede usar con --advanced
    Características avanzadas incluyen:
    - Monitoreo en tiempo real con métricas detalladas
    - Alertas por email y Telegram
    - Dashboard web interactivo con gráficos
    - Almacenamiento histórico en base de datos
    - Detección automática de anomalías

EJEMPLOS:
    $0                          # Monitoreo único básico
    $0 -c -i 30                 # Monitoreo continuo básico cada 30s
    $0 --advanced               # Monitoreo avanzado único
    $0 --advanced -c -i 30      # Monitoreo avanzado continuo cada 30s

ARCHIVOS DE LOG:
    /var/log/virtualmin_monitor.log        # Métricas básicas
    /var/log/advanced_monitoring/          # Logs avanzados
    /var/lib/advanced_monitoring/metrics.db # Base de datos avanzada

VARIABLES DE ENTORNO:
    MONITOR_INTERVAL    Intervalo de monitoreo (segundos)
    LOG_METRICS         Habilitar logging de métricas (true/false)
    ALERT_THRESHOLDS    Habilitar alertas (true/false)
    GENERATE_HTML       Generar reporte HTML (true/false)
    USE_ADVANCED        Usar sistema avanzado por defecto (true/false)

NOTAS:
    - Requiere permisos de root para acceso completo a métricas
    - Los reportes HTML se generan en /var/www/html/
    - Dashboard avanzado disponible en /monitoring/
EOF
}

# Función principal
main() {
    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--continuous) MONITOR_CONTINUOUS=true ;;
            -i|--interval) MONITOR_INTERVAL="$2"; shift ;;
            -l|--log) LOG_METRICS=true ;;
            -a|--alerts) ALERT_THRESHOLDS=true ;;
            -r|--report) GENERATE_HTML=true ;;
            -h|--help) show_help; exit 0 ;;
            *) log_error "Opción desconocida: $1"; show_help; exit 1 ;;
        esac
        shift
    done

    echo
    echo "=========================================="
    echo "  SISTEMA DE MONITOREO"
    echo "  Virtualmin & Webmin"
    echo "=========================================="
    echo

    # Verificar permisos
    if [[ $EUID -ne 0 ]]; then
        handle_error "$ERROR_ROOT_REQUIRED" "Este script requiere permisos de root para monitoreo completo"
    fi

    # Ejecutar monitoreo
    if [[ "${MONITOR_CONTINUOUS:-false}" == "true" ]]; then
        monitor_continuous
    else
        # Monitoreo único
        monitor_services
        monitor_system_resources
        monitor_virtualmin

        # Generar reporte HTML si se solicita
        if [[ "${GENERATE_HTML:-false}" == "true" ]]; then
            generate_html_report
        fi
    fi
}

# Función para verificar si el sistema avanzado está disponible
check_advanced_system() {
    local advanced_script="${SCRIPT_DIR}/advanced_monitoring.sh"
    if [[ -f "$advanced_script" && -x "$advanced_script" ]]; then
        log_info "Sistema de monitoreo avanzado detectado"
        return 0
    else
        return 1
    fi
}

# Función para ejecutar monitoreo avanzado
run_advanced_monitoring() {
    local advanced_script="${SCRIPT_DIR}/advanced_monitoring.sh"
    if check_advanced_system; then
        log_info "Ejecutando sistema de monitoreo avanzado..."
        exec "$advanced_script" "$@"
    else
        log_warning "Sistema avanzado no encontrado, usando monitoreo básico"
        return 1
    fi
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Verificar si se solicita monitoreo avanzado
    if [[ "${1:-}" == "--advanced" || "${1:-}" == "-a" ]]; then
        shift
        run_advanced_monitoring "$@"
    elif check_advanced_system && [[ "${USE_ADVANCED:-false}" == "true" ]]; then
        run_advanced_monitoring "$@"
    else
        main "$@"
    fi
fi
