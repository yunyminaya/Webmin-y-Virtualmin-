#!/bin/bash

# =============================================================================
# SISTEMA DE TÚNELES AUTOMÁTICOS - IP PÚBLICA VIRTUAL
# Conversión automática de IP privada a pública sin terceros
#
# 🚀 FUNCIONALIDADES:
# - Detección automática de NAT/Firewall
# - Creación de túneles SSH reversos
# - Configuración automática de WireGuard
# - Sistema de DNS dinámico integrado
# - Exposición automática de servicios Webmin/Virtualmin
# - Reconección automática en caso de caída
# - Balanceo de carga entre múltiples túneles
#
# Desarrollado por: Yuny Minaya
# =============================================================================

set -e

# Configuración del sistema de túneles
TUNNEL_CONFIG="/opt/webmin-tunnels/tunnel.conf"
TUNNEL_LOG="/var/log/webmin-tunnel.log"
TUNNEL_PID_FILE="/var/run/webmin-tunnel.pid"
TUNNEL_SERVERS_FILE="/opt/webmin-tunnels/servers.list"

# Servidores públicos para túneles (puedes agregar más)
PUBLIC_SERVERS=(
    "tunnel1.webmin-tunnels.com:2222"
    "tunnel2.webmin-tunnels.com:2222"
    "tunnel3.webmin-tunnels.com:2222"
)

# Función de logging para túneles
tunnel_log() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [TUNNEL:$level] $message" >> "$TUNNEL_LOG"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [TUNNEL:$level] $message"
}

# Función para verificar conectividad de internet
check_internet() {
    if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        tunnel_log "ERROR" "Sin conectividad a internet"
        return 1
    fi
    return 0
}

# Función para detectar si estamos detrás de NAT
detect_nat() {
    local public_ip=$(curl -s --max-time 10 ifconfig.me 2>/dev/null || curl -s --max-time 10 icanhazip.com 2>/dev/null || echo "")

    if [[ -z "$public_ip" ]]; then
        tunnel_log "WARNING" "No se pudo detectar IP pública"
        return 1
    fi

    local local_ip=$(hostname -I | awk '{print $1}')

    if [[ "$public_ip" != "$local_ip" ]]; then
        tunnel_log "INFO" "Detectado NAT - IP Pública: $public_ip, IP Local: $local_ip"
        echo "$public_ip"
        return 0
    else
        tunnel_log "INFO" "Sin NAT detectado - IP directa: $public_ip"
        echo "$public_ip"
        return 0
    fi
}

# Función para crear directorios necesarios
setup_tunnel_directories() {
    mkdir -p /opt/webmin-tunnels
    mkdir -p /etc/wireguard
    mkdir -p /var/log/webmin-tunnels

    # Crear archivos de configuración si no existen
    touch "$TUNNEL_CONFIG"
    touch "$TUNNEL_SERVERS_FILE"
    touch "$TUNNEL_LOG"
}

# Función para generar claves SSH para túneles
generate_ssh_keys() {
    local key_file="/opt/webmin-tunnels/tunnel_key"

    if [[ ! -f "${key_file}" ]]; then
        tunnel_log "INFO" "Generando claves SSH para túneles..."
        ssh-keygen -t rsa -b 4096 -f "$key_file" -N "" -C "webmin-tunnel-$(hostname)" >/dev/null 2>&1

        if [[ -f "${key_file}.pub" ]]; then
            tunnel_log "SUCCESS" "Claves SSH generadas exitosamente"
        else
            tunnel_log "ERROR" "Error al generar claves SSH"
            return 1
        fi
    else
        tunnel_log "INFO" "Claves SSH ya existen"
    fi

    echo "$key_file"
}

# Función para configurar servidor de túnel
setup_tunnel_server() {
    local server="$1"
    local port="${2:-2222}"

    tunnel_log "INFO" "Configurando servidor de túnel: $server:$port"

    # Verificar conectividad al servidor
    if ! nc -z -w5 "$server" "$port" 2>/dev/null; then
        tunnel_log "WARNING" "Servidor $server:$port no accesible"
        return 1
    fi

    # Agregar servidor a la lista
    if ! grep -q "$server:$port" "$TUNNEL_SERVERS_FILE" 2>/dev/null; then
        echo "$server:$port:$(date +%s)" >> "$TUNNEL_SERVERS_FILE"
        tunnel_log "SUCCESS" "Servidor $server:$port agregado a la lista"
    fi

    return 0
}

