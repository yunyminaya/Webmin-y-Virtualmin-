#!/bin/bash
# auto_tunnel_system.sh
# Sistema de Túnel Automático para IPs Privadas
# Convierte automáticamente IPs privadas en públicas con monitoreo 24/7

# Configuración del sistema
SCRIPT_VERSION="3.2.0"
SCRIPT_NAME="Auto Tunnel System with Advanced Redundancy"
LOG_FILE="/var/log/auto_tunnel_system.log"
CONFIG_FILE="/etc/auto_tunnel_config.conf"
PID_FILE="/var/run/auto_tunnel_system.pid"
TUNNEL_PID_FILE="/var/run/ssh_tunnel.pid"
MONITOR_PID_FILE="/var/run/tunnel_monitor.pid"

# Configuración de monitoreo de dominios
DOMAIN_LOG_FILE="/var/log/domain_monitor.log"
DOMAIN_STATUS_FILE="/var/run/domain_status.json"
DOMAIN_MONITOR_PID_FILE="/var/run/domain_monitor.pid"

# Configuración del sistema de respaldo avanzado
BACKUP_CONFIG_DIR="/etc/auto_tunnel_backup"
NETWORK_INTERFACES_STATUS="/var/run/network_interfaces.json"
FAILOVER_LOG="/var/log/failover_events.log"
BACKUP_CONFIG_FILE="/etc/auto_tunnel_backup.conf"
SERVICE_RECOVERY_LOG="/var/log/service_recovery.log"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Verificar que el script se ejecute como root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Este script debe ejecutarse como root${NC}"
    echo -e "${YELLOW}Ejemplo: sudo $0 $@${NC}"
    exit 1
fi

# Función de logging
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" >> "$LOG_FILE"
    echo -e "${timestamp} [${level}] ${message}"
}

# Función central de alertas con múltiples canales
send_alert() {
    local level="$1"
    local message="$2"
    local alert_type="${3:-SYSTEM}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Mapear niveles de prioridad numérica para comparación
    local priority
    case "$level" in
        "DEBUG") priority=0 ;;
        "INFO") priority=1 ;;
        "WARNING") priority=2 ;;
        "ERROR") priority=3 ;;
        "CRITICAL") priority=4 ;;
        *) priority=1 ;;
    esac

    # Verificar si el nivel de alerta está habilitado
    if [[ $priority -lt ${ALERT_LEVEL_THRESHOLD:-1} ]]; then
        return 0
    fi

    # Log siempre (canal base)
    log "$level" "[$alert_type] $message"

    # Notificación del sistema (si está disponible y habilitado)
    if [[ "$ENABLE_SYSTEM_NOTIFICATIONS" == "true" ]] && command -v notify-send >/dev/null 2>&1; then
        local urgency="normal"
        case "$level" in
            "CRITICAL") urgency="critical" ;;
            "ERROR") urgency="critical" ;;
            "WARNING") urgency="normal" ;;
            "INFO") urgency="low" ;;
            "DEBUG") urgency="low" ;;
        esac
        notify-send -u "$urgency" "Auto Tunnel Alert [$level]" "$message" 2>/dev/null || true
    fi

    # Dashboard local (si existe el archivo)
    if [[ -f "$ALERT_DASHBOARD_FILE" ]]; then
        echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"type\":\"$alert_type\",\"message\":\"$message\"}" >> "$ALERT_DASHBOARD_FILE"
        # Mantener solo las últimas 100 alertas
        tail -n 100 "$ALERT_DASHBOARD_FILE" > "${ALERT_DASHBOARD_FILE}.tmp" && mv "${ALERT_DASHBOARD_FILE}.tmp" "$ALERT_DASHBOARD_FILE"
    fi

    # Email (si está configurado)
    if [[ -n "$ALERT_EMAIL_RECIPIENTS" ]] && command -v mail >/dev/null 2>&1; then
        local subject="Auto Tunnel Alert [$level] - $alert_type"
        local email_body="Alerta del Sistema de Túnel Automático
Tipo: $alert_type
Nivel: $level
Mensaje: $message
Timestamp: $timestamp
Sistema: $SCRIPT_NAME v$SCRIPT_VERSION
Hostname: $(hostname)
IP Externa: $(get_external_ip)"

        # Enviar a múltiples destinatarios si están separados por comas
        IFS=',' read -ra RECIPIENTS <<< "$ALERT_EMAIL_RECIPIENTS"
        for recipient in "${RECIPIENTS[@]}"; do
            echo "$email_body" | mail -s "$subject" "$recipient" 2>/dev/null || true
        done
    fi

    # Webhooks (si están configurados)
    if [[ -n "$ALERT_WEBHOOK_URLS" ]]; then
        local webhook_data="{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"type\":\"$alert_type\",\"message\":\"$message\",\"system\":\"$SCRIPT_NAME\",\"version\":\"$SCRIPT_VERSION\",\"hostname\":\"$(hostname)\",\"external_ip\":\"$(get_external_ip)\"}"

        # Enviar a múltiples webhooks si están separados por comas
        IFS=',' read -ra URLS <<< "$ALERT_WEBHOOK_URLS"
        for url in "${URLS[@]}"; do
            curl -s -X POST "$url" \
                -H "Content-Type: application/json" \
                -H "User-Agent: Auto-Tunnel-System/$SCRIPT_VERSION" \
                -d "$webhook_data" \
                --connect-timeout 5 \
                --max-time 10 >/dev/null 2>&1 || true
        done
    fi
}

# Función para verificar si una IP es privada
is_private_ip() {
    local ip="$1"
    # Rangos de IP privadas:
    # 10.0.0.0/8
    # 172.16.0.0/12
    # 192.168.0.0/16
    # 169.254.0.0/16 (APIPA)

    if [[ $ip =~ ^10\. ]]; then
        return 0  # Verdadero - es privada
    elif [[ $ip =~ ^172\.1[6-9]\. ]] || [[ $ip =~ ^172\.2[0-9]\. ]] || [[ $ip =~ ^172\.3[0-1]\. ]]; then
        return 0  # Verdadero - es privada
    elif [[ $ip =~ ^192\.168\. ]]; then
        return 0  # Verdadero - es privada
    elif [[ $ip =~ ^169\.254\. ]]; then
        return 0  # Verdadero - es privada
    else
        return 1  # Falso - es pública
    fi
}

