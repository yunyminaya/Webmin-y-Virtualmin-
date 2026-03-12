#!/bin/bash

# ============================================================================
# SISTEMA DE MONITOREO AVANZADO DE LOGS
# PARA WEBMIN Y VIRTUALMIN
# ============================================================================
# Monitoreo continuo con detección de patrones maliciosos
# SQL Injection, XSS, Brute Force, ataques a paneles de control
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_DIR="/etc/webmin-virtualmin-ids"
LOG_FILE="$MONITOR_DIR/logs/monitor.log"
ALERT_LOG="$MONITOR_DIR/logs/alerts.log"
THREAT_DB="$MONITOR_DIR/threats.db"

# Configuración de umbrales
SQL_INJECTION_THRESHOLD=2
XSS_THRESHOLD=2
BRUTEFORCE_THRESHOLD=5
SUSPICIOUS_IP_THRESHOLD=10
DDOS_THRESHOLD=1000

# Función de logging
log_monitor() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    mkdir -p "$(dirname "$LOG_FILE")"

    case "$level" in
        "SUCCESS") echo -e "${GREEN}✅ [$timestamp] MONITOR:${NC} $message" ;;
        "INFO")    echo -e "${BLUE}💎 [$timestamp] MONITOR:${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}⚠️ [$timestamp] MONITOR:${NC} $message" ;;
        "ERROR")   echo -e "${RED}❌ [$timestamp] MONITOR:${NC} $message" ;;
        "ALERT")   echo -e "${RED}🚨 [$timestamp] ALERT:${NC} $message" ;;
        *)         echo -e "${PURPLE}🔥 [$timestamp] MONITOR:${NC} $message" ;;
    esac

    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    if [[ "$level" == "ALERT" ]]; then
        echo "[$timestamp] ALERT: $message" >> "$ALERT_LOG"
    fi
}

# Inicializar base de datos de amenazas
init_threat_database() {
    if [[ ! -f "$THREAT_DB" ]]; then
        log_monitor "INFO" "Inicializando base de datos de amenazas..."
        echo "# Base de datos de amenazas - Webmin/Virtualmin IDS" > "$THREAT_DB"
        echo "# Formato: timestamp|ip|threat_type|severity|details" >> "$THREAT_DB"
    fi
}

# Registrar amenaza en base de datos
record_threat() {
    local ip="$1"
    local threat_type="$2"
    local severity="$3"
    local details="$4"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "$timestamp|$ip|$threat_type|$severity|$details" >> "$THREAT_DB"
}