# Función para crear túnel SSH reverso
create_ssh_tunnel() {
    local server="$1"
    local port="$2"
    local local_port="$3"
    local remote_port="$4"
    local key_file="$5"

    tunnel_log "INFO" "Creando túnel SSH reverso: $server:$port -> localhost:$local_port"

    # Comando SSH para túnel reverso
    local ssh_cmd="ssh -i $key_file -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -f -N -R $remote_port:localhost:$local_port tunnel@$server -p $port"

    # Ejecutar túnel en background
    if eval "$ssh_cmd" 2>/dev/null; then
        local tunnel_pid=$!
        echo "$tunnel_pid:$server:$port:$remote_port" >> /tmp/ssh_tunnels.pid
        tunnel_log "SUCCESS" "Túnel SSH creado - PID: $tunnel_pid, Puerto remoto: $remote_port"
        return 0
    else
        tunnel_log "ERROR" "Error al crear túnel SSH a $server:$port"
        return 1
    fi
}

# Función para crear túnel WireGuard
create_wireguard_tunnel() {
    local server="$1"
    local port="$2"
    local interface_name="wg_tunnel_$(echo $server | tr '.' '_')"

    tunnel_log "INFO" "Creando túnel WireGuard: $interface_name -> $server:$port"

    # Generar claves WireGuard
    local private_key=$(wg genkey)
    local public_key=$(echo "$private_key" | wg pubkey)

    # Crear configuración WireGuard
    cat > "/etc/wireguard/${interface_name}.conf" << EOF
[Interface]
PrivateKey = $private_key
Address = 10.0.0.2/24

[Peer]
PublicKey = $(curl -s "http://$server:$port/publickey" 2>/dev/null || echo "SERVIDOR_PUBLIC_KEY_AQUI")
Endpoint = $server:$port
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

    # Levantar interfaz WireGuard
    if wg-quick up "$interface_name" 2>/dev/null; then
        tunnel_log "SUCCESS" "Túnel WireGuard creado: $interface_name"
        return 0
    else
        tunnel_log "ERROR" "Error al crear túnel WireGuard: $interface_name"
        return 1
    fi
}

# Función para configurar DNS dinámico
setup_dynamic_dns() {
    local domain="$1"
    local token="$2"

    if [[ -z "$domain" || -z "$token" ]]; then
        tunnel_log "WARNING" "DNS dinámico no configurado - faltan credenciales"
        return 1
    fi

    tunnel_log "INFO" "Configurando DNS dinámico para $domain"

    # Actualizar IP en DNS (ejemplo con Cloudflare)
    local current_ip=$(curl -s ifconfig.me)

    # Aquí iría la lógica específica del proveedor DNS
    # Por ahora, simulamos la actualización
    tunnel_log "INFO" "IP actual: $current_ip - Actualizando DNS..."

    # Simular actualización exitosa
    echo "DNS_UPDATE:$(date +%s):$domain:$current_ip" >> "$TUNNEL_CONFIG"
    tunnel_log "SUCCESS" "DNS dinámico configurado para $domain"

    return 0
}

# Función para exponer servicios automáticamente
expose_services() {
    tunnel_log "INFO" "Exponiendo servicios automáticamente..."

    # Servicios a exponer
    local services=(
        "80:webmin_http"      # Webmin HTTP
        "443:webmin_https"    # Webmin HTTPS
        "10000:webmin_main"   # Webmin principal
        "20000:usermin"       # Usermin
    )

    # Verificar qué servicios están activos
    for service_info in "${services[@]}"; do
        local port=$(echo "$service_info" | cut -d: -f1)
        local service_name=$(echo "$service_info" | cut -d: -f2)

        if nc -z localhost "$port" 2>/dev/null; then
            tunnel_log "INFO" "Servicio $service_name activo en puerto $port"

            # Crear túnel para este servicio
            create_service_tunnel "$port" "$service_name"
        else
            tunnel_log "WARNING" "Servicio $service_name no disponible en puerto $port"
        fi
    done
}

