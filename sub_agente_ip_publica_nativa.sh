#!/bin/bash

# Sub-Agente IP Pública Nativa SIN TERCEROS
# Configuración automática de IP pública usando métodos nativos

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/sub_agente_ip_publica_nativa.log"
CONFIG_FILE="/etc/webmin/ip_publica_nativa_config.conf"
STATUS_FILE="/var/lib/webmin/ip_publica_nativa_status.json"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [IP-PUBLICA-NATIVA] $1" | tee -a "$LOG_FILE"
}

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Configuración IP Pública Nativa
UPNP_ENABLED=true
STUN_ENABLED=true
NATIVE_ROUTING=true
AUTO_CONFIGURE_ROUTER=true
WEBMIN_PORT=10000
HTTP_PORT=80
HTTPS_PORT=443
PERSISTENT_MAPPING=true
SECURITY_HARDENING=true
DYNAMIC_DNS_LOCAL=true

EOF
    fi
    source "$CONFIG_FILE"
}

detect_router_capabilities() {
    log_message "=== DETECTANDO CAPACIDADES DEL ROUTER ==="
    
    local gateway_ip=$(ip route | grep default | awk '{print $3}')
    local router_brand="unknown"
    local upnp_available=false
    local admin_access=false
    
    log_message "Gateway detectado: $gateway_ip"
    
    # Detectar marca del router
    local router_response=$(curl -s --connect-timeout 5 "http://$gateway_ip" 2>/dev/null || echo "")
    
    if echo "$router_response" | grep -qi "dd-wrt"; then
        router_brand="dd-wrt"
    elif echo "$router_response" | grep -qi "openwrt"; then
        router_brand="openwrt"
    elif echo "$router_response" | grep -qi "mikrotik"; then
        router_brand="mikrotik"
    elif echo "$router_response" | grep -qi "tp-link"; then
        router_brand="tp-link"
    elif echo "$router_response" | grep -qi "asus"; then
        router_brand="asus"
    elif echo "$router_response" | grep -qi "netgear"; then
        router_brand="netgear"
    fi
    
    # Verificar UPnP
    if command -v upnpc &> /dev/null; then
        if upnpc -s >/dev/null 2>&1; then
            upnp_available=true
        fi
    fi
    
    log_message "Router: $router_brand | UPnP: $upnp_available"
    
    echo "$gateway_ip|$router_brand|$upnp_available"
}

setup_upnp_native() {
    log_message "=== CONFIGURANDO UPNP NATIVO ==="
    
    # Instalar herramientas UPnP si no están disponibles
    if ! command -v upnpc &> /dev/null; then
        apt-get update && apt-get install -y miniupnpc
    fi
    
    # Configurar mapeos UPnP automáticos
    cat > "$SCRIPT_DIR/configure_upnp.sh" << 'EOF'
#!/bin/bash

# Configuración UPnP Nativa

LOG_FILE="/var/log/configure_upnp.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [UPNP-CONFIG] $1" | tee -a "$LOG_FILE"
}

add_upnp_mapping() {
    local internal_port="$1"
    local external_port="$2"
    local protocol="${3:-TCP}"
    local description="$4"
    
    log_message "Configurando UPnP: $external_port -> $internal_port ($protocol)"
    
    # Eliminar mapping existente si existe
    upnpc -d "$external_port" "$protocol" 2>/dev/null || true
    
    # Agregar nuevo mapping
    if upnpc -a "$(hostname -I | awk '{print $1}')" "$internal_port" "$external_port" "$protocol" "$description" >/dev/null 2>&1; then
        log_message "✅ UPnP mapping creado: $external_port -> $internal_port"
        return 0
    else
        log_message "❌ Error al crear UPnP mapping: $external_port -> $internal_port"
        return 1
    fi
}

configure_all_mappings() {
    log_message "Configurando todos los mapeos UPnP..."
    
    # Mapeos principales
    add_upnp_mapping 10000 10000 TCP "Webmin-Admin-Panel"
    add_upnp_mapping 80 80 TCP "HTTP-Web-Server"
    add_upnp_mapping 443 443 TCP "HTTPS-Web-Server"
    add_upnp_mapping 22 22 TCP "SSH-Access"
    add_upnp_mapping 25 25 TCP "SMTP-Mail"
    add_upnp_mapping 993 993 TCP "IMAPS-Mail"
    add_upnp_mapping 995 995 TCP "POP3S-Mail"
    
    # Verificar mapeos
    log_message "Verificando mapeos UPnP..."
    upnpc -l | grep -E "(10000|80|443)" && log_message "✅ Mapeos principales confirmados"
}