# Detección de ataques SQL Injection
detect_sql_injection() {
    local log_files=(
        "/var/webmin/miniserv.log"
        "/var/log/apache2/access.log"
        "/var/log/nginx/access.log"
        "/var/log/httpd/access_log"
    )

    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            # Patrones SQL injection comunes
            local sql_patterns=(
                "union.*select"
                "select.*from.*information_schema"
                "insert.*into.*select"
                "update.*set.*script"
                "delete.*from.*where"
                "1=1.*--"
                "1=1.*#"
                "or.*1=1"
                "';.*--"
                "xp_cmdshell"
                "exec.*master"
                "having.*1=1"
                "group.*by.*having"
            )

            for pattern in "${sql_patterns[@]}"; do
                local matches=$(grep -i "$pattern" "$log_file" 2>/dev/null | tail -n 50 | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' | sort | uniq -c | sort -nr | head -10 || true)

                if [[ -n "$matches" ]]; then
                    while read -r line; do
                        local count=$(echo "$line" | awk '{print $1}')
                        local ip=$(echo "$line" | awk '{print $2}')

                        if [[ $count -ge $SQL_INJECTION_THRESHOLD ]]; then
                            log_monitor "ALERT" "SQL INJECTION DETECTADO - IP: $ip, Intentos: $count, Patrón: $pattern"
                            record_threat "$ip" "SQL_INJECTION" "HIGH" "Pattern: $pattern, Count: $count"
                            block_ip "$ip" "SQL Injection attack"
                        fi
                    done <<< "$matches"
                fi
            done
        fi
    done
}

# Detección de ataques XSS
detect_xss_attacks() {
    local log_files=(
        "/var/webmin/miniserv.log"
        "/var/log/apache2/access.log"
        "/var/log/nginx/access.log"
        "/var/log/httpd/access_log"
    )

    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            # Patrones XSS comunes
            local xss_patterns=(
                "<script"
                "<iframe"
                "<object"
                "<embed"
                "javascript:"
                "vbscript:"
                "data:text/html"
                "onload="
                "onerror="
                "onclick="
                "<svg"
                "expression("
                "vbscript:"
            )

            for pattern in "${xss_patterns[@]}"; do
                local matches=$(grep -i "$pattern" "$log_file" 2>/dev/null | tail -n 50 | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' | sort | uniq -c | sort -nr | head -10 || true)

                if [[ -n "$matches" ]]; then
                    while read -r line; do
                        local count=$(echo "$line" | awk '{print $1}')
                        local ip=$(echo "$line" | awk '{print $2}')

                        if [[ $count -ge $XSS_THRESHOLD ]]; then
                            log_monitor "ALERT" "XSS ATTACK DETECTADO - IP: $ip, Intentos: $count, Patrón: $pattern"
                            record_threat "$ip" "XSS" "HIGH" "Pattern: $pattern, Count: $count"
                            block_ip "$ip" "XSS attack"
                        fi
                    done <<< "$matches"
                fi
            done
        fi
    done
}

# Detección de ataques de fuerza bruta
detect_brute_force() {
    local auth_logs=(
        "/var/log/auth.log"
        "/var/log/secure"
        "/var/webmin/miniserv.log"
    )

    for log_file in "${auth_logs[@]}"; do
        if [[ -f "$log_file" ]]; then
            # Últimos 100 intentos de login fallidos en las últimas 5 minutos
            local recent_failures=$(grep -E "(Failed password|authentication failure|Invalid user|Failed login)" "$log_file" 2>/dev/null | tail -n 100 | grep "$(date '+%b %e %H:%M' -d '5 minutes ago')" | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' | sort | uniq -c | sort -nr | head -10 || true)

            if [[ -n "$recent_failures" ]]; then
                while read -r line; do
                    local count=$(echo "$line" | awk '{print $1}')
                    local ip=$(echo "$line" | awk '{print $2}')

                    if [[ $count -ge $BRUTEFORCE_THRESHOLD ]]; then
                        log_monitor "ALERT" "BRUTE FORCE DETECTADO - IP: $ip, Intentos: $count"
                        record_threat "$ip" "BRUTE_FORCE" "MEDIUM" "Failed attempts: $count"
                        block_ip "$ip" "Brute force attack"
                    fi
                done <<< "$recent_failures"
            fi
        fi
    done
}

# Detección de actividad sospechosa de IPs
detect_suspicious_ips() {
    local access_logs=(
        "/var/log/apache2/access.log"
        "/var/log/nginx/access.log"
        "/var/log/httpd/access_log"
    )

    for log_file in "${access_logs[@]}"; do
        if [[ -f "$log_file" ]]; then
            # Analizar requests por IP en las últimas 5 minutos
            local suspicious_ips=$(tail -n 10000 "$log_file" 2>/dev/null | grep "$(date '+%d/%b/%Y:%H:%M' -d '5 minutes ago' | cut -d: -f1-2)" | awk '{print $1}' | sort | uniq -c | sort -nr | head -20 || true)

            if [[ -n "$suspicious_ips" ]]; then
                while read -r line; do
                    local count=$(echo "$line" | awk '{print $1}')
                    local ip=$(echo "$line" | awk '{print $2}')

                    if [[ $count -ge $SUSPICIOUS_IP_THRESHOLD ]]; then
                        log_monitor "WARNING" "ACTIVIDAD SOSPECHOSA - IP: $ip, Requests: $count"
                        record_threat "$ip" "SUSPICIOUS_ACTIVITY" "LOW" "Requests: $count"
                    fi
                done <<< "$suspicious_ips"
            fi
        fi
    done
}

# Detección de ataques DDoS
detect_ddos_attacks() {
    # Verificar conexiones simultáneas
    local current_connections=$(netstat -an | grep :80 | grep ESTABLISHED | wc -l 2>/dev/null || echo "0")
    local current_ssl_connections=$(netstat -an | grep :443 | grep ESTABLISHED | wc -l 2>/dev/null || echo "0")
    local total_connections=$((current_connections + current_ssl_connections))

    if [[ $total_connections -ge $DDOS_THRESHOLD ]]; then
        log_monitor "ALERT" "ATAQUE DDOS DETECTADO - Conexiones simultáneas: $total_connections"
        record_threat "MULTIPLE" "DDOS" "CRITICAL" "Connections: $total_connections"

        # Activar medidas de emergencia
        enable_emergency_mode
    fi

    # Verificar rate de conexiones nuevas
    local new_connections_per_minute=$(netstat -an | grep SYN_RECV | wc -l 2>/dev/null || echo "0")

    if [[ $new_connections_per_minute -ge 500 ]]; then
        log_monitor "ALERT" "ATAQUE SYN FLOOD DETECTADO - Nuevas conexiones/minuto: $new_connections_per_minute"
        record_threat "MULTIPLE" "SYN_FLOOD" "CRITICAL" "New connections/min: $new_connections_per_minute"
    fi
}

# Detección de ataques a paneles de control
detect_control_panel_attacks() {
    local webmin_log="/var/webmin/miniserv.log"

    if [[ -f "$webmin_log" ]]; then
        # Ataques específicos a Webmin/Virtualmin
        local panel_attacks=$(grep -E "(session_login\.cgi|remote\.cgi|save_autoreply\.cgi)" "$webmin_log" 2>/dev/null | tail -n 50 | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' | sort | uniq -c | sort -nr | head -10 || true)

        if [[ -n "$panel_attacks" ]]; then
            while read -r line; do
                local count=$(echo "$line" | awk '{print $1}')
                local ip=$(echo "$line" | awk '{print $2}')

                if [[ $count -ge 10 ]]; then
                    log_monitor "ALERT" "ATAQUE A PANEL DE CONTROL - IP: $ip, Intentos: $count"
                    record_threat "$ip" "CONTROL_PANEL_ATTACK" "HIGH" "Attempts: $count"
                    block_ip "$ip" "Control panel attack"
                fi
            done <<< "$panel_attacks"
        fi
    fi
}

# Bloquear IP automáticamente
block_ip() {
    local ip="$1"
    local reason="$2"

    log_monitor "INFO" "Bloqueando IP: $ip - Razón: $reason"

    # Usar fail2ban si está disponible
    if command -v fail2ban-client >/dev/null 2>&1; then
        fail2ban-client set webmin-auth banip "$ip" 2>/dev/null || true
    fi

    # Usar iptables como respaldo
    iptables -I INPUT -s "$ip" -j DROP 2>/dev/null || true

    # Usar ipset si está disponible
    ipset add webmin_attackers "$ip" 2>/dev/null || true
}

# Activar modo de emergencia
enable_emergency_mode() {
    log_monitor "WARNING" "ACTIVANDO MODO DE EMERGENCIA"

    # Configuraciones de emergencia
    echo 1 > /proc/sys/net/ipv4/tcp_syncookies 2>/dev/null || true
    echo 2048 > /proc/sys/net/ipv4/tcp_max_syn_backlog 2>/dev/null || true

    # Limitar conexiones por IP
    iptables -I INPUT -p tcp --dport 80 -m connlimit --connlimit-above 10 --connlimit-mask 32 -j DROP 2>/dev/null || true
    iptables -I INPUT -p tcp --dport 443 -m connlimit --connlimit-above 10 --connlimit-mask 32 -j DROP 2>/dev/null || true

    # Notificar administradores
    send_emergency_alert
}

# Enviar alerta de emergencia
send_emergency_alert() {
    local alert_message="EMERGENCIA: Ataque DDoS detectado en $(hostname) - Modo de emergencia activado"

    # Email
    echo "$alert_message" | mail -s "EMERGENCIA DDOS - $(hostname)" root 2>/dev/null || true

    # Log detallado
    log_monitor "ALERT" "$alert_message"
}

# Generar reporte de amenazas
generate_threat_report() {
    local report_file="$MONITOR_DIR/reports/threat_report_$(date +%Y%m%d_%H%M%S).txt"

    mkdir -p "$(dirname "$report_file")"

    {
        echo "=== REPORTE DE AMENAZAS - $(date) ==="
        echo ""
        echo "RESUMEN DE AMENAZAS:"
        echo "-------------------"

        if [[ -f "$THREAT_DB" ]]; then
            echo "Total amenazas registradas: $(wc -l < "$THREAT_DB")"
            echo ""
            echo "Amenazas por tipo:"
            tail -n 1000 "$THREAT_DB" | cut -d'|' -f3 | sort | uniq -c | sort -nr
            echo ""
            echo "Amenazas por severidad:"
            tail -n 1000 "$THREAT_DB" | cut -d'|' -f4 | sort | uniq -c | sort -nr
            echo ""
            echo "Últimas 20 amenazas:"
            tail -n 20 "$THREAT_DB"
        else
            echo "No hay amenazas registradas"
        fi

        echo ""
        echo "=== FIN DEL REPORTE ==="
    } > "$report_file"

    log_monitor "INFO" "Reporte de amenazas generado: $report_file"
}

# Función principal de monitoreo
main_monitoring_loop() {
    log_monitor "INFO" "Iniciando monitoreo continuo de amenazas..."

    while true; do
        # Ejecutar detecciones
        detect_sql_injection
        detect_xss_attacks
        detect_brute_force
        detect_suspicious_ips
        detect_ddos_attacks
        detect_control_panel_attacks

        # Generar reporte cada hora
        if [[ $(date +%M) == "00" ]]; then
            generate_threat_report
        fi

        # Esperar intervalo configurado (por defecto 60 segundos)
        sleep 60
    done
}

# Función principal
main() {
    local action="${1:-monitor}"

    case "$action" in
        "start")
            log_monitor "INFO" "Iniciando sistema de monitoreo..."
            init_threat_database
            main_monitoring_loop
            ;;
        "check")
            log_monitor "INFO" "Ejecutando verificación única..."
            init_threat_database
            detect_sql_injection
            detect_xss_attacks
            detect_brute_force
            detect_suspicious_ips
            detect_ddos_attacks
            detect_control_panel_attacks
            log_monitor "SUCCESS" "Verificación completada"
            ;;
        "report")
            generate_threat_report
            ;;
        "status")
            echo "=== ESTADO DEL MONITOR DE AMENAZAS ==="
            echo "Archivo de log: $LOG_FILE"
            echo "Base de amenazas: $THREAT_DB"
            echo "Archivo de alertas: $ALERT_LOG"
            if [[ -f "$THREAT_DB" ]]; then
                echo "Amenazas totales: $(wc -l < "$THREAT_DB")"
                echo "Última amenaza: $(tail -n 1 "$THREAT_DB" 2>/dev/null || echo 'Ninguna')"
            fi
            echo ""
            echo "✅ Monitor operativo"
            ;;
        *)
            echo "Sistema de Monitoreo de Amenazas - Webmin/Virtualmin"
            echo ""
            echo "Uso: $0 [acción]"
            echo ""
            echo "Acciones:"
            echo "  start   - Iniciar monitoreo continuo"
            echo "  check   - Verificación única de amenazas"
            echo "  report  - Generar reporte de amenazas"
            echo "  status  - Mostrar estado del sistema"
            ;;
    esac
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi