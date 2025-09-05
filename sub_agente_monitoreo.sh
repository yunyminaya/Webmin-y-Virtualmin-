#!/bin/bash

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -euo pipefail
IFS=$'\n\t'
trap 'echo "[ERROR] sub_agente_monitoreo.sh fallo en línea $LINENO" >&2' ERR

# Sub-Agente de Monitoreo del Sistema
# Monitorea recursos del sistema, servicios y estado general

LOG_FILE="/var/log/sub_agente_monitoreo.log"
CONFIG_FILE="/etc/webmin/sub_agente_monitoreo.conf"
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEMORY=85
ALERT_THRESHOLD_DISK=90

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_system_resources() {
    log_message "=== VERIFICACIÓN DE RECURSOS DEL SISTEMA ==="
    
    # CPU Usage
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d',' -f1)
    log_message "Uso de CPU: ${CPU_USAGE}%"
    
    if awk -v a="$CPU_USAGE" -v b="$ALERT_THRESHOLD_CPU" 'BEGIN{exit (a>b)?0:1}'; then
        log_message "ALERTA: Uso de CPU alto: ${CPU_USAGE}%"
        send_alert "CPU" "$CPU_USAGE"
    fi
    
    # Memory Usage
    MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.1f", ($3/$2) * 100.0)}')
    log_message "Uso de Memoria: ${MEMORY_USAGE}%"
    
    if awk -v a="$MEMORY_USAGE" -v b="$ALERT_THRESHOLD_MEMORY" 'BEGIN{exit (a>b)?0:1}'; then
        log_message "ALERTA: Uso de memoria alto: ${MEMORY_USAGE}%"
        send_alert "MEMORIA" "$MEMORY_USAGE"
    fi
    
    # Disk Usage
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
    log_message "Uso de Disco: ${DISK_USAGE}%"
    
    if [ "$DISK_USAGE" -gt "$ALERT_THRESHOLD_DISK" ]; then
        log_message "ALERTA: Uso de disco alto: ${DISK_USAGE}%"
        send_alert "DISCO" "$DISK_USAGE"
    fi
}

check_services() {
    log_message "=== VERIFICACIÓN DE SERVICIOS ==="
    
    SERVICES=("webmin" "apache2" "nginx" "mysql" "postgresql" "postfix" "bind9" "ssh")
    
    for service in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log_message "✓ Servicio $service: ACTIVO"
        else
            if systemctl is-enabled --quiet "$service" 2>/dev/null; then
                log_message "✗ Servicio $service: INACTIVO (pero habilitado)"
                send_alert "SERVICIO" "$service está inactivo"
            fi
        fi
    done
}

check_network_connectivity() {
    log_message "=== VERIFICACIÓN DE CONECTIVIDAD ==="
    
    if curl -fsSIL --connect-timeout 5 "https://download.webmin.com/" >/dev/null 2>&1; then
        log_message "✓ Conectividad externa: OK"
    else
        log_message "✗ Conectividad externa: FALLO"
        send_alert "RED" "Sin conectividad externa"
    fi
    
    if getent hosts localhost >/dev/null 2>&1; then
        log_message "✓ Conectividad local: OK"
    else
        log_message "✗ Conectividad local: FALLO"
        send_alert "RED" "Sin conectividad local"
    fi
}

check_ports() {
    log_message "=== VERIFICACIÓN DE PUERTOS ==="
    
    PORTS=("22:SSH" "80:HTTP" "443:HTTPS" "10000:Webmin" "20000:Virtualmin")
    
    for port_info in "${PORTS[@]}"; do
        port=$(echo "$port_info" | cut -d':' -f1)
        service=$(echo "$port_info" | cut -d':' -f2)
        
        if ss -tuln 2>/dev/null | grep -q ":${port}\b" || netstat -tuln 2>/dev/null | grep -q ":${port} "; then
            log_message "✓ Puerto $port ($service): ABIERTO"
        else
            log_message "✗ Puerto $port ($service): CERRADO"
            send_alert "PUERTO" "Puerto $port ($service) cerrado"
        fi
    done
}

check_log_errors() {
    log_message "=== VERIFICACIÓN DE ERRORES EN LOGS ==="
    
    ERROR_COUNT=$(journalctl --since "1 hour ago" --priority=err | wc -l)
    log_message "Errores en la última hora: $ERROR_COUNT"
    
    if [ "$ERROR_COUNT" -gt 10 ]; then
        log_message "ALERTA: Muchos errores detectados: $ERROR_COUNT"
        send_alert "LOGS" "$ERROR_COUNT errores en la última hora"
    fi
}

send_alert() {
    local type="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] ALERTA [$type]: $message" >> "/var/log/alertas_sistema.log"
    
    # Integración con Webmin (si está disponible)
    if command -v webmin >/dev/null 2>&1; then
        echo "$timestamp|$type|$message" >> "/usr/local/webmin/var/system_alerts.log"
    fi
}

generate_report() {
    log_message "=== GENERANDO REPORTE DE MONITOREO ==="
    
    REPORT_FILE="/var/log/reporte_monitoreo_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== REPORTE DE MONITOREO DEL SISTEMA ==="
        echo "Fecha: $(date)"
        echo "Servidor: $(hostname)"
        echo ""
        echo "=== RECURSOS ==="
        echo "CPU: ${CPU_USAGE}%"
        echo "Memoria: ${MEMORY_USAGE}%"
        echo "Disco: ${DISK_USAGE}%"
        echo ""
        echo "=== SERVICIOS ACTIVOS ==="
        systemctl --type=service --state=active | grep -E "(webmin|apache|nginx|mysql|postgresql|postfix|bind|ssh)"
        echo ""
        echo "=== ÚLTIMAS ALERTAS ==="
        tail -20 "/var/log/alertas_sistema.log" 2>/dev/null || echo "Sin alertas recientes"
    } > "$REPORT_FILE"
    
    log_message "Reporte generado: $REPORT_FILE"
}

main() {
    log_message "Iniciando sub-agente de monitoreo..."
    
    check_system_resources
    check_services
    check_network_connectivity
    check_ports
    check_log_errors
    generate_report
    
    log_message "Monitoreo completado."
}

case "${1:-}" in
    start)
        main
        ;;
    daemon)
        log_message "Iniciando en modo daemon..."
        while true; do
            main
            sleep 300  # 5 minutos
        done
        ;;
    report)
        generate_report
        ;;
    *)
        echo "Uso: $0 {start|daemon|report}"
        echo "  start  - Ejecutar monitoreo una vez"
        echo "  daemon - Ejecutar continuamente cada 5 minutos"
        echo "  report - Generar solo reporte"
        exit 1
        ;;
esac