# Ejecutar configuración
configure_all_mappings
EOF

    chmod +x "$SCRIPT_DIR/configure_upnp.sh"
    log_message "✓ Configuración UPnP nativa creada"
}

setup_stun_discovery() {
    log_message "=== CONFIGURANDO STUN PARA DESCUBRIMIENTO IP ==="
    
    # Instalar herramientas STUN nativas
    if ! command -v stunclient &> /dev/null; then
        apt-get update && apt-get install -y stun-client
    fi
    
    cat > "$SCRIPT_DIR/stun_discovery.sh" << 'EOSD'
#!/bin/bash

# Descubrimiento IP usando STUN (protocolo nativo)

LOG_FILE="/var/log/stun_discovery.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [STUN-DISCOVERY] $1" | tee -a "$LOG_FILE"
}

get_public_ip_stun() {
    local stun_servers=(
        "stun.l.google.com:19302"
        "stun1.l.google.com:19302"
        "stun2.l.google.com:19302"
        "stun.cloudflare.com:3478"
        "stun.nextcloud.com:443"
    )
    
    for stun_server in "${stun_servers[@]}"; do
        log_message "Probando servidor STUN: $stun_server"
        
        if command -v stunclient &> /dev/null; then
            local result=$(stunclient "$stun_server" 2>/dev/null | grep "Mapped Address" | awk '{print $3}' | cut -d: -f1)
            if [[ "$result" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                log_message "✅ IP pública obtenida via STUN: $result"
                echo "$result"
                return 0
            fi
        fi
        
        # Método alternativo con netcat
        if command -v nc &> /dev/null; then
            local stun_host=$(echo "$stun_server" | cut -d: -f1)
            local stun_port=$(echo "$stun_server" | cut -d: -f2)
            
            # STUN binding request simple
            local result=$(timeout 5 nc -u "$stun_host" "$stun_port" < /dev/null 2>/dev/null | hexdump -C | grep -oE '([0-9a-f]{2} ){4}' | head -1 | tr -d ' ' | fold -w2 | paste -sd. | sed 's/\.\([0-9a-f]\{2\}\)/.\1/g' 2>/dev/null || echo "")
            
            if [[ "$result" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                log_message "✅ IP pública obtenida via STUN (netcat): $result"
                echo "$result"
                return 0
            fi
        fi
    done
    
    log_message "❌ No se pudo obtener IP pública via STUN"
    return 1
}

configure_nat_traversal() {
    log_message "Configurando NAT traversal nativo"
    
    # Configurar keep-alive para mantener mappings NAT
    cat > /etc/systemd/system/nat-keepalive.service << 'EOF'
[Unit]
Description=NAT Keep-Alive Nativo
After=network.target

[Service]
Type=simple
User=root
ExecStart=/bin/bash -c 'while true; do for port in 10000 80 443; do nc -z 8.8.8.8 53 >/dev/null 2>&1; done; sleep 30; done'
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target


    systemctl daemon-reload
    systemctl enable nat-keepalive.service
    systemctl start nat-keepalive.service
    
    log_message "✓ NAT keep-alive configurado"
}

# Ejecutar STUN discovery
public_ip=$(get_public_ip_stun)
configure_nat_traversal
EOSD

    chmod +x "$SCRIPT_DIR/stun_discovery.sh"
    log_message "✓ STUN discovery configurado"
}

create_native_dns_server() {
    log_message "=== CONFIGURANDO SERVIDOR DNS NATIVO ==="
    
    # Configurar bind9 como DNS autoritativo local
    if ! command -v named &> /dev/null; then
        apt-get update && apt-get install -y bind9 bind9utils
    fi
    
    # Configuración DNS nativa
    cat > /etc/bind/named.conf.local << EOF
// Configuración DNS Nativa para Túnel

zone "$(hostname).local" {
    type master;
    file "/etc/bind/db.$(hostname).local";
    allow-update { none; };
};

zone "webmin.local" {
    type master;
    file "/etc/bind/db.webmin.local";
    allow-update { none; };
};
EOF

    # Crear zona DNS para hostname
    cat > "/etc/bind/db.$(hostname).local" << EOF
\$TTL    604800
@       IN      SOA     $(hostname).local. root.$(hostname).local. (
                     $(date +%Y%m%d%H) ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      $(hostname).local.
@       IN      A       127.0.0.1
webmin  IN      A       127.0.0.1
panel   IN      A       127.0.0.1
www     IN      A       127.0.0.1
EOF

    # Crear zona DNS para webmin
    cat > /etc/bind/db.webmin.local << EOF
\$TTL    604800
@       IN      SOA     webmin.local. root.webmin.local. (
                     $(date +%Y%m%d%H) ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      webmin.local.
@       IN      A       127.0.0.1
EOF

    systemctl restart bind9
    systemctl enable bind9
    
    log_message "✓ Servidor DNS nativo configurado"
}

auto_configure_router() {
    log_message "=== CONFIGURACIÓN AUTOMÁTICA DEL ROUTER ==="
    
    local router_info=$(detect_router_capabilities)
    local gateway_ip=$(echo "$router_info" | cut -d'|' -f1)
    local router_brand=$(echo "$router_info" | cut -d'|' -f2)
    local upnp_available=$(echo "$router_info" | cut -d'|' -f3)
    
    if [ "$upnp_available" = "true" ]; then
        log_message "✅ UPnP disponible - Configurando automáticamente"
        "$SCRIPT_DIR/configure_upnp.sh"
    else
        log_message "⚠️  UPnP no disponible - Configurando métodos alternativos"
        
        # Método alternativo: SSH al router (si es posible)
        case "$router_brand" in
            "dd-wrt"|"openwrt")
                configure_openwrt_router "$gateway_ip"
                ;;
            "mikrotik")
                configure_mikrotik_router "$gateway_ip"
                ;;
            *)
                log_message "Router no reconocido - Usando métodos genéricos"
                configure_generic_router "$gateway_ip"
                ;;
        esac
    fi
}

configure_openwrt_router() {
    local router_ip="$1"
    log_message "Configurando router OpenWrt: $router_ip"
    
    # Script para configurar OpenWrt via SSH (si es posible)
    cat > "$SCRIPT_DIR/configure_openwrt.sh" << EOF
#!/bin/bash

# Configuración automática OpenWrt

ROUTER_IP="$router_ip"

# Configurar port forwarding via uci (OpenWrt)
configure_port_forwarding() {
    local internal_ip=\$(hostname -I | awk '{print \$1}')
    
    # Webmin
    uci add firewall redirect
    uci set firewall.@redirect[-1].name='Webmin'
    uci set firewall.@redirect[-1].src='wan'
    uci set firewall.@redirect[-1].src_dport='10000'
    uci set firewall.@redirect[-1].dest='lan'
    uci set firewall.@redirect[-1].dest_ip="\$internal_ip"
    uci set firewall.@redirect[-1].dest_port='10000'
    uci set firewall.@redirect[-1].proto='tcp'
    
    # HTTP
    uci add firewall redirect
    uci set firewall.@redirect[-1].name='HTTP'
    uci set firewall.@redirect[-1].src='wan'
    uci set firewall.@redirect[-1].src_dport='80'
    uci set firewall.@redirect[-1].dest='lan'
    uci set firewall.@redirect[-1].dest_ip="\$internal_ip"
    uci set firewall.@redirect[-1].dest_port='80'
    uci set firewall.@redirect[-1].proto='tcp'
    
    # HTTPS
    uci add firewall redirect
    uci set firewall.@redirect[-1].name='HTTPS'
    uci set firewall.@redirect[-1].src='wan'
    uci set firewall.@redirect[-1].src_dport='443'
    uci set firewall.@redirect[-1].dest='lan'
    uci set firewall.@redirect[-1].dest_ip="\$internal_ip"
    uci set firewall.@redirect[-1].dest_port='443'
    uci set firewall.@redirect[-1].proto='tcp'
    
    uci commit firewall
    /etc/init.d/firewall restart
}

# Intentar configuración (requiere acceso SSH al router)
if ssh -o ConnectTimeout=5 -o BatchMode=yes root@\$ROUTER_IP "uci show firewall" >/dev/null 2>&1; then
    ssh root@\$ROUTER_IP "\$(declare -f configure_port_forwarding); configure_port_forwarding"
    echo "✅ Router OpenWrt configurado automáticamente"
else
    echo "⚠️  No se puede acceder al router via SSH"
fi
EOF

    chmod +x "$SCRIPT_DIR/configure_openwrt.sh"
    "$SCRIPT_DIR/configure_openwrt.sh"
}

configure_generic_router() {
    local router_ip="$1"
    log_message "Configurando router genérico: $router_ip"
    
    # Intentar configuración via web scraping (método nativo)
    cat > "$SCRIPT_DIR/configure_generic_router.sh" << 'EOF'
#!/bin/bash

# Configuración Router Genérico

LOG_FILE="/var/log/configure_generic_router.log"
ROUTER_IP="$1"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ROUTER-CONFIG] $1" | tee -a "$LOG_FILE"
}

attempt_web_configuration() {
    local internal_ip=$(hostname -I | awk '{print $1}')
    
    log_message "Intentando configuración web del router..."
    
    # Común URLs de configuración
    local config_urls=(
        "http://$ROUTER_IP/cgi-bin/luci"
        "http://$ROUTER_IP/admin"
        "http://$ROUTER_IP/setup"
        "http://$ROUTER_IP/index.php"
        "http://$ROUTER_IP/"
    )
    
    for url in "${config_urls[@]}"; do
        log_message "Probando URL: $url"
        
        local response=$(curl -s --connect-timeout 5 "$url" 2>/dev/null || echo "")
        
        if echo "$response" | grep -qi "port.*forward\|virtual.*server\|nat"; then
            log_message "✅ Interfaz de configuración encontrada: $url"
            
            # Intentar configuración automática básica
            # (Este método varía según el router, aquí un ejemplo genérico)
            local session_id=$(echo "$response" | grep -o 'session[^"]*' | head -1)
            
            if [ -n "$session_id" ]; then
                # Intentar enviar configuración de port forwarding
                curl -s -X POST "$url" \
                    -d "action=add_portforward" \
                    -d "external_port=10000" \
                    -d "internal_ip=$internal_ip" \
                    -d "internal_port=10000" \
                    -d "protocol=tcp" \
                    -d "description=Webmin" \
                    2>/dev/null || true
                
                log_message "Configuración enviada al router"
            fi
            
            return 0
        fi
    done
    
    log_message "⚠️  No se encontró interfaz de configuración accesible"
    return 1
}

attempt_web_configuration "$ROUTER_IP"
EOF

    chmod +x "$SCRIPT_DIR/configure_generic_router.sh"
    "$SCRIPT_DIR/configure_generic_router.sh" "$router_ip"
}

