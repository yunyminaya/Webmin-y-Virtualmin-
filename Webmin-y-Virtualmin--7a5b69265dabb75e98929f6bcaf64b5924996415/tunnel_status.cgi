#!/bin/bash
# tunnel_status.cgi
# Script CGI para proporcionar estado del sistema de túnel en formato JSON

# Configuración
LOG_FILE="/var/log/auto_tunnel_system.log"
CONFIG_FILE="/etc/auto_tunnel_config.conf"
TUNNEL_PID_FILE="/var/run/ssh_tunnel.pid"
MONITOR_PID_FILE="/var/run/tunnel_monitor.pid"
DOMAIN_STATUS_FILE="/var/run/domain_status.json"

# Función para verificar conectividad a internet
check_internet() {
    ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1
    return $?
}

# Función para obtener IP externa
get_external_ip() {
    curl -s --connect-timeout 3 --max-time 5 https://api.ipify.org 2>/dev/null || echo ""
}

# Función para verificar si IP es privada
is_private_ip() {
    local ip="$1"
    [[ $ip =~ ^10\. ]] || [[ $ip =~ ^172\.1[6-9]\. ]] || [[ $ip =~ ^172\.2[0-9]\. ]] || [[ $ip =~ ^172\.3[0-1]\. ]] || [[ $ip =~ ^192\.168\. ]] || [[ $ip =~ ^169\.254\. ]]
}

# Función para verificar estado del túnel
check_tunnel_status() {
    if [[ -f "$TUNNEL_PID_FILE" ]]; then
        local pid=$(cat "$TUNNEL_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "{\"active\": true, \"pid\": $pid}"
            return 0
        fi
    fi
    echo "{\"active\": false, \"pid\": null}"
    return 1
}

# Función para verificar estado del monitor
check_monitor_status() {
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        local pid=$(cat "$MONITOR_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "{\"active\": true, \"pid\": $pid}"
            return 0
        fi
    fi
    echo "{\"active\": false, \"pid\": null}"
    return 1
}

# Función para obtener logs recientes
get_recent_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        tail -20 "$LOG_FILE" | while IFS= read -r line; do
            # Parsear línea de log: timestamp [LEVEL] message
            if [[ $line =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2})\ \[([A-Z]+)\]\ (.+) ]]; then
                local timestamp="${BASH_REMATCH[1]}"
                local level="${BASH_REMATCH[2]}"
                local message="${BASH_REMATCH[3]}"

                # Escapar caracteres especiales en JSON
                message=$(echo "$message" | sed 's/"/\\"/g')

                echo "{\"timestamp\": \"$timestamp\", \"level\": \"$level\", \"message\": \"$message\"}"
            fi
        done | paste -sd',' | sed 's/^/[/; s/$/]/'
    else
        echo "[]"
    fi
}

# Función para calcular uptime del sistema
get_system_uptime() {
    local uptime=$(uptime -p 2>/dev/null || uptime | awk '{print $3 " " $4}' | sed 's/,//g')
    echo "\"$uptime\""
}

# Función para obtener estadísticas
get_stats() {
    local connections=0
    local failovers=0
    local alerts=0

    # Contar conexiones del día (líneas con "tunnel" en el log de hoy)
    if [[ -f "$LOG_FILE" ]]; then
        connections=$(grep "$(date '+%Y-%m-%d')" "$LOG_FILE" | grep -c "tunnel\|Túnel\|SSH")
        failovers=$(grep "$(date '+%Y-%m-%d')" "$LOG_FILE" | grep -c "reconectar\|restablecer\|failover")
        alerts=$(grep "$(date '+%Y-%m-%d')" "$LOG_FILE" | grep -c "ERROR\|WARNING")
    fi

    echo "{\"connections\": $connections, \"failovers\": $failovers, \"alerts\": $alerts, \"uptime\": $(get_system_uptime)}"
}

# Función para obtener alertas activas
get_alerts() {
    local alerts="[]"

    # Verificar si hay problemas críticos
    local problems=()

    # Verificar conectividad
    if ! check_internet; then
        problems+=("{\"type\": \"error\", \"message\": \"Sin conectividad a internet\"}")
    fi

    # Verificar túnel si IP es privada
    local external_ip=$(get_external_ip)
    if [[ -n "$external_ip" ]] && is_private_ip "$external_ip"; then
        if ! check_tunnel_status >/dev/null; then
            problems+=("{\"type\": \"warning\", \"message\": \"IP privada detectada pero túnel inactivo\"}")
        fi
    fi

    # Verificar monitor
    if ! check_monitor_status >/dev/null; then
        problems+=("{\"type\": \"warning\", \"message\": \"Monitor 24/7 no está ejecutándose\"}")
    fi

    if [[ ${#problems[@]} -gt 0 ]]; then
        alerts=$(printf '%s\n' "${problems[@]}" | paste -sd',' | sed 's/^/[/; s/$/]/')
    fi

    echo "$alerts"
}

# Función para obtener estado de dominios
get_domains_status() {
    if [[ -f "$DOMAIN_STATUS_FILE" ]]; then
        # Leer el archivo JSON y extraer solo el array de dominios
        cat "$DOMAIN_STATUS_FILE" | jq -c '.domains // []' 2>/dev/null || echo "[]"
    else
        echo "[]"
    fi
}

# Headers HTTP para JSON
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo "Access-Control-Allow-Methods: GET, POST, OPTIONS"
echo "Access-Control-Allow-Headers: Content-Type"
echo ""

# Verificar conectividad a internet
internet_connected=false
if check_internet; then
    internet_connected=true
fi

# Obtener IP externa
external_ip=$(get_external_ip)
ip_type="unknown"
if [[ -n "$external_ip" ]]; then
    if is_private_ip "$external_ip"; then
        ip_type="private"
    else
        ip_type="public"
    fi
fi

# Obtener estados
tunnel_status=$(check_tunnel_status)
monitor_status=$(check_monitor_status)
logs=$(get_recent_logs)
stats=$(get_stats)
alerts=$(get_alerts)
domains=$(get_domains_status)

# Generar respuesta JSON
cat << EOF
{
  "internet": {
    "connected": $internet_connected
  },
  "external_ip": "$external_ip",
  "ip_type": "$ip_type",
  "tunnel": $tunnel_status,
  "monitor": $monitor_status,
  "logs": $logs,
  "stats": $stats,
  "alerts": $alerts,
  "domains": $domains,
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')",
  "version": "1.1.0"
}
EOF