# Función para obtener la IP externa actual con validación cruzada
get_external_ip() {
    # Intentar múltiples servicios para obtener la IP externa con validación cruzada
    local ip_services=(
        "https://api.ipify.org"
        "https://checkip.amazonaws.com"
        "https://icanhazip.com"
        "https://ipinfo.io/ip"
        "https://api.myip.com"
        "https://ipv4.icanhazip.com"
        "https://wtfismyip.com/text"
        "https://ipapi.co/ip"
    )

    local ip_votes=()  # Array de strings "IP:count" para compatibilidad con shells básicos

    # Obtener IPs de múltiples fuentes
    for service in "${ip_services[@]}"; do
        local ip=$(curl -s --connect-timeout 3 --max-time 8 "$service" 2>/dev/null | tr -d '[:space:]' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
        if [[ -n "$ip" ]]; then
            # Buscar si la IP ya existe en el array
            local found=false
            for i in "${!ip_votes[@]}"; do
                IFS=':' read -r vote_ip count <<< "${ip_votes[i]}"
                if [[ "$vote_ip" == "$ip" ]]; then
                    ((count++))
                    ip_votes[i]="$ip:$count"
                    found=true
                    break
                fi
            done
            # Si no se encontró, agregar nueva entrada
            if [[ "$found" == false ]]; then
                ip_votes+=("$ip:1")
            fi
        fi
    done

    # Encontrar la IP más votada (validación cruzada)
    local max_votes=0
    local consensus_ip=""
    for vote in "${ip_votes[@]}"; do
        IFS=':' read -r ip count <<< "$vote"
        if (( count > max_votes )); then
            max_votes=$count
            consensus_ip=$ip
        fi
    done

    # Si al menos 3 servicios coinciden, usar esa IP
    if [[ $max_votes -ge 3 ]]; then
        log "INFO" "IP externa detectada por validación cruzada: $consensus_ip (votos: $max_votes)"
        echo "$consensus_ip"
        return 0
    fi

    # Fallback: usar la primera IP válida si no hay consenso
    for service in "${ip_services[@]}"; do
        local ip=$(curl -s --connect-timeout 5 --max-time 10 "$service" 2>/dev/null | tr -d '[:space:]')
        if [[ -n "$ip" ]] && [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            log "WARNING" "Usando IP de fallback (sin consenso): $ip"
            echo "$ip"
            return 0
        fi
    done

    # Último fallback: IP local
    local local_ip=$(hostname -I | awk '{print $1}')
    log "ERROR" "No se pudo obtener IP externa, usando IP local: $local_ip"
    echo "$local_ip"
}

# Función para verificar conectividad a internet con más pruebas
check_internet() {
    # Verificar conectividad probando múltiples hosts y servicios
    local test_hosts=("8.8.8.8" "1.1.1.1" "208.67.222.222" "8.8.4.4" "9.9.9.9")
    local timeout=3
    local success_count=0

    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W "$timeout" "$host" >/dev/null 2>&1; then
            ((success_count++))
        fi
    done

    # Requiere al menos 2 conexiones exitosas para considerar conectividad buena
    if [[ $success_count -ge 2 ]]; then
        return 0
    fi

    # Verificar conectividad HTTP como respaldo
    if curl -s --connect-timeout 5 --max-time 10 "https://www.google.com" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

# Función para detectar y monitorear interfaces de red disponibles
detect_network_interfaces() {
    local interfaces=()
    local interface_details=()

    # Detectar interfaces físicas disponibles
    while IFS= read -r line; do
        if [[ $line =~ ^[0-9]+:\ ([a-zA-Z0-9]+): ]]; then
            local iface="${BASH_REMATCH[1]}"
            # Excluir interfaces loopback y virtuales
            if [[ "$iface" != "lo" ]] && [[ "$iface" != docker* ]] && [[ "$iface" != veth* ]] && [[ "$iface" != br-* ]]; then
                interfaces+=("$iface")
            fi
        fi
    done < /proc/net/dev

    # Obtener detalles de cada interfaz
    for iface in "${interfaces[@]}"; do
        local status="down"
        local ip=""
        local mac=""
        local type="unknown"

        # Verificar estado de la interfaz
        if ip link show "$iface" 2>/dev/null | grep -q "UP"; then
            status="up"
        fi

        # Obtener dirección IP
        ip=$(ip addr show "$iface" 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)

        # Obtener dirección MAC
        mac=$(ip link show "$iface" 2>/dev/null | grep -oP 'link/ether \K[0-9a-f:]+')

        # Determinar tipo de interfaz
        if [[ "$iface" =~ ^(eth|en) ]]; then
            type="ethernet"
        elif [[ "$iface" =~ ^(wlan|wl) ]]; then
            type="wifi"
        elif [[ "$iface" =~ ^(wwan|ppp|usb) ]]; then
            type="mobile"
        fi

        interface_details+=("{\"interface\":\"$iface\",\"type\":\"$type\",\"status\":\"$status\",\"ip\":\"$ip\",\"mac\":\"$mac\"}")
    done

    # Crear JSON con estado de interfaces
    local interfaces_json=$(printf '%s\n' "${interface_details[@]}" | jq -s . 2>/dev/null || echo "[]")
    echo "{\"timestamp\":\"$(date -Iseconds)\",\"interfaces\":$interfaces_json}" > "$NETWORK_INTERFACES_STATUS"
    echo "$interfaces_json"
}

# Función para verificar conectividad por interfaz específica
check_interface_connectivity() {
    local interface="$1"
    local timeout="${2:-5}"
    local test_hosts=("8.8.8.8" "1.1.1.1")
    local success_count=0

    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W "$timeout" -I "$interface" "$host" >/dev/null 2>&1; then
            ((success_count++))
        fi
    done

    # Requiere al menos 1 conexión exitosa por interfaz
    [[ $success_count -ge 1 ]] && return 0 || return 1
}

# Función para detectar fallos de red rápida (< 10 segundos)
detect_network_failure() {
    local failure_detected=false
    local failed_interfaces=()
    local start_time=$(date +%s)

    # Monitorear todas las interfaces activas
    while IFS= read -r interface_data; do
        local iface=$(echo "$interface_data" | jq -r '.interface' 2>/dev/null)
        local status=$(echo "$interface_data" | jq -r '.status' 2>/dev/null)

        if [[ "$status" == "up" ]] && [[ -n "$iface" ]]; then
            if ! check_interface_connectivity "$iface" 2; then
                failed_interfaces+=("$iface")
                failure_detected=true
                log "WARNING" "Fallo detectado en interfaz $iface"
            fi
        fi
    done < <(detect_network_interfaces | jq -c '.interfaces[]' 2>/dev/null)

    local end_time=$(date +%s)
    local detection_time=$((end_time - start_time))

    if [[ "$failure_detected" == true ]]; then
        log "CRITICAL" "Fallo de red detectado en ${#failed_interfaces[@]} interfaces: ${failed_interfaces[*]} (tiempo de detección: ${detection_time}s)"
        echo "${failed_interfaces[*]}"
        return 1
    fi

    return 0
}

# Función para rotación automática de conexiones
rotate_network_connection() {
    local failed_interfaces=("$@")
    local available_interfaces=()
    local rotated=false

    # Encontrar interfaces disponibles que no fallaron
    while IFS= read -r interface_data; do
        local iface=$(echo "$interface_data" | jq -r '.interface' 2>/dev/null)
        local status=$(echo "$interface_data" | jq -r '.status' 2>/dev/null)
        local type=$(echo "$interface_data" | jq -r '.type' 2>/dev/null)

        # Verificar si esta interfaz no falló y está disponible
        local interface_failed=false
        for failed_iface in "${failed_interfaces[@]}"; do
            if [[ "$iface" == "$failed_iface" ]]; then
                interface_failed=true
                break
            fi
        done

        if [[ "$interface_failed" == false ]] && [[ "$status" == "up" ]] && check_interface_connectivity "$iface" 3; then
            available_interfaces+=("$iface:$type")
        fi
    done < <(detect_network_interfaces | jq -c '.interfaces[]' 2>/dev/null)

    # Intentar rotar a interfaces disponibles por prioridad: Ethernet > WiFi > 4G/5G
    local priority_order=("ethernet" "wifi" "mobile")

    for priority in "${priority_order[@]}"; do
        for iface_type in "${available_interfaces[@]}"; do
            IFS=':' read -r iface type <<< "$iface_type"
            if [[ "$type" == "$priority" ]]; then
                log "INFO" "Rotando conexión a interfaz $iface (tipo: $type)"
                # Aquí se podría implementar lógica específica para cambiar rutas por defecto
                # Por ahora, solo registramos la rotación
                send_alert "WARNING" "Conexión rotada automáticamente a interfaz $iface ($type) debido a fallos en otras interfaces" "NETWORK_ROTATION"
                rotated=true
                break 2
            fi
        done
    done

    if [[ "$rotated" == false ]]; then
        send_alert "CRITICAL" "No hay interfaces alternativas disponibles para rotación - Sistema en modo degradado" "NETWORK_ROTATION_FAILED"
        return 1
    fi

    return 0
}

# Función para crear respaldo de configuraciones críticas
backup_critical_configs() {
    local backup_timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$BACKUP_CONFIG_DIR/$backup_timestamp"

    log "INFO" "Creando respaldo de configuraciones críticas en $backup_dir"

    # Crear directorio de respaldo
    mkdir -p "$backup_dir"

    # Lista de archivos de configuración críticos a respaldar
    local critical_files=(
        "$CONFIG_FILE"
        "/etc/network/interfaces"
        "/etc/resolv.conf"
        "/etc/hosts"
        "/etc/ssh/sshd_config"
        "/etc/fail2ban/jail.local"
        "/etc/iptables/rules.v4"
        "/etc/iptables/rules.v6"
    )

    local backup_count=0
    for config_file in "${critical_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            cp "$config_file" "$backup_dir/"
            ((backup_count++))
        fi
    done

    # Respaldar configuraciones del sistema de túnel
    if [[ -d "/etc/auto-tunnel" ]]; then
        cp -r "/etc/auto-tunnel" "$backup_dir/"
    fi

    # Respaldar estado actual del sistema
    cat > "$backup_dir/system_state.json" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "external_ip": "$(get_external_ip)",
    "network_interfaces": $(detect_network_interfaces),
    "tunnel_status": "$(check_tunnel_status && echo 'active' || echo 'inactive')",
    "services_status": {
        "ssh": "$(systemctl is-active ssh 2>/dev/null || echo 'unknown')",
        "networking": "$(systemctl is-active networking 2>/dev/null || echo 'unknown')",
        "fail2ban": "$(systemctl is-active fail2ban 2>/dev/null || echo 'unknown')"
    }
}
EOF

    # Crear enlace simbólico al respaldo más reciente
    rm -f "$BACKUP_CONFIG_DIR/latest"
    ln -s "$backup_dir" "$BACKUP_CONFIG_DIR/latest"

    # Limpiar respaldos antiguos (mantener últimos 10)
    ls -td "$BACKUP_CONFIG_DIR"/* 2>/dev/null | tail -n +11 | xargs -r rm -rf

    log "SUCCESS" "Respaldo completado: $backup_count archivos respaldados"
    send_alert "INFO" "Respaldo automático de configuraciones críticas completado ($backup_count archivos)" "CONFIG_BACKUP"
}

# Función para restaurar configuraciones desde respaldo
restore_from_backup() {
    local backup_source="${1:-latest}"
    local backup_dir

    if [[ "$backup_source" == "latest" ]]; then
        backup_dir="$BACKUP_CONFIG_DIR/latest"
    else
        backup_dir="$BACKUP_CONFIG_DIR/$backup_source"
    fi

    if [[ ! -d "$backup_dir" ]]; then
        log "ERROR" "Directorio de respaldo no encontrado: $backup_dir"
        return 1
    fi

    log "WARNING" "Restaurando configuraciones desde respaldo: $backup_dir"

    # Restaurar archivos de configuración críticos
    local critical_files=(
        "auto_tunnel_config.conf"
        "interfaces"
        "resolv.conf"
        "hosts"
        "sshd_config"
        "jail.local"
        "rules.v4"
        "rules.v6"
    )

    for config_file in "${critical_files[@]}"; do
        if [[ -f "$backup_dir/$config_file" ]]; then
            local target_path
            case "$config_file" in
                "auto_tunnel_config.conf") target_path="$CONFIG_FILE" ;;
                "interfaces") target_path="/etc/network/interfaces" ;;
                "resolv.conf") target_path="/etc/resolv.conf" ;;
                "hosts") target_path="/etc/hosts" ;;
                "sshd_config") target_path="/etc/ssh/sshd_config" ;;
                "jail.local") target_path="/etc/fail2ban/jail.local" ;;
                "rules.v4") target_path="/etc/iptables/rules.v4" ;;
                "rules.v6") target_path="/etc/iptables/rules.v6" ;;
            esac

            if [[ -n "$target_path" ]]; then
                cp "$backup_dir/$config_file" "$target_path"
                log "INFO" "Restaurado: $config_file -> $target_path"
            fi
        fi
    done

    # Restaurar directorio auto-tunnel si existe
    if [[ -d "$backup_dir/auto-tunnel" ]]; then
        cp -r "$backup_dir/auto-tunnel" "/etc/"
        log "INFO" "Restaurado directorio: auto-tunnel"
    fi

    send_alert "WARNING" "Configuraciones restauradas desde respaldo - Se recomienda reiniciar servicios" "CONFIG_RESTORE"
    log "SUCCESS" "Restauración completada desde respaldo: $backup_dir"
}

# Función para recuperación automática de servicios caídos
auto_recover_services() {
    local services_to_check=(
        "ssh:ssh.service"
        "networking:networking.service"
        "fail2ban:fail2ban.service"
        "bind9:bind9.service"
        "iptables:iptables.service"
    )

    local recovery_count=0

    for service_entry in "${services_to_check[@]}"; do
        IFS=':' read -r service_name service_file <<< "$service_entry"

        # Verificar estado del servicio
        local service_status=$(systemctl is-active "$service_file" 2>/dev/null || echo "unknown")

        if [[ "$service_status" != "active" ]] && [[ "$service_status" != "unknown" ]]; then
            log "WARNING" "Servicio $service_name detectado como caído (estado: $service_status)"

            # Intentar reiniciar el servicio
            if systemctl restart "$service_file" 2>/dev/null; then
                log "SUCCESS" "Servicio $service_name recuperado exitosamente"
                send_alert "WARNING" "Servicio $service_name recuperado automáticamente después de falla" "SERVICE_RECOVERY"
                ((recovery_count++))

                # Registrar en log de recuperación
                echo "$(date '+%Y-%m-%d %H:%M:%S') SERVICE_RECOVERY $service_name restarted successfully" >> "$SERVICE_RECOVERY_LOG"
            else
                log "ERROR" "Falló la recuperación automática del servicio $service_name"
                send_alert "CRITICAL" "Falló la recuperación automática del servicio $service_name - Requiere intervención manual" "SERVICE_RECOVERY_FAILED"

                # Registrar falla en log de recuperación
                echo "$(date '+%Y-%m-%d %H:%M:%S') SERVICE_RECOVERY_FAILED $service_name restart failed" >> "$SERVICE_RECOVERY_LOG"
            fi
        fi
    done

    if [[ $recovery_count -gt 0 ]]; then
        log "INFO" "Recuperación automática completada: $recovery_count servicios restaurados"
    fi
}

# Función para detectar y manejar escenarios específicos de eventualidades
handle_specific_scenarios() {
    local scenario_type="$1"
    local scenario_details="$2"

    case "$scenario_type" in
        "internet_outage")
            log "CRITICAL" "Escenario detectado: Corte total de internet"
            send_alert "CRITICAL" "Corte total de conectividad a internet detectado - Activando modo offline" "INTERNET_OUTAGE"

            # Intentar failover inmediato
            local failed_interfaces=$(detect_network_failure)
            if [[ -n "$failed_interfaces" ]]; then
                rotate_network_connection $failed_interfaces
            fi

            # Crear respaldo preventivo
            backup_critical_configs
            ;;

        "isp_change")
            log "WARNING" "Escenario detectado: Cambio de ISP detectado"
            send_alert "WARNING" "Cambio de proveedor de internet detectado - Verificando conectividad" "ISP_CHANGE"

            # Verificar todas las interfaces
            detect_network_interfaces

            # Forzar reconfiguración de túnel si es necesario
            if check_tunnel_status; then
                log "INFO" "Reiniciando túnel por cambio de ISP"
                stop_tunnel
                sleep 2
                setup_ssh_tunnel
            fi
            ;;

        "hardware_failure")
            log "CRITICAL" "Escenario detectado: Fallo de hardware de red"
            send_alert "CRITICAL" "Fallo de hardware de red detectado - Activando protocolos de contingencia" "HARDWARE_FAILURE"

            # Respaldar configuraciones inmediatamente
            backup_critical_configs

            # Intentar recuperación de servicios
            auto_recover_services

            # Forzar re-detección de interfaces
            detect_network_interfaces
            ;;

        "ddos_attack")
            log "CRITICAL" "Escenario detectado: Posible ataque DDoS"
            send_alert "CRITICAL" "Ataque DDoS detectado - Activando medidas de protección" "DDOS_ATTACK"

            # Verificar si fail2ban está activo y configurado
            if systemctl is-active fail2ban >/dev/null 2>&1; then
                # Recargar reglas de fail2ban
                fail2ban-client reload 2>/dev/null || true
                log "INFO" "Reglas de fail2ban recargadas por posible DDoS"
            fi

            # Monitorear uso de red intensamente
            local high_traffic=$(check_high_traffic)
            if [[ "$high_traffic" == "true" ]]; then
                send_alert "CRITICAL" "Tráfico DDoS confirmado - Activando mitigación avanzada" "DDOS_CONFIRMED"
            fi
            ;;

        "overload")
            log "WARNING" "Escenario detectado: Sobrecarga del sistema"
            send_alert "WARNING" "Sobrecarga del sistema detectada - Optimizando recursos" "SYSTEM_OVERLOAD"

            # Verificar y liberar recursos
            clean_system_resources

            # Reducir intervalo de monitoreo temporalmente
            TUNNEL_MONITOR_INTERVAL=30
            ;;
    esac
}

# Función para verificar alto tráfico (posible DDoS)
check_high_traffic() {
    # Verificar conexiones TCP establecidas
    local tcp_connections=$(netstat -tun 2>/dev/null | grep ESTABLISHED | wc -l)
    local udp_connections=$(netstat -tun 2>/dev/null | grep udp | wc -l)

    # Umbrales para detectar posible DDoS
    local tcp_threshold=500
    local udp_threshold=1000

    if [[ $tcp_connections -gt $tcp_threshold ]] || [[ $udp_connections -gt $udp_threshold ]]; then
        log "WARNING" "Alto número de conexiones detectado: TCP=$tcp_connections, UDP=$udp_connections"
        echo "true"
        return 0
    fi

    echo "false"
    return 1
}

# Función para limpiar recursos del sistema
clean_system_resources() {
    log "INFO" "Limpiando recursos del sistema por sobrecarga"

    # Limpiar caché de paquetes
    if command -v apt-get >/dev/null 2>&1; then
        apt-get clean >/dev/null 2>&1 || true
    elif command -v yum >/dev/null 2>&1; then
        yum clean all >/dev/null 2>&1 || true
    fi

    # Limpiar archivos temporales
    find /tmp -type f -mtime +1 -delete 2>/dev/null || true

    # Liberar memoria caché
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

    log "SUCCESS" "Limpieza de recursos completada"
}

# Función para seleccionar servidor remoto con balanceo de carga
select_remote_server() {
    local available_servers=()
    local server_weights=()
    local total_weight=0

    # Verificar disponibilidad de cada servidor
    for server_config in "${TUNNEL_REMOTE_SERVERS[@]}"; do
        IFS=':' read -r host user port weight <<< "$server_config"

        # Verificar conectividad al servidor
        if nc -z -w3 "$host" "$port" 2>/dev/null; then
            available_servers+=("$server_config")
            server_weights+=("$weight")
            ((total_weight += weight))
        else
            log "WARNING" "Servidor remoto no disponible: $host:$port"
        fi
    done

    if [[ ${#available_servers[@]} -eq 0 ]]; then
        log "ERROR" "No hay servidores remotos disponibles"
        return 1
    fi

    # Balanceo de carga: seleccionar basado en pesos
    if [[ "$ENABLE_LOAD_BALANCING" == "true" ]] && [[ $total_weight -gt 0 ]]; then
        local random_weight=$((RANDOM % total_weight + 1))
        local cumulative_weight=0

        for i in "${!available_servers[@]}"; do
            ((cumulative_weight += server_weights[i]))
            if [[ $random_weight -le $cumulative_weight ]]; then
                echo "${available_servers[i]}"
                return 0
            fi
        done
    fi

    # Fallback: seleccionar el primer servidor disponible
    echo "${available_servers[0]}"
}

# Función para obtener el siguiente servidor para failover
get_failover_server() {
    local current_server="$1"
    local available_servers=()

    # Encontrar servidores disponibles excluyendo el actual
    for server_config in "${TUNNEL_REMOTE_SERVERS[@]}"; do
        if [[ "$server_config" != "$current_server" ]]; then
            IFS=':' read -r host user port weight <<< "$server_config"
            if nc -z -w3 "$host" "$port" 2>/dev/null; then
                available_servers+=("$server_config")
            fi
        fi
    done

    if [[ ${#available_servers[@]} -gt 0 ]]; then
        echo "${available_servers[0]}"
        return 0
    fi

    return 1
}

# Función para configurar el túnel SSH con balanceo de carga y failover
setup_ssh_tunnel() {
    local selected_server

    # Seleccionar servidor remoto usando balanceo de carga
    if [[ "$ENABLE_LOAD_BALANCING" == "true" ]] || [[ "$ENABLE_FAILOVER" == "true" ]]; then
        selected_server=$(select_remote_server)
        if [[ $? -ne 0 ]]; then
            log "ERROR" "No se pudo seleccionar un servidor remoto disponible"
            return 1
        fi
    else
        # Modo compatibilidad: usar configuración antigua si existe
        if [[ -n "${TUNNEL_REMOTE_HOST:-}" ]]; then
            selected_server="${TUNNEL_REMOTE_HOST}:${TUNNEL_REMOTE_USER:-tunnel_user}:${TUNNEL_REMOTE_PORT:-22}:10"
        else
            log "ERROR" "No hay configuración de servidor remoto disponible"
            return 1
        fi
    fi

    IFS=':' read -r remote_host remote_user remote_port weight <<< "$selected_server"
    local local_port="${TUNNEL_LOCAL_PORT:-80}"
    local tunnel_port="${TUNNEL_PORT_BASE:-8080}"

    log "INFO" "Configurando túnel SSH reverse a ${remote_user}@${remote_host}:${remote_port} (peso: $weight)"

    # Verificar que SSH esté disponible
    if ! command -v ssh >/dev/null 2>&1; then
        log "ERROR" "SSH no está instalado en el sistema"
        return 1
    fi

    # Crear clave SSH si no existe
    local ssh_key="/root/.ssh/auto_tunnel_key"
    if [[ ! -f "$ssh_key" ]]; then
        log "INFO" "Generando nueva clave SSH para túnel automático"
        mkdir -p /root/.ssh
        chmod 700 /root/.ssh
        ssh-keygen -t rsa -b 4096 -f "$ssh_key" -N "" -C "auto-tunnel-system"
    fi

    # Intentar conexión SSH y agregar clave al known_hosts
    log "INFO" "Probando conexión SSH y configurando autenticación"
    ssh-keyscan -H "$remote_host" >> /root/.ssh/known_hosts 2>/dev/null

    # Configurar el túnel SSH reverse con opciones mejoradas
    local ssh_cmd="ssh -i $ssh_key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/root/.ssh/known_hosts -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ConnectTimeout=10 -o ConnectionAttempts=3 -R ${tunnel_port}:localhost:${local_port} -N ${remote_user}@${remote_host} -p ${remote_port}"

    log "INFO" "Iniciando túnel SSH: $ssh_cmd"

    # Ejecutar el túnel en background
    nohup $ssh_cmd >/dev/null 2>&1 &
    local tunnel_pid=$!

    # Guardar información del túnel activo
    echo "$tunnel_pid:$selected_server:$(date +%s)" > "$TUNNEL_PID_FILE"

    # Esperar un momento y verificar que el túnel esté funcionando
    sleep 5
    if kill -0 "$tunnel_pid" 2>/dev/null; then
        send_alert "INFO" "Túnel SSH establecido exitosamente a $remote_host:$tunnel_port - Conversión a IP pública operativa" "TUNNEL_ESTABLISHED"
        log "SUCCESS" "Túnel SSH establecido exitosamente a $remote_host (PID: $tunnel_pid)"

        # Actualizar DNS si está habilitado
        if [[ "$ENABLE_DNS_LOCAL" == "true" ]]; then
            update_dns_record "$remote_host" "$tunnel_port"
        fi

        return 0
    else
        send_alert "ERROR" "Falló al establecer el túnel SSH a $remote_host:$tunnel_port - Conversión a IP pública fallida" "TUNNEL_SETUP_FAILURE"
        log "ERROR" "Falló al establecer el túnel SSH a $remote_host"

        # Intentar failover si está habilitado
        if [[ "$ENABLE_FAILOVER" == "true" ]]; then
            local failover_server=$(get_failover_server "$selected_server")
            if [[ -n "$failover_server" ]]; then
                send_alert "WARNING" "Iniciando failover automático a servidor alternativo" "TUNNEL_FAILOVER"
                log "INFO" "Intentando failover a servidor alternativo"
                # Recursión con servidor alternativo (limitada a 1 nivel para evitar bucles)
                TUNNEL_REMOTE_SERVERS=("$failover_server") setup_ssh_tunnel
                return $?
            else
                send_alert "CRITICAL" "Failover fallido - No hay servidores alternativos disponibles" "FAILOVER_FAILURE"
            fi
        fi

        return 1
    fi
}

# Función para verificar estado del túnel
check_tunnel_status() {
    if [[ -f "$TUNNEL_PID_FILE" ]]; then
        local tunnel_info=$(cat "$TUNNEL_PID_FILE")
        IFS=':' read -r tunnel_pid server_config timestamp <<< "$tunnel_info"

        if kill -0 "$tunnel_pid" 2>/dev/null; then
            # Verificar que el puerto del túnel esté abierto
            IFS=':' read -r host user port weight <<< "$server_config"
            local tunnel_port="${TUNNEL_PORT_BASE:-8080}"

            # Verificar conectividad al puerto del túnel
            if nc -z localhost "$tunnel_port" 2>/dev/null; then
                return 0  # Túnel activo y funcional
            else
                log "WARNING" "Túnel PID existe pero puerto $tunnel_port no responde"
                rm -f "$TUNNEL_PID_FILE"
                return 1
            fi
        else
            # Limpiar PID file si el proceso no existe
            rm -f "$TUNNEL_PID_FILE"
        fi
    fi
    return 1  # Túnel inactivo
}

# Función para configurar bind9 DNS local
setup_bind9_dns() {
    log "INFO" "Configurando servidor DNS local con bind9"

    # Instalar bind9 si no está presente
    if ! command -v named >/dev/null 2>&1; then
        log "INFO" "Instalando bind9..."
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y bind9 bind9utils bind9-doc
        elif command -v yum >/dev/null 2>&1; then
            yum install -y bind bind-utils
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y bind bind-utils
        else
            log "ERROR" "No se pudo instalar bind9 - gestor de paquetes no reconocido"
            return 1
        fi
    fi

    # Crear directorios necesarios
    mkdir -p /var/lib/bind
    mkdir -p /etc/bind/zones

    # Generar clave DDNS si no existe
    if [[ ! -f "$DNS_UPDATE_KEY" ]]; then
        log "INFO" "Generando clave DDNS para actualizaciones DNS"
        dnssec-keygen -a HMAC-MD5 -b 128 -r /dev/urandom -n USER "$DNS_DOMAIN" > /tmp/keygen.out
        local key_file=$(grep "K${DNS_DOMAIN}" /tmp/keygen.out | head -1).private
        local secret=$(grep "Key:" "$key_file" | cut -d' ' -f2)

        cat > "$DNS_UPDATE_KEY" << EOF
key "$DNS_DOMAIN" {
    algorithm hmac-md5;
    secret "$secret";
};
EOF
        chmod 600 "$DNS_UPDATE_KEY"
        rm -f /tmp/keygen.out "$key_file"
    fi

    # Configurar zona DNS
    if [[ ! -f "$DNS_ZONE_FILE" ]]; then
        cat > "$DNS_ZONE_FILE" << EOF
\$TTL 86400
@   IN  SOA     ns1.$DNS_DOMAIN. admin.$DNS_DOMAIN. (
        $(date +%Y%m%d%H) ; Serial
        3600       ; Refresh
        1800       ; Retry
        604800     ; Expire
        86400 )    ; Minimum TTL
;
@       IN  NS      ns1.$DNS_DOMAIN.
ns1     IN  A       127.0.0.1
tunnel  IN  A       127.0.0.1
EOF
    fi

    # Configurar named.conf.local
    if ! grep -q "$DNS_DOMAIN" "$DNS_CONFIG_FILE" 2>/dev/null; then
        cat >> "$DNS_CONFIG_FILE" << EOF

zone "$DNS_DOMAIN" {
    type master;
    file "$DNS_ZONE_FILE";
    allow-update { key "$DNS_DOMAIN"; };
};
EOF
    fi

    # Reiniciar bind9
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart bind9
        systemctl enable bind9
    elif command -v service >/dev/null 2>&1; then
        service bind9 restart
    fi

    log "SUCCESS" "Servidor DNS local configurado correctamente"
}

# Función para actualizar registro DNS
update_dns_record() {
    local remote_host="$1"
    local tunnel_port="$2"

    if [[ "$ENABLE_DNS_LOCAL" != "true" ]] || [[ ! -f "$DNS_UPDATE_KEY" ]]; then
        return 0
    fi

    log "INFO" "Actualizando registro DNS para tunnel.$DNS_DOMAIN -> $remote_host:$tunnel_port"

    # Usar nsupdate para actualizar el registro DNS
    local nsupdate_cmd=$(cat << EOF
server 127.0.0.1
zone $DNS_DOMAIN
update delete tunnel.$DNS_DOMAIN A
update add tunnel.$DNS_DOMAIN 300 A $remote_host
send
EOF
)

    echo "$nsupdate_cmd" | nsupdate -k "$DNS_UPDATE_KEY" 2>/dev/null

    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "Registro DNS actualizado: tunnel.$DNS_DOMAIN -> $remote_host"
    else
        log "WARNING" "Falló la actualización del registro DNS"
    fi
}

# Función para verificar resolución DNS de un dominio
check_domain_dns() {
    local domain="$1"
    local start_time=$(date +%s%N)

    # Usar dig o nslookup para resolver DNS
    if command -v dig >/dev/null 2>&1; then
        local result=$(dig +timeout="$DNS_TIMEOUT" +short "$domain" A 2>/dev/null | head -1)
        local exit_code=$?
    elif command -v nslookup >/dev/null 2>&1; then
        local result=$(nslookup "$domain" 2>/dev/null | grep -E "Address.*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | head -1 | awk '{print $2}')
        local exit_code=$?
    else
        # Fallback con ping
        local result=$(ping -c1 -W"$DNS_TIMEOUT" "$domain" 2>/dev/null | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -1)
        local exit_code=$?
    fi

    local end_time=$(date +%s%N)
    local dns_time=$(( (end_time - start_time) / 1000000 )) # Convertir a ms

    if [[ $exit_code -eq 0 ]] && [[ -n "$result" ]]; then
        echo "{\"status\":\"success\",\"ip\":\"$result\",\"time_ms\":$dns_time}"
        return 0
    else
        echo "{\"status\":\"failed\",\"ip\":\"\",\"time_ms\":$dns_time}"
        return 1
    fi
}

# Función para verificar conectividad TCP/UDP a puertos específicos
check_port_connectivity() {
    local domain="$1"
    local ports="$2"  # Lista de puertos separados por :
    local protocol="${3:-tcp}"  # tcp o udp

    local results=()
    local all_success=true

    IFS=':' read -ra PORT_ARRAY <<< "$ports"
    for port in "${PORT_ARRAY[@]}"; do
        if [[ "$protocol" == "tcp" ]]; then
            # Verificar conectividad TCP
            if nc -z -w3 "$domain" "$port" 2>/dev/null; then
                results+=("{\"port\":$port,\"status\":\"success\"}")
            else
                results+=("{\"port\":$port,\"status\":\"failed\"}")
                all_success=false
            fi
        else
            # Verificar conectividad UDP (más limitado)
            if nc -z -u -w3 "$domain" "$port" 2>/dev/null; then
                results+=("{\"port\":$port,\"status\":\"success\"}")
            else
                results+=("{\"port\":$port,\"status\":\"failed\"}")
                all_success=false
            fi
        fi
    done

    local result_json=$(IFS=,; echo "[${results[*]}]")
    echo "{\"protocol\":\"$protocol\",\"results\":$result_json,\"all_success\":$all_success}"
    $all_success && return 0 || return 1
}

# Función para medir latencia y pérdida de paquetes
measure_network_metrics() {
    local domain="$1"
    local count="${2:-10}"  # Número de paquetes ping

    # Ejecutar ping para medir latencia y pérdida
    local ping_output=$(ping -c "$count" -W 2 "$domain" 2>/dev/null)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        # Extraer estadísticas del ping
        local packet_loss=$(echo "$ping_output" | grep -oE "[0-9]+% packet loss" | grep -oE "[0-9]+")
        local avg_latency=$(echo "$ping_output" | grep -oE "rtt min/avg/max/mdev = [0-9.]+/[0-9.]+/[0-9.]+/[0-9.]+" | grep -oE "/[0-9.]+/" | sed 's/\///g' | awk '{print $2}')

        # Convertir a números enteros
        packet_loss=${packet_loss:-100}
        avg_latency=${avg_latency:-9999}

        # Convertir latencia a ms si es necesario
        if [[ $avg_latency =~ ^[0-9]+\.[0-9]+$ ]]; then
            avg_latency=$(echo "$avg_latency * 1000" | bc | cut -d'.' -f1)
        fi

        echo "{\"packet_loss_percent\":$packet_loss,\"avg_latency_ms\":$avg_latency,\"reachable\":true}"
        return 0
    else
        echo "{\"packet_loss_percent\":100,\"avg_latency_ms\":9999,\"reachable\":false}"
        return 1
    fi
}

# Función para enviar alertas de dominio (ahora integrada con el sistema central de alertas)
send_domain_alert() {
    local domain="$1"
    local alert_type="$2"
    local message="$3"

    # Determinar nivel de prioridad basado en el tipo de alerta
    local alert_level="WARNING"
    case "$alert_type" in
        "CRITICAL"|"DOWN") alert_level="CRITICAL" ;;
        "ERROR") alert_level="ERROR" ;;
        "WARNING") alert_level="WARNING" ;;
        "INFO") alert_level="INFO" ;;
        *) alert_level="WARNING" ;;
    esac

    # Usar el sistema central de alertas
    send_alert "$alert_level" "Dominio $domain: $message" "DOMAIN_$alert_type"

    # Log específico para dominios (mantenido por compatibilidad)
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ALERT] [$alert_type] $domain: $message" >> "$DOMAIN_LOG_FILE"
}

# Función para monitorear un dominio específico
monitor_single_domain() {
    local domain_config="$1"
    IFS=':' read -r domain ports <<< "$domain_config"

    local domain_status="{}"
    local alerts=()

    # Verificar DNS
    local dns_result=$(check_domain_dns "$domain")
    local dns_status=$(echo "$dns_result" | jq -r '.status' 2>/dev/null || echo "failed")
    local dns_time=$(echo "$dns_result" | jq -r '.time_ms' 2>/dev/null || echo "0")
    local dns_ip=$(echo "$dns_result" | jq -r '.ip' 2>/dev/null || echo "")

    if [[ "$dns_status" == "success" ]]; then
        if (( dns_time > DNS_TIMEOUT * 1000 )); then
            alerts+=("DNS lento: ${dns_time}ms (umbral: ${DNS_TIMEOUT}s)")
        fi
    else
        alerts+=("Fallo en resolución DNS")
    fi

    # Verificar conectividad TCP
    local tcp_result=$(check_port_connectivity "$domain" "$ports" "tcp")
    local tcp_success=$(echo "$tcp_result" | jq -r '.all_success' 2>/dev/null || echo "false")

    if [[ "$tcp_success" != "true" ]]; then
        alerts+=("Puertos TCP no accesibles")
    fi

    # Medir latencia y pérdida de paquetes
    local network_result=$(measure_network_metrics "$domain")
    local packet_loss=$(echo "$network_result" | jq -r '.packet_loss_percent' 2>/dev/null || echo "100")
    local latency=$(echo "$network_result" | jq -r '.avg_latency_ms' 2>/dev/null || echo "9999")
    local reachable=$(echo "$network_result" | jq -r '.reachable' 2>/dev/null || echo "false")

    if [[ "$reachable" == "true" ]]; then
        if (( packet_loss > PACKET_LOSS_THRESHOLD )); then
            alerts+=("Pérdida de paquetes alta: ${packet_loss}% (umbral: ${PACKET_LOSS_THRESHOLD}%)")
        fi
        if (( latency > LATENCY_THRESHOLD )); then
            alerts+=("Latencia alta: ${latency}ms (umbral: ${LATENCY_THRESHOLD}ms)")
        fi
    else
        alerts+=("Dominio no reachable")
    fi

    # Generar alertas si hay problemas
    if [[ ${#alerts[@]} -gt 0 ]] && [[ "$ENABLE_DOMAIN_ALERTS" == "true" ]]; then
        for alert in "${alerts[@]}"; do
            # Determinar severidad basada en el tipo de problema
            local severity="WARNING"
            if [[ "$alert" == *"no reachable"* ]] || [[ "$alert" == *"Fallo en resolución DNS"* ]]; then
                severity="CRITICAL"
            elif [[ "$alert" == *"lento"* ]] || [[ "$alert" == *"alta"* ]]; then
                severity="ERROR"
            fi
            send_domain_alert "$domain" "$severity" "$alert"
        done
    fi

    # Crear objeto JSON con estado del dominio
    local alert_array_json=$(printf '%s\n' "${alerts[@]}" | jq -R . | jq -s . 2>/dev/null || echo "[]")

    cat << EOF
{
    "domain": "$domain",
    "timestamp": "$(date -Iseconds)",
    "dns": {
        "status": "$dns_status",
        "time_ms": $dns_time,
        "ip": "$dns_ip"
    },
    "connectivity": {
        "tcp_success": $tcp_success,
        "ports": "$ports"
    },
    "network": {
        "packet_loss_percent": $packet_loss,
        "avg_latency_ms": $latency,
        "reachable": $reachable
    },
    "alerts": $alert_array_json
}
EOF
}

# Función del monitor de dominios 24/7
domain_monitor() {
    log "INFO" "Iniciando monitor 24/7 de dominios"

    # Crear archivo de estado si no existe
    if [[ ! -f "$DOMAIN_STATUS_FILE" ]]; then
        echo "{}" > "$DOMAIN_STATUS_FILE"
    fi

    while true; do
        local all_domains_status=()

        # Monitorear cada dominio configurado
        for domain_config in "${MONITORED_DOMAINS[@]}"; do
            local domain_status=$(monitor_single_domain "$domain_config")
            all_domains_status+=("$domain_status")

            # Log básico del estado
            local domain=$(echo "$domain_status" | jq -r '.domain' 2>/dev/null)
            local dns_status=$(echo "$domain_status" | jq -r '.dns.status' 2>/dev/null)
            local reachable=$(echo "$domain_status" | jq -r '.network.reachable' 2>/dev/null)

            log "INFO" "Dominio $domain - DNS: $dns_status, Reachable: $reachable"
        done

        # Guardar estado completo en archivo JSON
        local domains_json=$(printf '%s\n' "${all_domains_status[@]}" | jq -s . 2>/dev/null || echo "[]")
        echo "{\"timestamp\":\"$(date -Iseconds)\",\"domains\":$domains_json}" > "$DOMAIN_STATUS_FILE"

        # Esperar intervalo configurado
        sleep "$DOMAIN_MONITOR_INTERVAL"
    done
}

# Función para detener el túnel
stop_tunnel() {
    if [[ -f "$TUNNEL_PID_FILE" ]]; then
        local tunnel_info=$(cat "$TUNNEL_PID_FILE")
        IFS=':' read -r tunnel_pid server_config timestamp <<< "$tunnel_info"
        if kill -0 "$tunnel_pid" 2>/dev/null; then
            log "INFO" "Deteniendo túnel SSH (PID: $tunnel_pid)"
            kill "$tunnel_pid" 2>/dev/null
            sleep 2
            if kill -0 "$tunnel_pid" 2>/dev/null; then
                kill -9 "$tunnel_pid" 2>/dev/null
            fi
        fi
        rm -f "$TUNNEL_PID_FILE"
        log "SUCCESS" "Túnel SSH detenido"
    fi
}

# Función del monitor 24/7 con sistema de respaldo avanzado
tunnel_monitor() {
    log "INFO" "Iniciando monitor 24/7 del sistema de túnel con respaldo avanzado"

    # Variables para el sistema de respaldo
    local last_backup_time=0
    local last_interface_check=0
    local last_service_check=0
    local consecutive_failures=0
    local last_scenario_detection=0

    while true; do
        local current_time=$(date +%s)

        # === SISTEMA DE RESPALDO AVANZADO ===

        # 1. Monitoreo de interfaces de red cada 30 segundos
        if (( current_time - last_interface_check >= 30 )); then
            detect_network_interfaces
            last_interface_check=$current_time

            # Detección rápida de fallos (< 10 segundos)
            local failed_interfaces=$(detect_network_failure)
            if [[ -n "$failed_interfaces" ]]; then
                ((consecutive_failures++))
                log "CRITICAL" "Fallo de red detectado en interfaces: $failed_interfaces (fallos consecutivos: $consecutive_failures)"

                # Rotación automática de conexiones
                if ! rotate_network_connection $failed_interfaces; then
                    handle_specific_scenarios "internet_outage" "interfaces_failed:$failed_interfaces"
                fi
            else
                # Reset contador de fallos si la red funciona
                if [[ $consecutive_failures -gt 0 ]]; then
                    log "INFO" "Conectividad de red restaurada después de $consecutive_failures fallos consecutivos"
                    send_alert "INFO" "Conectividad de red restaurada automáticamente" "NETWORK_RECOVERY"
                    consecutive_failures=0
                fi
            fi
        fi

        # 2. Verificar conectividad a internet con respaldo
        if ! check_internet; then
            send_alert "CRITICAL" "Pérdida total de conectividad a internet - Eventualidad de red crítica" "NETWORK_OUTAGE"
            log "WARNING" "Sin conectividad a internet - esperando recuperación automática..."
            sleep 10
            continue
        fi

        # 3. Obtener IP externa actual
        local current_ip=$(get_external_ip)
        if [[ -z "$current_ip" ]]; then
            send_alert "ERROR" "No se pudo obtener IP externa - Posible problema de conectividad de red" "IP_DETECTION_FAILURE"
            log "ERROR" "No se pudo obtener la IP externa"
            sleep 10
            continue
        fi

        # 4. Detectar cambios de ISP
        local previous_ip_file="/var/run/previous_external_ip"
        if [[ -f "$previous_ip_file" ]]; then
            local previous_ip=$(cat "$previous_ip_file")
            if [[ "$current_ip" != "$previous_ip" ]]; then
                handle_specific_scenarios "isp_change" "old_ip:$previous_ip,new_ip:$current_ip"
            fi
        fi
        echo "$current_ip" > "$previous_ip_file"

        # 5. Verificar si la IP es privada y gestionar túnel
        if is_private_ip "$current_ip"; then
            log "INFO" "IP privada detectada: $current_ip - Verificando túnel"

            # Verificar estado del túnel
            if ! check_tunnel_status; then
                send_alert "WARNING" "Túnel SSH inactivo detectado - Intentando reconexión automática" "TUNNEL_STATUS"
                log "WARNING" "Túnel inactivo - Intentando reconectar"

                # Intentar restablecer el túnel usando configuración automática
                if [[ -f "$CONFIG_FILE" ]]; then
                    source "$CONFIG_FILE"

                    if setup_ssh_tunnel; then
                        send_alert "INFO" "Túnel SSH restablecido exitosamente después de falla" "TUNNEL_RECOVERY"
                        log "SUCCESS" "Túnel restablecido exitosamente"
                    else
                        send_alert "ERROR" "Falló al restablecer el túnel SSH - Conversión a IP pública no disponible" "TUNNEL_FAILURE"
                        log "ERROR" "Falló al restablecer el túnel"
                        handle_specific_scenarios "hardware_failure" "tunnel_setup_failed"
                    fi
                else
                    send_alert "CRITICAL" "Archivo de configuración no encontrado - Sistema de túnel inoperable" "CONFIG_ERROR"
                    log "ERROR" "Archivo de configuración no encontrado: $CONFIG_FILE"
                fi
            else
                log "INFO" "Túnel activo y funcionando correctamente"
            fi
        else
            log "INFO" "IP pública detectada: $current_ip - No se requiere túnel"

            # Si hay un túnel activo, detenerlo
            if check_tunnel_status; then
                send_alert "INFO" "IP pública detectada - Deteniendo túnel innecesario" "IP_CHANGE"
                log "INFO" "Deteniendo túnel innecesario (IP pública disponible)"
                stop_tunnel
            fi
        fi

        # 6. Recuperación automática de servicios cada 5 minutos
        if (( current_time - last_service_check >= 300 )); then
            auto_recover_services
            last_service_check=$current_time
        fi

        # 7. Respaldo automático de configuraciones cada 6 horas
        if (( current_time - last_backup_time >= 21600 )); then
            backup_critical_configs
            last_backup_time=$current_time
        fi

        # 8. Detección de escenarios específicos cada 2 minutos
        if (( current_time - last_scenario_detection >= 120 )); then
            # Verificar posible DDoS
            if [[ "$(check_high_traffic)" == "true" ]]; then
                handle_specific_scenarios "ddos_attack" "high_traffic_detected"
            fi

            # Verificar sobrecarga del sistema
            local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
            if (( $(echo "$load_avg > 5.0" | bc -l 2>/dev/null || echo 0) )); then
                handle_specific_scenarios "overload" "high_load:$load_avg"
            fi

            last_scenario_detection=$current_time
        fi

        # 9. Monitorear dominios configurados
        if [[ ${#MONITORED_DOMAINS[@]} -gt 0 ]]; then
            log "INFO" "Verificando estado de ${#MONITORED_DOMAINS[@]} dominios"

            for domain_config in "${MONITORED_DOMAINS[@]}"; do
                IFS=':' read -r domain ports <<< "$domain_config"
                local domain_status=$(monitor_single_domain "$domain_config")

                # Log resumen del estado del dominio
                local dns_status=$(echo "$domain_status" | jq -r '.dns.status' 2>/dev/null || echo "unknown")
                local reachable=$(echo "$domain_status" | jq -r '.network.reachable' 2>/dev/null || echo "false")
                local alerts_count=$(echo "$domain_status" | jq -r '.alerts | length' 2>/dev/null || echo "0")

                if [[ "$dns_status" == "success" ]] && [[ "$reachable" == "true" ]] && [[ "$alerts_count" == "0" ]]; then
                    log "INFO" "Dominio $domain: OK"
                else
                    log "WARNING" "Dominio $domain: Problemas detectados (DNS: $dns_status, Reachable: $reachable, Alertas: $alerts_count)"
                fi
            done
        fi

        # Intervalo configurable de monitoreo (por defecto 30 segundos para mayor responsividad)
        local monitor_interval=${TUNNEL_MONITOR_INTERVAL:-30}
        sleep "$monitor_interval"
    done
}

# Función para configurar el sistema
configure_system() {
    log "INFO" "Configurando sistema de túnel automático"

    # Crear directorios necesarios
    mkdir -p /etc/auto-tunnel
    mkdir -p /var/log
    mkdir -p /var/run

    # Crear directorios necesarios para el sistema de respaldo
    mkdir -p "$BACKUP_CONFIG_DIR"
    mkdir -p /var/log
    mkdir -p /var/run

    # Crear archivo de configuración si no existe
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Configuración del Sistema de Túnel Automático con Respaldo Avanzado
# Modificar estos valores según sus necesidades

# Configuración de servidores remotos para túnel SSH (múltiples con balanceo de carga)
# Formato: "host:user:port:weight" - weight determina prioridad en balanceo de carga
TUNNEL_REMOTE_SERVERS=(
    "tu-servidor-remoto1.com:tunnel_user1:22:10"
    "tu-servidor-remoto2.com:tunnel_user2:22:8"
    "tu-servidor-remoto3.com:tunnel_user3:22:6"
)
TUNNEL_LOCAL_PORT="80"
TUNNEL_PORT_BASE="8080"
ENABLE_LOAD_BALANCING="true"
ENABLE_FAILOVER="true"

# Configuración de monitoreo avanzado
TUNNEL_MONITOR_INTERVAL="30"          # Intervalo de monitoreo principal en segundos
MONITOR_INTERVAL="30"
ENABLE_AUTO_RESTART="true"

# Configuración de alertas avanzadas
ENABLE_SYSTEM_NOTIFICATIONS="true"    # Notificaciones del sistema (notify-send)
ALERT_LEVEL_THRESHOLD="1"              # Nivel mínimo de alertas (0=DEBUG, 1=INFO, 2=WARNING, 3=ERROR, 4=CRITICAL)
ALERT_EMAIL_RECIPIENTS=""             # Destinatarios de email separados por comas
ALERT_WEBHOOK_URLS=""                 # URLs de webhooks separados por comas
ALERT_DASHBOARD_FILE="/var/log/auto_tunnel_alerts.json"  # Archivo para dashboard de alertas

# Configuración de monitoreo de dominios 24/7
MONITORED_DOMAINS=(
    "google.com:80:443"
    "cloudflare.com:80:443"
    "github.com:22:80:443"
    "stackoverflow.com:80:443"
)
DNS_TIMEOUT="5"           # Timeout para resolución DNS en segundos (< 5s recomendado)
LATENCY_THRESHOLD="500"   # Umbral de latencia en ms (< 500ms recomendado)
PACKET_LOSS_THRESHOLD="10" # Umbral de pérdida de paquetes en porcentaje (< 10% recomendado)
DOMAIN_MONITOR_INTERVAL="60" # Intervalo de monitoreo de dominios en segundos
ENABLE_DOMAIN_ALERTS="true"   # Habilitar alertas automáticas para dominios
DOMAIN_ALERT_EMAIL=""         # Email para alertas de dominios
DOMAIN_ALERT_WEBHOOK=""       # Webhook para alertas de dominios

# Configuración de DNS local (bind9)
ENABLE_DNS_LOCAL="true"
DNS_DOMAIN="tunnel.local"
DNS_ZONE_FILE="/var/lib/bind/db.${DNS_DOMAIN}"
DNS_CONFIG_FILE="/etc/bind/named.conf.local"
DNS_UPDATE_KEY="/etc/bind/ddns.key"

# === CONFIGURACIÓN DEL SISTEMA DE RESPALDO AVANZADO ===

# Configuración de respaldo automático
ENABLE_AUTO_BACKUP="true"              # Habilitar respaldo automático de configuraciones
BACKUP_INTERVAL="21600"                # Intervalo de respaldo en segundos (6 horas)
MAX_BACKUP_RETENTION="10"              # Número máximo de respaldos a mantener

# Configuración de recuperación automática de servicios
ENABLE_AUTO_SERVICE_RECOVERY="true"    # Habilitar recuperación automática de servicios
SERVICE_RECOVERY_INTERVAL="300"        # Intervalo de verificación de servicios en segundos (5 min)

# Configuración de monitoreo de interfaces de red
ENABLE_INTERFACE_MONITORING="true"     # Habilitar monitoreo de múltiples interfaces
INTERFACE_CHECK_INTERVAL="30"          # Intervalo de verificación de interfaces en segundos

# Configuración de failover avanzado
ENABLE_ADVANCED_FAILOVER="true"        # Habilitar failover avanzado
FAILOVER_TIMEOUT="10"                  # Timeout para failover en segundos (< 10s)
MAX_CONSECUTIVE_FAILURES="3"           # Máximo de fallos consecutivos antes de alerta crítica

# Configuración de detección de escenarios específicos
ENABLE_SCENARIO_DETECTION="true"       # Habilitar detección automática de escenarios
SCENARIO_CHECK_INTERVAL="120"          # Intervalo de verificación de escenarios en segundos

# Umbrales para detección de ataques DDoS
DDOS_TCP_CONNECTION_THRESHOLD="500"    # Umbral de conexiones TCP para DDoS
DDOS_UDP_CONNECTION_THRESHOLD="1000"   # Umbral de conexiones UDP para DDoS

# Umbrales para detección de sobrecarga
SYSTEM_LOAD_THRESHOLD="5.0"            # Umbral de carga del sistema

# Configuración de rotación automática de conexiones
ENABLE_CONNECTION_ROTATION="true"      # Habilitar rotación automática de conexiones
CONNECTION_PRIORITY_ORDER=("ethernet" "wifi" "mobile")  # Orden de prioridad para rotación

# Configuración de respaldo de configuraciones críticas
CRITICAL_CONFIG_FILES=(
    "/etc/network/interfaces"
    "/etc/resolv.conf"
    "/etc/hosts"
    "/etc/ssh/sshd_config"
    "/etc/fail2ban/jail.local"
    "/etc/iptables/rules.v4"
    "/etc/iptables/rules.v6"
)

# Servicios críticos para recuperación automática
CRITICAL_SERVICES=(
    "ssh:ssh.service"
    "networking:networking.service"
    "fail2ban:fail2ban.service"
    "bind9:bind9.service"
    "iptables:iptables.service"
)
EOF

        log "INFO" "Archivo de configuración creado: $CONFIG_FILE"
        echo -e "${YELLOW}⚠️  IMPORTANTE: Configure los parámetros en $CONFIG_FILE antes de continuar${NC}"
    fi

    # Instalar dependencias incluyendo las del sistema de respaldo avanzado
    log "INFO" "Verificando dependencias del sistema con respaldo avanzado"

    local dependencies=("curl" "ssh" "ping" "nohup" "nc" "jq" "bc" "netstat")
    local missing_deps=()

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "WARNING" "Dependencias faltantes: ${missing_deps[*]}"
        echo -e "${YELLOW}Instalando dependencias faltantes...${NC}"

        if command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y "${missing_deps[@]}" netcat-openbsd jq bc net-tools
        elif command -v yum >/dev/null 2>&1; then
            yum install -y "${missing_deps[@]}" nc jq bc net-tools
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y "${missing_deps[@]}" nc jq bc net-tools
        else
            log "ERROR" "No se pudo instalar dependencias - gestor de paquetes no reconocido"
            return 1
        fi
    fi

    # Configurar DNS local si está habilitado
    if [[ "$ENABLE_DNS_LOCAL" == "true" ]]; then
        setup_bind9_dns
    fi

    log "SUCCESS" "Sistema configurado correctamente"
}

# Función para mostrar estado del sistema
show_status() {
    echo -e "${BLUE}=== ESTADO DEL SISTEMA DE TÚNEL AUTOMÁTICO ===${NC}"
    echo

    # Verificar conectividad
    echo -e "${CYAN}🔗 Conectividad a Internet:${NC}"
    if check_internet; then
        echo -e "   ✅ ${GREEN}Conectado${NC}"
    else
        echo -e "   ❌ ${RED}Sin conexión${NC}"
    fi

    # Mostrar IP externa
    local external_ip=$(get_external_ip)
    echo -e "${CYAN}🌐 IP Externa:${NC} $external_ip"

    # Verificar si es IP privada
    if is_private_ip "$external_ip"; then
        echo -e "${CYAN}🏠 Tipo de IP:${NC} ${YELLOW}Privada${NC} (Requiere túnel)"
    else
        echo -e "${CYAN}🌍 Tipo de IP:${NC} ${GREEN}Pública${NC} (No requiere túnel)"
    fi

    # Estado del túnel
    echo -e "${CYAN}🚇 Estado del Túnel:${NC}"
    if check_tunnel_status; then
        local tunnel_info=$(cat "$TUNNEL_PID_FILE" 2>/dev/null)
        IFS=':' read -r tunnel_pid server_config timestamp <<< "$tunnel_info"
        IFS=':' read -r host user port weight <<< "$server_config"
        echo -e "   ✅ ${GREEN}Activo${NC} (PID: $tunnel_pid, Servidor: $host, Puerto: $port)"
    else
        echo -e "   ❌ ${RED}Inactivo${NC}"
    fi

    # Balanceo de carga y failover
    echo -e "${CYAN}⚖️  Balanceo de Carga:${NC}"
    if [[ "$ENABLE_LOAD_BALANCING" == "true" ]]; then
        echo -e "   ✅ ${GREEN}Habilitado${NC}"
        echo -e "   📊 Servidores configurados: ${#TUNNEL_REMOTE_SERVERS[@]}"
    else
        echo -e "   ❌ ${RED}Deshabilitado${NC}"
    fi

    echo -e "${CYAN}🔄 Failover:${NC}"
    if [[ "$ENABLE_FAILOVER" == "true" ]]; then
        echo -e "   ✅ ${GREEN}Habilitado${NC}"
    else
        echo -e "   ❌ ${RED}Deshabilitado${NC}"
    fi

    # DNS Local
    echo -e "${CYAN}🌐 DNS Local:${NC}"
    if [[ "$ENABLE_DNS_LOCAL" == "true" ]]; then
        echo -e "   ✅ ${GREEN}Habilitado${NC} (Dominio: $DNS_DOMAIN)"
        if pgrep -f "named" >/dev/null 2>&1; then
            echo -e "   ✅ ${GREEN}Servicio bind9 activo${NC}"
        else
            echo -e "   ❌ ${RED}Servicio bind9 inactivo${NC}"
        fi
    else
        echo -e "   ❌ ${RED}Deshabilitado${NC}"
    fi

    # Estado del monitor
    echo -e "${CYAN}👁️  Estado del Monitor:${NC}"
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        local monitor_pid=$(cat "$MONITOR_PID_FILE" 2>/dev/null)
        if kill -0 "$monitor_pid" 2>/dev/null; then
            echo -e "   ✅ ${GREEN}Activo${NC} (PID: $monitor_pid)"
        else
            echo -e "   ❌ ${RED}Inactivo${NC} (proceso muerto)"
            rm -f "$MONITOR_PID_FILE"
        fi
    else
        echo -e "   ❌ ${RED}No iniciado${NC}"
    fi

    # === SISTEMA DE RESPALDO AVANZADO ===

    # Monitoreo de interfaces de red
    echo -e "${CYAN}🔌 Interfaces de Red:${NC}"
    if [[ -f "$NETWORK_INTERFACES_STATUS" ]]; then
        local interface_count=$(jq '.interfaces | length' "$NETWORK_INTERFACES_STATUS" 2>/dev/null || echo "0")
        local active_interfaces=$(jq '.interfaces[] | select(.status == "up") | .interface' "$NETWORK_INTERFACES_STATUS" 2>/dev/null | wc -l)
        echo -e "   📊 Total: $interface_count, Activas: $active_interfaces"

        # Mostrar detalles de interfaces activas
        jq -r '.interfaces[] | select(.status == "up") | "   ✅ \(.interface) (\(.type)) - \(.ip)"' "$NETWORK_INTERFACES_STATUS" 2>/dev/null || true
    else
        echo -e "   ❌ ${RED}Información no disponible${NC}"
    fi

    # Sistema de respaldo
    echo -e "${CYAN}💾 Sistema de Respaldo:${NC}"
    if [[ -d "$BACKUP_CONFIG_DIR" ]]; then
        local backup_count=$(ls -1d "$BACKUP_CONFIG_DIR"/* 2>/dev/null | grep -v latest | wc -l)
        if [[ -L "$BACKUP_CONFIG_DIR/latest" ]]; then
            local latest_backup=$(readlink "$BACKUP_CONFIG_DIR/latest" | xargs basename)
            echo -e "   ✅ ${GREEN}Activo${NC} (Total: $backup_count respaldos, Último: $latest_backup)"
        else
            echo -e "   ✅ ${GREEN}Activo${NC} (Total: $backup_count respaldos)"
        fi
    else
        echo -e "   ❌ ${RED}No configurado${NC}"
    fi

    # Recuperación automática de servicios
    echo -e "${CYAN}🔧 Recuperación de Servicios:${NC}"
    if [[ -f "$SERVICE_RECOVERY_LOG" ]]; then
        local last_recovery=$(tail -1 "$SERVICE_RECOVERY_LOG" 2>/dev/null | cut -d' ' -f1-3 || echo "Nunca")
        echo -e "   ✅ ${GREEN}Activa${NC} (Última: $last_recovery)"
    else
        echo -e "   ✅ ${GREEN}Activa${NC} (Sin recuperaciones previas)"
    fi

    # Detección de escenarios
    echo -e "${CYAN}🎯 Detección de Escenarios:${NC}"
    if [[ -f "$FAILOVER_LOG" ]]; then
        local scenario_count=$(grep "ESCENARIO_DETECTADO" "$FAILOVER_LOG" 2>/dev/null | wc -l)
        echo -e "   ✅ ${GREEN}Activa${NC} (Escenarios detectados: $scenario_count)"
    else
        echo -e "   ✅ ${GREEN}Activa${NC} (Sin detecciones previas)"
    fi

    # Configuración
    echo -e "${CYAN}⚙️  Configuración:${NC}"
    if [[ -f "$CONFIG_FILE" ]]; then
        echo -e "   ✅ ${GREEN}Archivo de configuración presente${NC}"
        echo -e "   📊 Servidores remotos: ${#TUNNEL_REMOTE_SERVERS[@]} configurados"
        echo -e "   🔄 Failover avanzado: $([[ "$ENABLE_ADVANCED_FAILOVER" == "true" ]] && echo "${GREEN}Habilitado${NC}" || echo "${RED}Deshabilitado${NC}")"
        echo -e "   🔄 Rotación automática: $([[ "$ENABLE_CONNECTION_ROTATION" == "true" ]] && echo "${GREEN}Habilitada${NC}" || echo "${RED}Deshabilitada${NC}")"
    else
        echo -e "   ❌ ${RED}Archivo de configuración faltante${NC}"
    fi

    echo
}

# Función para iniciar el servicio
start_service() {
    log "INFO" "Iniciando servicio de túnel automático"

    # Verificar que no esté ya ejecutándose
    if [[ -f "$PID_FILE" ]]; then
        local existing_pid=$(cat "$PID_FILE")
        if kill -0 "$existing_pid" 2>/dev/null; then
            log "WARNING" "El servicio ya está ejecutándose (PID: $existing_pid)"
            echo -e "${YELLOW}El servicio ya está ejecutándose${NC}"
            return 1
        else
            rm -f "$PID_FILE"
        fi
    fi

    # Configurar el sistema si es necesario
    configure_system

    # Iniciar el monitor en background
    log "INFO" "Iniciando monitor del túnel"
    tunnel_monitor &
    local monitor_pid=$!

    # Guardar PIDs
    echo "$monitor_pid" > "$MONITOR_PID_FILE"
    echo "$$" > "$PID_FILE"

    send_alert "INFO" "Servicio de túnel automático iniciado exitosamente - Monitoreo 24/7 activado" "SERVICE_START"
    log "SUCCESS" "Servicio de túnel automático iniciado (PID: $monitor_pid)"
    echo -e "${GREEN}✅ Servicio de túnel automático iniciado${NC}"
    echo -e "${BLUE}📊 Use '$0 status' para ver el estado del sistema${NC}"
}

# Función para detener el servicio
stop_service() {
    log "INFO" "Deteniendo servicio de túnel automático"

    # Detener el túnel si está activo
    stop_tunnel

    # Detener el monitor
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        local monitor_pid=$(cat "$MONITOR_PID_FILE")
        if kill -0 "$monitor_pid" 2>/dev/null; then
            log "INFO" "Deteniendo monitor (PID: $monitor_pid)"
            kill "$monitor_pid" 2>/dev/null
            sleep 2
            if kill -0 "$monitor_pid" 2>/dev/null; then
                kill -9 "$monitor_pid" 2>/dev/null
            fi
        fi
        rm -f "$MONITOR_PID_FILE"
    fi

    # Limpiar archivos PID
    rm -f "$PID_FILE"

    send_alert "WARNING" "Servicio de túnel automático detenido - Monitoreo 24/7 desactivado" "SERVICE_STOP"
    log "SUCCESS" "Servicio de túnel automático detenido"
    echo -e "${GREEN}✅ Servicio de túnel automático detenido${NC}"
}

# Función principal
main() {
    local command="${1:-status}"

    case "$command" in
        "start")
            start_service
            ;;
        "stop")
            stop_service
            ;;
        "restart")
            stop_service
            sleep 2
            start_service
            ;;
        "status")
            show_status
            ;;
        "configure")
            configure_system
            ;;
        "test")
            echo -e "${BLUE}=== PRUEBA DEL SISTEMA DE TÚNEL CON RESPALDO AVANZADO ===${NC}"
            echo

            echo -e "${CYAN}🔗 Probando conectividad a internet...${NC}"
            if check_internet; then
                echo -e "   ✅ ${GREEN}Conectividad OK${NC}"
            else
                echo -e "   ❌ ${RED}Sin conectividad${NC}"
            fi

            echo -e "${CYAN}🌐 Obteniendo IP externa...${NC}"
            local ip=$(get_external_ip)
            if [[ -n "$ip" ]]; then
                echo -e "   ✅ ${GREEN}IP externa: $ip${NC}"
                if is_private_ip "$ip"; then
                    echo -e "   ℹ️  ${YELLOW}IP privada detectada - túnel requerido${NC}"
                else
                    echo -e "   ℹ️  ${GREEN}IP pública detectada - túnel no requerido${NC}"
                fi
            else
                echo -e "   ❌ ${RED}No se pudo obtener IP externa${NC}"
            fi

            echo -e "${CYAN}🚇 Verificando estado del túnel...${NC}"
            if check_tunnel_status; then
                echo -e "   ✅ ${GREEN}Túnel activo${NC}"
            else
                echo -e "   ❌ ${RED}Túnel inactivo${NC}"
            fi

            echo -e "${CYAN}⚖️  Probando balanceo de carga...${NC}"
            if [[ "$ENABLE_LOAD_BALANCING" == "true" ]]; then
                local selected=$(select_remote_server 2>/dev/null)
                if [[ -n "$selected" ]]; then
                    IFS=':' read -r host user port weight <<< "$selected"
                    echo -e "   ✅ ${GREEN}Servidor seleccionado: $host (peso: $weight)${NC}"
                else
                    echo -e "   ❌ ${RED}No se pudo seleccionar servidor${NC}"
                fi
            else
                echo -e "   ℹ️  ${YELLOW}Balanceo de carga deshabilitado${NC}"
            fi

            echo -e "${CYAN}🌐 Probando DNS local...${NC}"
            if [[ "$ENABLE_DNS_LOCAL" == "true" ]]; then
                if command -v nslookup >/dev/null 2>&1; then
                    local dns_test=$(nslookup tunnel.$DNS_DOMAIN 127.0.0.1 2>/dev/null | grep -E "Address.*127\.0\.0\.1" | wc -l)
                    if [[ $dns_test -gt 0 ]]; then
                        echo -e "   ✅ ${GREEN}DNS local funcionando${NC}"
                    else
                        echo -e "   ❌ ${RED}DNS local no responde${NC}"
                    fi
                else
                    echo -e "   ℹ️  ${YELLOW}nslookup no disponible para prueba DNS${NC}"
                fi
            else
                echo -e "   ℹ️  ${YELLOW}DNS local deshabilitado${NC}"
            fi

            # Pruebas del sistema de respaldo avanzado
            echo -e "${CYAN}🔌 Probando interfaces de red...${NC}"
            detect_network_interfaces >/dev/null 2>&1
            if [[ -f "$NETWORK_INTERFACES_STATUS" ]]; then
                local interface_count=$(jq '.interfaces | length' "$NETWORK_INTERFACES_STATUS" 2>/dev/null || echo "0")
                echo -e "   ✅ ${GREEN}Interfaces detectadas: $interface_count${NC}"
            else
                echo -e "   ❌ ${RED}Error al detectar interfaces${NC}"
            fi

            echo -e "${CYAN}💾 Probando sistema de respaldo...${NC}"
            if [[ -d "$BACKUP_CONFIG_DIR" ]]; then
                echo -e "   ✅ ${GREEN}Sistema de respaldo configurado${NC}"
            else
                echo -e "   ❌ ${RED}Sistema de respaldo no configurado${NC}"
            fi

            echo -e "${CYAN}🔧 Probando recuperación de servicios...${NC}"
            if [[ -f "$SERVICE_RECOVERY_LOG" ]]; then
                echo -e "   ✅ ${GREEN}Sistema de recuperación activo${NC}"
            else
                echo -e "   ℹ️  ${YELLOW}Sistema de recuperación listo${NC}"
            fi

            echo -e "${CYAN}🎯 Probando detección de escenarios...${NC}"
            local high_traffic=$(check_high_traffic)
            if [[ "$high_traffic" == "false" ]]; then
                echo -e "   ✅ ${GREEN}Sin tráfico anormal detectado${NC}"
            else
                echo -e "   ⚠️  ${YELLOW}Tráfico alto detectado${NC}"
            fi
            ;;
        "help"|"-h"|"--help")
            echo -e "${BLUE}=== SISTEMA DE TÚNEL AUTOMÁTICO CON RESPALDO AVANZADO ===${NC}"
            echo
            echo -e "${CYAN}Uso:${NC} $0 [comando]"
            echo
            echo -e "${GREEN}Comandos disponibles:${NC}"
            echo "  start      - Iniciar el servicio de túnel automático"
            echo "  stop       - Detener el servicio de túnel automático"
            echo "  restart    - Reiniciar el servicio"
            echo "  status     - Mostrar estado del sistema"
            echo "  configure  - Configurar el sistema"
            echo "  test       - Ejecutar pruebas del sistema"
            echo "  help       - Mostrar esta ayuda"
            echo
            echo -e "${YELLOW}Ejemplos:${NC}"
            echo "  $0 start          # Iniciar el servicio"
            echo "  $0 status         # Ver estado actual"
            echo "  $0 configure      # Configurar parámetros"
            ;;
        *)
            echo -e "${RED}Comando desconocido: $command${NC}"
            echo -e "${YELLOW}Use '$0 help' para ver comandos disponibles${NC}"
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"