create_ip_public_monitor() {
    log_message "=== CREANDO MONITOR DE IP PÚBLICA ==="
    
    cat > "$SCRIPT_DIR/monitor_ip_publica.sh" << 'EOMIP'
#!/bin/bash

# Monitor de IP Pública Nativa

LOG_FILE="/var/log/monitor_ip_publica.log"
STATUS_FILE="/var/lib/webmin/ip_publica_nativa_status.json"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [IP-MONITOR] $1" | tee -a "$LOG_FILE"
}

get_current_public_ip() {
    # Método 1: STUN
    if command -v stunclient &> /dev/null; then
        local stun_ip=$(stunclient stun.l.google.com:19302 2>/dev/null | grep "Mapped Address" | awk '{print $3}' | cut -d: -f1)
        if [[ "$stun_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$stun_ip"
            return 0
        fi
    fi
    
    # Método 2: UPnP discovery
    if command -v upnpc &> /dev/null; then
        local upnp_ip=$(upnpc -s 2>/dev/null | grep "ExternalIPAddress" | awk '{print $3}')
        if [[ "$upnp_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$upnp_ip"
            return 0
        fi
    fi
    
    # Método 3: Router gateway query
    local gateway_ip=$(ip route | grep default | awk '{print $3}')
    if [ -n "$gateway_ip" ]; then
        local router_ip=$(curl -s --connect-timeout 3 "http://$gateway_ip/status" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 || echo "")
        if [[ "$router_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$router_ip"
            return 0
        fi
    fi
    
    return 1
}

verify_port_accessibility() {
    local public_ip="$1"
    local accessible_ports=()
    local blocked_ports=()
    
    # Verificar puertos principales
    local ports=(10000 80 443)
    
    for port in "${ports[@]}"; do
        log_message "Verificando puerto $port en IP $public_ip"
        
        # Usar nmap si está disponible
        if command -v nmap &> /dev/null; then
            if nmap -p "$port" "$public_ip" 2>/dev/null | grep -q "open"; then
                accessible_ports+=("$port")
            else
                blocked_ports+=("$port")
            fi
        else
            # Método alternativo con netcat
            if timeout 5 nc -z "$public_ip" "$port" 2>/dev/null; then
                accessible_ports+=("$port")
            else
                blocked_ports+=("$port")
            fi
        fi
    done
    
    log_message "Puertos accesibles: ${accessible_ports[*]}"
    log_message "Puertos bloqueados: ${blocked_ports[*]}"
    
    # Actualizar estado
    cat > "$STATUS_FILE" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "public_ip": "$public_ip",
    "accessible_ports": [$(printf '"%s",' "${accessible_ports[@]}" | sed 's/,$//')],
    "blocked_ports": [$(printf '"%s",' "${blocked_ports[@]}" | sed 's/,$//')],
    "tunnel_method": "native",
    "upnp_status": "$(upnpc -s >/dev/null 2>&1 && echo 'available' || echo 'unavailable')",
    "last_check": "$(date -Iseconds)"
}
EOF
    
    return $([[ ${#accessible_ports[@]} -gt 0 ]] && echo 0 || echo 1)
}

monitor_continuous() {
    log_message "Iniciando monitoreo continuo de IP pública"
    
    local last_ip=""
    local check_count=0
    
    while true; do
        ((check_count++))
        
        local current_ip=$(get_current_public_ip)
        
        if [ -n "$current_ip" ] && [ "$current_ip" != "$last_ip" ]; then
            log_message "📍 IP pública actualizada: $last_ip -> $current_ip"
            
            # Verificar accesibilidad
            if verify_port_accessibility "$current_ip"; then
                log_message "✅ IP pública accesible: $current_ip"
                
                # Actualizar DNS local
                "$SCRIPT_DIR/dns_dinamico_nativo.sh" "$current_ip"
                
            else
                log_message "❌ IP pública no accesible: $current_ip"
                
                # Reconfigurar UPnP si está disponible
                if command -v upnpc &> /dev/null; then
                    log_message "🔄 Reconfigurando UPnP..."
                    "$SCRIPT_DIR/configure_upnp.sh"
                fi
            fi
            
            last_ip="$current_ip"
        fi
        
        # Log periódico cada 10 verificaciones
        if [ $((check_count % 10)) -eq 0 ]; then
            log_message "Verificación #$check_count - IP actual: ${current_ip:-no detectada}"
        fi
        
        sleep 60
    done
}

# Ejecutar según parámetro
case "${1:-check}" in
    check)
        current_ip=$(get_current_public_ip)
        verify_port_accessibility "$current_ip"
        ;;
    monitor)
        monitor_continuous
        ;;
    *)
        echo "Monitor IP Pública Nativa"
        echo "Uso: $0 {check|monitor}"
        ;;
esac
EOMIP

    chmod +x "$SCRIPT_DIR/monitor_ip_publica.sh"
    log_message "✓ Monitor de IP pública creado"
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")" "/var/lib/webmin" 2>/dev/null || true
    log_message "=== INICIANDO IP PÚBLICA NATIVA ==="
    
    load_config
    
    case "${1:-auto}" in
        auto)
            setup_upnp_native
            setup_stun_discovery
            create_native_dns_server
            auto_configure_router
            create_ip_public_monitor
            "$SCRIPT_DIR/monitor_ip_publica.sh" monitor &
            ;;
        upnp)
            setup_upnp_native
            "$SCRIPT_DIR/configure_upnp.sh"
            ;;
        stun)
            setup_stun_discovery
            "$SCRIPT_DIR/stun_discovery.sh"
            ;;
        dns)
            create_native_dns_server
            ;;
        router)
            auto_configure_router
            ;;
        monitor)
            "$SCRIPT_DIR/monitor_ip_publica.sh" monitor
            ;;
        test)
            "$SCRIPT_DIR/monitor_ip_publica.sh" check
            ;;
        status)
            if [ -f "$STATUS_FILE" ]; then
                jq '.' "$STATUS_FILE"
            else
                echo '{"error": "Estado no disponible"}'
            fi
            ;;
        *)
            echo "Sub-Agente IP Pública Nativa"
            echo "Uso: $0 {auto|upnp|stun|dns|router|monitor|test|status}"
            echo ""
            echo "Comandos:"
            echo "  auto    - Configuración automática completa"
            echo "  upnp    - Configurar solo UPnP"
            echo "  stun    - Configurar solo STUN"
            echo "  dns     - Configurar DNS nativo"
            echo "  router  - Configurar router automáticamente"
            echo "  monitor - Monitoreo continuo"
            echo "  test    - Probar IP pública actual"
            echo "  status  - Estado en JSON"
            exit 1
            ;;
    esac
    
    log_message "IP pública nativa completada"
}

main "$@"
