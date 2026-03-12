#!/bin/bash

# Sistema de Monitoreo Continuo Enterprise
# Monitorea el estado del sistema en tiempo real
# Versión: Enterprise Professional 2025

set -euo pipefail
IFS=$'\n\t'

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_LOG="$SCRIPT_DIR/monitoring.log"
ALERT_LOG="$SCRIPT_DIR/alerts.log"
STATUS_FILE="$SCRIPT_DIR/system_status.json"
METRICS_DIR="$SCRIPT_DIR/metrics"

# Umbrales de monitoreo
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=90
NETWORK_TIMEOUT=5

# Funciones de logging
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*" | tee -a "$MONITOR_LOG"
}

log_warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $*" | tee -a "$MONITOR_LOG" | tee -a "$ALERT_LOG"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" >&2 | tee -a "$MONITOR_LOG" | tee -a "$ALERT_LOG"
}

log_alert() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ALERT] $*" | tee -a "$ALERT_LOG"
}

# Crear directorios necesarios
setup_monitoring() {
    mkdir -p "$METRICS_DIR"
    touch "$MONITOR_LOG" "$ALERT_LOG" "$STATUS_FILE"
}

# Monitoreo de CPU
monitor_cpu() {
    # Para macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')
        local cpu_cores=$(sysctl -n hw.ncpu)
        local load_avg=$(uptime | awk -F'load averages:' '{ print $2 }' | cut -d, -f1 | xargs)
    else
        # Para Linux
        local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
        local cpu_cores=$(nproc)
        local load_avg=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d, -f1 | xargs)
    fi

    echo "$cpu_usage $cpu_cores $load_avg"

    # Verificar umbrales
    if (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l 2>/dev/null || echo "0") )); then
        log_warning "Uso de CPU alto: ${cpu_usage}% (umbral: ${CPU_THRESHOLD}%)"
    fi

    if (( $(echo "$load_avg > $cpu_cores" | bc -l 2>/dev/null || echo "0") )); then
        log_warning "Load average alto: $load_avg (cores: $cpu_cores)"
    fi
}

# Monitoreo de memoria
monitor_memory() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Para macOS
        local mem_info=$(vm_stat | grep "Pages free\|Pages active\|Pages inactive\|Pages wired")
        local pages_free=$(echo "$mem_info" | grep "Pages free" | awk '{print $3}' | tr -d '.')
        local pages_active=$(echo "$mem_info" | grep "Pages active" | awk '{print $3}' | tr -d '.')
        local pages_wired=$(echo "$mem_info" | grep "Pages wired" | awk '{print $3}' | tr -d '.')

        local page_size=$(sysctl -n vm.pagesize)
        local total_mem=$(( $(sysctl -n hw.memsize) / 1024 / 1024 )) # MB
        local used_mem=$(( (pages_active + pages_wired) * page_size / 1024 / 1024 )) # MB
        local mem_usage=$(( used_mem * 100 / total_mem ))

        local total_swap=0
        local used_swap=0
    else
        # Para Linux
        local mem_info=$(free | grep Mem)
        local total_mem=$(echo "$mem_info" | awk '{print $2}')
        local used_mem=$(echo "$mem_info" | awk '{print $3}')
        local mem_usage=$((used_mem * 100 / total_mem))

        local swap_info=$(free | grep Swap)
        local total_swap=$(echo "$swap_info" | awk '{print $2}')
        local used_swap=$(echo "$swap_info" | awk '{print $3}')
    fi

    echo "$total_mem $used_mem $mem_usage $total_swap $used_swap"

    # Verificar umbrales
    if [[ $mem_usage -gt $MEMORY_THRESHOLD ]]; then
        log_warning "Uso de memoria alto: ${mem_usage}% (umbral: ${MEMORY_THRESHOLD}%)"
    fi

    if [[ $total_swap -gt 0 && $used_swap -gt 0 ]]; then
        local swap_usage=$((used_swap * 100 / total_swap))
        if [[ $swap_usage -gt 50 ]]; then
            log_warning "Uso de swap alto: ${swap_usage}%"
        fi
    fi
}

# Monitoreo de disco
monitor_disk() {
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

    echo "$disk_usage"

    if [[ $disk_usage -gt $DISK_THRESHOLD ]]; then
        log_warning "Uso de disco alto: ${disk_usage}% (umbral: ${DISK_THRESHOLD}%)"
    fi

    # Verificar inodos
    local inode_usage=$(df -i / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $inode_usage -gt 90 ]]; then
        log_warning "Uso de inodos alto: ${inode_usage}%"
    fi
}