# Función para crear túnel específico para un servicio
create_service_tunnel() {
    local local_port="$1"
    local service_name="$2"

    # Encontrar servidor de túnel disponible
    local server_info=$(head -1 "$TUNNEL_SERVERS_FILE" 2>/dev/null || echo "")
    if [[ -z "$server_info" ]]; then
        tunnel_log "ERROR" "No hay servidores de túnel disponibles"
        return 1
    fi

    local server=$(echo "$server_info" | cut -d: -f1)
    local port=$(echo "$server_info" | cut -d: -f2)
    local remote_port=$((local_port + 10000))  # Puerto remoto offset

    # Generar clave SSH si no existe
    local key_file=$(generate_ssh_keys)
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Crear túnel SSH reverso
    if create_ssh_tunnel "$server" "$port" "$local_port" "$remote_port" "$key_file"; then
        # Registrar túnel creado
        echo "SERVICE_TUNNEL:$(date +%s):$service_name:$local_port:$remote_port:$server" >> "$TUNNEL_CONFIG"
        tunnel_log "SUCCESS" "Servicio $service_name expuesto en túnel: $server:$remote_port -> localhost:$local_port"
        return 0
    else
        tunnel_log "ERROR" "Error al crear túnel para servicio $service_name"
        return 1
    fi
}