# Monitoreo de red
monitor_network() {
    local network_status="OK"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Para macOS
        local interfaces=$(ifconfig -l)
        for interface in $interfaces; do
            if [[ $interface != "lo0" ]]; then
                local status=$(ifconfig "$interface" 2>/dev/null | grep -o "status: [a-z]*" | cut -d: -f2)
                if [[ $status != "active" ]]; then
                    log_warning "Interfaz de red $interface está DOWN"
                    network_status="DEGRADED"
                fi
            fi
        done
    else
        # Para Linux
        local interfaces=$(ip link show | grep -E '^[0-9]+:' | cut -d: -f2 | xargs)
        for interface in $interfaces; do
            if [[ $interface != "lo" ]]; then
                local status=$(ip link show "$interface" | grep -o "state [A-Z]*" | cut -d' ' -f2)
                if [[ $status != "UP" ]]; then
                    log_warning "Interfaz de red $interface está DOWN"
                    network_status="DEGRADED"
                fi
            fi
        done
    fi

    # Verificar conectividad
    if ! ping -c 1 -t $NETWORK_TIMEOUT 8.8.8.8 &>/dev/null; then
        log_error "Sin conectividad a internet"
        network_status="DOWN"
    fi

    echo "$network_status"
}

# Monitoreo de servicios
monitor_services() {
    local critical_services=("sshd" "rsyslog" "cron")
    local failed_services=()

    for service in "${critical_services[@]}"; do
        # En macOS y desarrollo, verificar procesos en lugar de servicios
        if ! pgrep -x "$service" >/dev/null 2>&1; then
            log_error "Servicio crítico $service no está ejecutándose"
            failed_services+=("$service")
        fi
    done

    echo "${#failed_services[@]}"
}

# Monitoreo de procesos
monitor_processes() {
    local zombie_processes=$(ps aux | awk '{print $8}' | grep -c 'Z')
    local total_processes=$(ps aux | wc -l)

    echo "$zombie_processes $total_processes"

    if [[ $zombie_processes -gt 0 ]]; then
        log_warning "Procesos zombie detectados: $zombie_processes"
    fi

    if [[ $total_processes -gt 1000 ]]; then
        log_warning "Número alto de procesos: $total_processes"
    fi
}

# Monitoreo de logs del sistema
monitor_logs() {
    local log_errors=0

    # Verificar logs de sistema
    if [[ -f /var/log/syslog ]]; then
        local recent_errors=$(tail -1000 /var/log/syslog | grep -i -c "error\|fail\|crit" || true)
        if [[ $recent_errors -gt 10 ]]; then
            log_warning "Errores recientes en syslog: $recent_errors"
            log_errors=$((log_errors + recent_errors))
        fi
    fi

    # Verificar logs de autenticación
    if [[ -f /var/log/auth.log ]]; then
        local failed_logins=$(tail -1000 /var/log/auth.log | grep -c "Failed password\|authentication failure" || true)
        if [[ $failed_logins -gt 5 ]]; then
            log_warning "Intentos de login fallidos recientes: $failed_logins"
            log_errors=$((log_errors + failed_logins))
        fi
    fi

    echo "$log_errors"
}

# Generar reporte de estado
generate_status_report() {
    local timestamp=$(date +%s)
    local metrics_file="$METRICS_DIR/metrics_$timestamp.json"

    # Recopilar métricas
    local cpu_data=$(monitor_cpu)
    local mem_data=$(monitor_memory)
    local disk_data=$(monitor_disk)
    local net_data=$(monitor_network)
    local services_data=$(monitor_services)
    local proc_data=$(monitor_processes)
    local logs_data=$(monitor_logs)

    # Parsear datos
    local cpu_usage=$(echo "$cpu_data" | awk '{print $1}')
    local cpu_cores=$(echo "$cpu_data" | awk '{print $2}')
    local load_avg=$(echo "$cpu_data" | awk '{print $3}')

    local total_mem=$(echo "$mem_data" | awk '{print $1}')
    local used_mem=$(echo "$mem_data" | awk '{print $2}')
    local mem_usage=$(echo "$mem_data" | awk '{print $3}')

    local disk_usage=$(echo "$disk_data" | awk '{print $1}')
    local network_status="$net_data"
    local failed_services="$services_data"

    local zombie_proc=$(echo "$proc_data" | awk '{print $1}')
    local total_proc=$(echo "$proc_data" | awk '{print $2}')

    local log_errors="$logs_data"

    # Generar JSON de estado
    cat > "$STATUS_FILE" << EOF
{
  "timestamp": "$timestamp",
  "hostname": "$(hostname)",
  "system": {
    "cpu_usage": $cpu_usage,
    "cpu_cores": $cpu_cores,
    "load_average": $load_avg,
    "memory_total": $total_mem,
    "memory_used": $used_mem,
    "memory_usage_percent": $mem_usage,
    "disk_usage_percent": $disk_usage,
    "network_status": "$network_status",
    "failed_services": $failed_services,
    "zombie_processes": $zombie_proc,
    "total_processes": $total_proc,
    "log_errors": $log_errors
  },
  "status": "healthy"
}
EOF

    # Generar métricas detalladas
    cat > "$metrics_file" << EOF
{
  "timestamp": "$timestamp",
  "metrics": {
    "cpu": {
      "usage_percent": $cpu_usage,
      "cores": $cpu_cores,
      "load_average": $load_avg
    },
    "memory": {
      "total_kb": $total_mem,
      "used_kb": $used_mem,
      "usage_percent": $mem_usage
    },
    "disk": {
      "usage_percent": $disk_usage
    },
    "network": {
      "status": "$network_status"
    },
    "services": {
      "failed_count": $failed_services
    },
    "processes": {
      "zombie_count": $zombie_proc,
      "total_count": $total_proc
    },
    "logs": {
      "error_count": $log_errors
    }
  }
}
EOF

    log_info "Reporte de estado generado: $STATUS_FILE"
}