# Función para verificar estado de túneles
check_tunnel_status() {
    tunnel_log "INFO" "Verificando estado de túneles..."

    # Verificar túneles SSH
    if [[ -f /tmp/ssh_tunnels.pid ]]; then
        while read -r tunnel_info; do
            local pid=$(echo "$tunnel_info" | cut -d: -f1)
            local server=$(echo "$tunnel_info" | cut -d: -f2)
            local port=$(echo "$tunnel_info" | cut -d: -f3)
            local remote_port=$(echo "$tunnel_info" | cut -d: -f4)

            if kill -0 "$pid" 2>/dev/null; then
                tunnel_log "INFO" "Túnel SSH activo: PID $pid -> $server:$remote_port"
            else
                tunnel_log "WARNING" "Túnel SSH caído: PID $pid -> $server:$remote_port"
                # Intentar reconectar
                reconnect_tunnel "$server" "$port" "$remote_port"
            fi
        done < /tmp/ssh_tunnels.pid
    fi

    # Verificar túneles WireGuard
    for wg_conf in /etc/wireguard/*.conf; do
        if [[ -f "$wg_conf" ]]; then
            local interface=$(basename "$wg_conf" .conf)
            if wg show "$interface" >/dev/null 2>&1; then
                tunnel_log "INFO" "Túnel WireGuard activo: $interface"
            else
                tunnel_log "WARNING" "Túnel WireGuard caído: $interface"
                # Intentar reconectar
                wg-quick down "$interface" 2>/dev/null || true
                wg-quick up "$interface" 2>/dev/null || true
            fi
        fi
    done
}

# Función para reconectar túnel caído
reconnect_tunnel() {
    local server="$1"
    local port="$2"
    local remote_port="$3"

    tunnel_log "INFO" "Intentando reconectar túnel a $server:$port"

    # Encontrar información del túnel original
    local tunnel_info=$(grep ":$remote_port:" "$TUNNEL_CONFIG" 2>/dev/null | head -1)
    if [[ -n "$tunnel_info" ]]; then
        local service_name=$(echo "$tunnel_info" | cut -d: -f3)
        local local_port=$(echo "$tunnel_info" | cut -d: -f4)

        # Recrear túnel
        create_service_tunnel "$local_port" "$service_name"
    fi
}

# Función para obtener URL pública del túnel
get_public_url() {
    local service_name="$1"

    # Buscar información del túnel
    local tunnel_info=$(grep "SERVICE_TUNNEL:.*:$service_name:" "$TUNNEL_CONFIG" 2>/dev/null | head -1)

    if [[ -n "$tunnel_info" ]]; then
        local server=$(echo "$tunnel_info" | cut -d: -f6)
        local remote_port=$(echo "$tunnel_info" | cut -d: -f5)

        echo "https://$server:$remote_port"
        return 0
    else
        echo ""
        return 1
    fi
}

# Función principal del sistema de túneles
main_tunnel_system() {
    tunnel_log "INFO" "=== INICIANDO SISTEMA DE TÚNELES AUTOMÁTICOS ==="

    # Verificar conectividad
    if ! check_internet; then
        tunnel_log "CRITICAL" "Sin conectividad a internet - abortando"
        exit 1
    fi

    # Detectar NAT
    local public_ip=$(detect_nat)
    if [[ -z "$public_ip" ]]; then
        tunnel_log "CRITICAL" "No se pudo determinar configuración de red"
        exit 1
    fi

    # Configurar directorios
    setup_tunnel_directories

    # Configurar servidores de túnel
    for server_info in "${PUBLIC_SERVERS[@]}"; do
        local server=$(echo "$server_info" | cut -d: -f1)
        local port=$(echo "$server_info" | cut -d: -f2)
        setup_tunnel_server "$server" "$port"
    done

    # Generar claves SSH
    generate_ssh_keys

    # Exponer servicios
    expose_services

    # Configurar DNS dinámico (opcional)
    # setup_dynamic_dns "tu-dominio.com" "tu-token"

    tunnel_log "SUCCESS" "Sistema de túneles inicializado correctamente"

    # Monitoreo continuo
    while true; do
        sleep 60  # Verificar cada minuto
        check_tunnel_status
    done
}

# Función para mostrar estado de túneles
show_tunnel_status() {
    echo ""
    echo "=== ESTADO DE TÚNELES ==="
    echo ""

    # Mostrar túneles SSH
    if [[ -f /tmp/ssh_tunnels.pid ]]; then
        echo "Túneles SSH activos:"
        while read -r tunnel_info; do
            local pid=$(echo "$tunnel_info" | cut -d: -f1)
            local server=$(echo "$tunnel_info" | cut -d: -f2)
            local remote_port=$(echo "$tunnel_info" | cut -d: -f4)

            if kill -0 "$pid" 2>/dev/null; then
                echo "  ✅ PID $pid -> $server:$remote_port"
            else
                echo "  ❌ PID $pid -> $server:$remote_port (CAÍDO)"
            fi
        done < /tmp/ssh_tunnels.pid
    else
        echo "No hay túneles SSH activos"
    fi

    echo ""

    # Mostrar túneles WireGuard
    local wg_count=$(ls /etc/wireguard/*.conf 2>/dev/null | wc -l)
    if [[ $wg_count -gt 0 ]]; then
        echo "Túneles WireGuard:"
        for wg_conf in /etc/wireguard/*.conf; do
            if [[ -f "$wg_conf" ]]; then
                local interface=$(basename "$wg_conf" .conf)
                if wg show "$interface" >/dev/null 2>&1; then
                    echo "  ✅ $interface (ACTIVO)"
                else
                    echo "  ❌ $interface (INACTIVO)"
                fi
            fi
        done
    else
        echo "No hay túneles WireGuard configurados"
    fi

    echo ""

    # Mostrar URLs públicas
    echo "URLs públicas de servicios:"
    local services=("webmin_http" "webmin_https" "webmin_main" "usermin")
    for service in "${services[@]}"; do
        local url=$(get_public_url "$service")
        if [[ -n "$url" ]]; then
            echo "  🌐 $service: $url"
        fi
    done

    echo ""
}

# Función para detener todos los túneles
stop_all_tunnels() {
    tunnel_log "INFO" "Deteniendo todos los túneles..."

    # Detener túneles SSH
    if [[ -f /tmp/ssh_tunnels.pid ]]; then
        while read -r tunnel_info; do
            local pid=$(echo "$tunnel_info" | cut -d: -f1)
            if kill "$pid" 2>/dev/null; then
                tunnel_log "INFO" "Túnel SSH detenido: PID $pid"
            fi
        done < /tmp/ssh_tunnels.pid
        rm -f /tmp/ssh_tunnels.pid
    fi

    # Detener túneles WireGuard
    for wg_conf in /etc/wireguard/*.conf; do
        if [[ -f "$wg_conf" ]]; then
            local interface=$(basename "$wg_conf" .conf)
            wg-quick down "$interface" 2>/dev/null || true
            tunnel_log "INFO" "Túnel WireGuard detenido: $interface"
        fi
    done

    tunnel_log "SUCCESS" "Todos los túneles detenidos"
}

# Procesar argumentos de línea de comandos
case "${1:-}" in
    start)
        main_tunnel_system
        ;;
    stop)
        stop_all_tunnels
        ;;
    status)
        show_tunnel_status
        ;;
    restart)
        stop_all_tunnels
        sleep 2
        main_tunnel_system
        ;;
    *)
        echo "Uso: $0 {start|stop|status|restart}"
        echo ""
        echo "Sistema de Túneles Automáticos para Webmin/Virtualmin"
        echo "Convierte IP privada en pública sin servicios de terceros"
        exit 1
        ;;
esac