# Función de monitoreo continuo
continuous_monitoring() {
    log_info "Iniciando monitoreo continuo..."

    while true; do
        generate_status_report

        # Verificar estado general
        local failed_services=$(monitor_services)
        local network_status=$(monitor_network)

        if [[ $failed_services -gt 0 || $network_status != "OK" ]]; then
            log_alert "Sistema en estado DEGRADADO - Servicios fallidos: $failed_services, Red: $network_status"
        fi

        # Esperar intervalo (30 segundos)
        sleep 30
    done
}

# Función de verificación de estado
check_system_health() {
    log_info "=== VERIFICACIÓN DE SALUD DEL SISTEMA ==="

    local issues=0

    # Verificar CPU
    local cpu_data=$(monitor_cpu)
    local cpu_usage=$(echo "$cpu_data" | awk '{print $1}')
    if (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l) )); then
        log_error "CPU: USO ALTO (${cpu_usage}%)"
        issues=$((issues + 1))
    else
        log_info "CPU: OK (${cpu_usage}%)"
    fi

    # Verificar memoria
    local mem_data=$(monitor_memory)
    local mem_usage=$(echo "$mem_data" | awk '{print $3}')
    if [[ $mem_usage -gt $MEMORY_THRESHOLD ]]; then
        log_error "Memoria: USO ALTO (${mem_usage}%)"
        issues=$((issues + 1))
    else
        log_info "Memoria: OK (${mem_usage}%)"
    fi

    # Verificar disco
    local disk_usage=$(monitor_disk)
    if [[ $disk_usage -gt $DISK_THRESHOLD ]]; then
        log_error "Disco: USO ALTO (${disk_usage}%)"
        issues=$((issues + 1))
    else
        log_info "Disco: OK (${disk_usage}%)"
    fi

    # Verificar red
    local network_status=$(monitor_network)
    if [[ $network_status != "OK" ]]; then
        log_error "Red: ESTADO $network_status"
        issues=$((issues + 1))
    else
        log_info "Red: OK"
    fi

    # Verificar servicios
    local failed_services=$(monitor_services)
    if [[ $failed_services -gt 0 ]]; then
        log_error "Servicios: $failed_services FALLIDOS"
        issues=$((issues + 1))
    else
        log_info "Servicios: OK"
    fi

    if [[ $issues -eq 0 ]]; then
        log_info "✅ SISTEMA SALUDABLE - Sin problemas detectados"
        return 0
    else
        log_error "❌ SISTEMA CON PROBLEMAS - $issues problemas detectados"
        return 1
    fi
}

# Función principal
main() {
    local action=${1:-"status"}

    echo "=========================================="
    echo "  MONITOREO CONTINUO ENTERPRISE"
    echo "  Sistema Webmin/Virtualmin"
    echo "=========================================="
    echo

    setup_monitoring

    case "$action" in
        "start")
            log_info "Iniciando monitoreo continuo..."
            continuous_monitoring
            ;;

        "status")
            check_system_health
            echo
            echo "=== ÚLTIMO ESTADO ==="
            if [[ -f "$STATUS_FILE" ]]; then
                cat "$STATUS_FILE"
            else
                echo "No hay datos de estado disponibles"
            fi
            ;;

        "report")
            generate_status_report
            echo "Reporte generado: $STATUS_FILE"
            ;;

        "alerts")
            echo "=== ÚLTIMAS ALERTAS ==="
            if [[ -f "$ALERT_LOG" ]]; then
                tail -20 "$ALERT_LOG"
            else
                echo "No hay alertas registradas"
            fi
            ;;

        *)
            echo "Uso: $0 {start|status|report|alerts}"
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"