#!/bin/bash

# Sub-Agente Túnel Nativo Automático SIN TERCEROS
# Túnel SSH nativo con IP pública automática y seguridad avanzada

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/sub_agente_tunel_nativo_automatico.log"
CONFIG_FILE="/etc/webmin/tunel_nativo_config.conf"
STATUS_FILE="/var/lib/webmin/tunel_nativo_status.json"
TUNNEL_KEY_FILE="/etc/ssh/tunnel_native_key"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [TUNEL-NATIVO] $1" | tee -a "$LOG_FILE"
}

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Configuración Túnel Nativo Automático
TUNNEL_ENABLED=true
TUNNEL_PORT=22
WEBMIN_PORT=10000
VIRTUAL_IP_RANGE="10.8.0.0/24"
TUNNEL_INTERFACE="tun0"
AUTO_CONFIGURE_ROUTING=true
PERSISTENT_TUNNEL=true
SECURITY_HARDENING=true
AUTO_FIREWALL_RULES=true
TUNNEL_KEEPALIVE=60
MAX_TUNNEL_ATTEMPTS=5
FALLBACK_ENABLED=true
HEALTH_CHECK_INTERVAL=30
EOF
    fi
    source "$CONFIG_FILE"
}

create_native_tunnel_server() {
    log_message "=== CONFIGURANDO SERVIDOR DE TÚNEL NATIVO ==="
    
    # Generar claves SSH específicas para túnel
    if [ ! -f "$TUNNEL_KEY_FILE" ]; then
        ssh-keygen -t ed25519 -f "$TUNNEL_KEY_FILE" -N "" -C "tunnel-native-$(hostname)"
        chmod 600 "$TUNNEL_KEY_FILE"
        chmod 644 "${TUNNEL_KEY_FILE}.pub"
        log_message "✓ Claves SSH del túnel generadas"
    fi
    
    # Configurar servidor SSH específico para túnel
    cat > /etc/ssh/sshd_config.d/tunnel-native.conf << EOF
# Configuración SSH para Túnel Nativo
Match User tunnel-native
    AllowTcpForwarding yes
    AllowStreamLocalForwarding yes
    PermitTunnel yes
    X11Forwarding no
    AllowAgentForwarding no
    PermitOpen localhost:${WEBMIN_PORT}
    PermitOpen localhost:80
    PermitOpen localhost:443
    PermitListen localhost:${WEBMIN_PORT}
    PermitListen localhost:80
    PermitListen localhost:443
    AuthorizedKeysFile /etc/ssh/tunnel_authorized_keys
    ForceCommand /bin/false
    ClientAliveInterval ${TUNNEL_KEEPALIVE}
    ClientAliveCountMax 3
EOF

    # Crear usuario específico para túnel
    if ! id "tunnel-native" &>/dev/null; then
        useradd -r -s /bin/false -d /var/empty tunnel-native
        log_message "✓ Usuario tunnel-native creado"
    fi
    
    # Configurar claves autorizadas
    mkdir -p /etc/ssh
    cat "${TUNNEL_KEY_FILE}.pub" > /etc/ssh/tunnel_authorized_keys
    chown root:root /etc/ssh/tunnel_authorized_keys
    chmod 644 /etc/ssh/tunnel_authorized_keys
    
    systemctl restart sshd
    log_message "✓ Servidor SSH de túnel configurado"
}

setup_network_tunnel() {
    log_message "=== CONFIGURANDO TÚNEL DE RED NATIVO ==="
    
    # Verificar soporte TUN/TAP
    if [ ! -e /dev/net/tun ]; then
        mkdir -p /dev/net
        mknod /dev/net/tun c 10 200
        chmod 666 /dev/net/tun
    fi
    
    # Configurar interfaz de túnel
    cat > /etc/systemd/network/tunnel-native.netdev << EOF
[NetDev]
Name=${TUNNEL_INTERFACE}
Kind=tun
Description=Túnel Nativo Webmin/Virtualmin

[Tun]
User=tunnel-native
Group=tunnel-native
EOF

    cat > /etc/systemd/network/tunnel-native.network << EOF
[Match]
Name=${TUNNEL_INTERFACE}

[Network]
Address=${VIRTUAL_IP_RANGE%/*}.1/24
IPForward=yes
IPMasquerade=yes
EOF

    systemctl enable systemd-networkd
    systemctl restart systemd-networkd
    
    log_message "✓ Interfaz de túnel configurada"
}

create_auto_port_forward() {
    log_message "=== CONFIGURANDO REENVÍO DE PUERTOS AUTOMÁTICO ==="
    
    cat > "$SCRIPT_DIR/auto_port_forward.sh" << 'EOAPF'
#!/bin/bash

# Reenvío de Puertos Automático Nativo

LOG_FILE="/var/log/auto_port_forward.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PORT-FORWARD] $1" | tee -a "$LOG_FILE"
}

setup_iptables_forwarding() {
    log_message "Configurando iptables para reenvío nativo"
    
    # Habilitar forwarding
    echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
    sysctl -p
    
    # Configurar NAT para túnel
    iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $(ip route | grep default | awk '{print $5}') -j MASQUERADE
    
    # Reenvío específico para Webmin
    iptables -t nat -A PREROUTING -p tcp --dport 10000 -j DNAT --to-destination 127.0.0.1:10000
    iptables -A FORWARD -p tcp --dport 10000 -d 127.0.0.1 -j ACCEPT
    
    # Reenvío para HTTP/HTTPS
    iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination 127.0.0.1:80
    iptables -t nat -A PREROUTING -p tcp --dport 443 -j DNAT --to-destination 127.0.0.1:443
    iptables -A FORWARD -p tcp -m multiport --dports 80,443 -d 127.0.0.1 -j ACCEPT
    
    # Guardar reglas
    iptables-save > /etc/iptables/rules.v4
    
    log_message "✓ Reenvío de puertos configurado"
}

create_socat_forwarding() {
    log_message "Configurando socat para reenvío nativo"
    
    # Instalar socat si no está disponible
    if ! command -v socat &> /dev/null; then
        apt-get update && apt-get install -y socat
    fi
    
    # Crear scripts de reenvío
    cat > /usr/local/bin/tunnel-forward-webmin << 'EOF'
#!/bin/bash
exec socat TCP-LISTEN:10000,fork,reuseaddr TCP:127.0.0.1:10000
EOF

    cat > /usr/local/bin/tunnel-forward-http << 'EOF'
#!/bin/bash
exec socat TCP-LISTEN:80,fork,reuseaddr TCP:127.0.0.1:80
EOF

    cat > /usr/local/bin/tunnel-forward-https << 'EOF'
#!/bin/bash
exec socat TCP-LISTEN:443,fork,reuseaddr TCP:127.0.0.1:443
EOF

    chmod +x /usr/local/bin/tunnel-forward-*
    
    # Crear servicios systemd
    for service in webmin http https; do
        cat > "/etc/systemd/system/tunnel-forward-${service}.service" << EOF
[Unit]
Description=Túnel Nativo Forward ${service}
After=network.target

[Service]
Type=simple
User=tunnel-native
ExecStart=/usr/local/bin/tunnel-forward-${service}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    done
    
    systemctl daemon-reload
    systemctl enable tunnel-forward-webmin tunnel-forward-http tunnel-forward-https
    
    log_message "✓ Servicios de reenvío socat configurados"
}

setup_iptables_forwarding
create_socat_forwarding
EOAPF

    chmod +x "$SCRIPT_DIR/auto_port_forward.sh"
    log_message "✓ Sistema de reenvío automático creado"
}

setup_reverse_proxy_native() {
    log_message "=== CONFIGURANDO PROXY REVERSO NATIVO ==="
    
    # Configurar Nginx como proxy reverso nativo
    cat > /etc/nginx/sites-available/tunnel-native-proxy << 'EOF'
# Proxy Reverso Nativo para Túnel
server {
    listen 80;
    listen [::]:80;
    server_name _;
    
    # Logs específicos del túnel
    access_log /var/log/nginx/tunnel_access.log;
    error_log /var/log/nginx/tunnel_error.log;
    
    # Headers de seguridad
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";
    
    # Proxy para Webmin
    location /webmin/ {
        proxy_pass https://127.0.0.1:10000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_ssl_verify off;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffers
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
    }
    
    # Proxy para aplicaciones web
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Rate limiting
        limit_req zone=general burst=20 nodelay;
        limit_conn addr 10;
    }
}

# HTTPS
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name _;
    
    # Certificado auto-generado
    ssl_certificate /etc/ssl/certs/tunnel-native.crt;
    ssl_certificate_key /etc/ssl/private/tunnel-native.key;
    
    # Configuración SSL segura
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;
    
    # HSTS
    add_header Strict-Transport-Security "max-age=63072000" always;
    
    # Proxy HTTPS para Webmin
    location /webmin/ {
        proxy_pass https://127.0.0.1:10000/;
        proxy_ssl_verify off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
    
    # Proxy HTTPS para aplicaciones
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
EOF

    # Generar certificado auto-firmado para túnel
    if [ ! -f "/etc/ssl/certs/tunnel-native.crt" ]; then
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/ssl/private/tunnel-native.key \
            -out /etc/ssl/certs/tunnel-native.crt \
            -subj "/C=ES/ST=State/L=City/O=TunnelNative/CN=$(hostname)"
        
        log_message "✓ Certificado SSL auto-generado"
    fi
    
    # Activar sitio
    ln -sf /etc/nginx/sites-available/tunnel-native-proxy /etc/nginx/sites-enabled/
    systemctl restart nginx
    
    log_message "✓ Proxy reverso nativo configurado"
}

create_dynamic_dns_native() {
    log_message "=== CONFIGURANDO DNS DINÁMICO NATIVO ==="
    
    cat > "$SCRIPT_DIR/dns_dinamico_nativo.sh" << 'EODNS'
#!/bin/bash

# DNS Dinámico Nativo - Sin servicios terceros

LOG_FILE="/var/log/dns_dinamico_nativo.log"
HOSTS_FILE="/etc/hosts"
DNS_CACHE_FILE="/var/cache/dns_nativo.cache"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DNS-NATIVO] $1" | tee -a "$LOG_FILE"
}

get_external_ip() {
    # Métodos nativos para obtener IP pública
    local public_ip=""
    
    # Método 1: Usar gateway router
    local gateway_ip=$(ip route | grep default | awk '{print $3}')
    if [ -n "$gateway_ip" ]; then
        # Intentar obtener IP pública del router
        public_ip=$(curl -s --connect-timeout 5 "http://$gateway_ip/status" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 2>/dev/null || echo "")
    fi
    
    # Método 2: Usar STUN servers (protocolo nativo)
    if [ -z "$public_ip" ] && command -v stun &> /dev/null; then
        public_ip=$(stun stun.l.google.com:19302 | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 2>/dev/null || echo "")
    fi
    
    # Método 3: DNS TXT query (método nativo)
    if [ -z "$public_ip" ] && command -v dig &> /dev/null; then
        public_ip=$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null || echo "")
    fi
    
    # Método 4: UPnP (protocolo nativo)
    if [ -z "$public_ip" ] && command -v upnpc &> /dev/null; then
        public_ip=$(upnpc -s | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 2>/dev/null || echo "")
    fi
    
    echo "$public_ip"
}

setup_local_dns_server() {
    log_message "Configurando servidor DNS local"
    
    # Instalar dnsmasq como DNS local
    if ! command -v dnsmasq &> /dev/null; then
        apt-get update && apt-get install -y dnsmasq
    fi
    
    # Configurar dnsmasq
    cat > /etc/dnsmasq.d/tunnel-native.conf << EOF
# DNS Local para Túnel Nativo
listen-address=127.0.0.1,10.8.0.1
bind-interfaces
domain-needed
bogus-priv
no-resolv
server=8.8.8.8
server=1.1.1.1
cache-size=1000
local-ttl=300

# Dominios locales
address=/webmin.local/127.0.0.1
address=/virtualmin.local/127.0.0.1
address=/panel.local/127.0.0.1
EOF

    systemctl restart dnsmasq
    systemctl enable dnsmasq
    
    log_message "✓ Servidor DNS local configurado"
}

update_hosts_dynamic() {
    local public_ip="$1"
    
    if [ -n "$public_ip" ]; then
        # Backup hosts file
        cp "$HOSTS_FILE" "${HOSTS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Eliminar entradas anteriores del túnel
        sed -i '/# TUNNEL-NATIVE-START/,/# TUNNEL-NATIVE-END/d' "$HOSTS_FILE"
        
        # Agregar nuevas entradas
        cat >> "$HOSTS_FILE" << EOF

# TUNNEL-NATIVE-START
$public_ip webmin.$(hostname).local
$public_ip virtualmin.$(hostname).local
$public_ip panel.$(hostname).local
127.0.0.1 webmin.local
127.0.0.1 virtualmin.local
127.0.0.1 panel.local
# TUNNEL-NATIVE-END
EOF
        
        log_message "✓ Archivo hosts actualizado con IP: $public_ip"
    fi
}

# Ejecutar actualización
public_ip=$(get_external_ip)
update_hosts_dynamic "$public_ip"
setup_local_dns_server
EODNS

    chmod +x "$SCRIPT_DIR/dns_dinamico_nativo.sh"
    log_message "✓ DNS dinámico nativo creado"
}

setup_tunnel_security() {
    log_message "=== CONFIGURANDO SEGURIDAD DEL TÚNEL NATIVO ==="
    
    # Crear firewall específico para túnel
    cat > /etc/iptables/tunnel-native-security.rules << 'EOF'
#!/bin/bash

# Seguridad Avanzada para Túnel Nativo

# Limpiar reglas del túnel
iptables -t filter -D INPUT -i tun0 -j ACCEPT 2>/dev/null || true
iptables -t filter -D FORWARD -i tun0 -j ACCEPT 2>/dev/null || true

# Permitir tráfico del túnel con restricciones
iptables -A INPUT -i tun0 -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -i tun0 -p tcp --dport 10000 -m limit --limit 10/minute --limit-burst 5 -j ACCEPT
iptables -A INPUT -i tun0 -p tcp -m multiport --dports 80,443 -m limit --limit 50/minute --limit-burst 20 -j ACCEPT

# Logging de conexiones del túnel
iptables -A INPUT -i tun0 -j LOG --log-prefix "TUNNEL-ACCESS: " --log-level 4

# Protección anti-scanning
iptables -A INPUT -i tun0 -p tcp --tcp-flags ALL NONE -j DROP
iptables -A INPUT -i tun0 -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
iptables -A INPUT -i tun0 -p tcp --tcp-flags SYN,RST SYN,RST -j DROP

# Rate limiting específico por IP
iptables -A INPUT -i tun0 -m recent --set --name TUNNEL_CLIENTS
iptables -A INPUT -i tun0 -m recent --update --seconds 60 --hitcount 100 --name TUNNEL_CLIENTS -j DROP

# Bloquear resto del tráfico del túnel
iptables -A INPUT -i tun0 -j DROP
EOF

    chmod +x /etc/iptables/tunnel-native-security.rules
    /etc/iptables/tunnel-native-security.rules
    
    log_message "✓ Seguridad del túnel configurada"
}

create_tunnel_health_monitor() {
    log_message "=== CREANDO MONITOR DE SALUD DEL TÚNEL ==="
    
    cat > "$SCRIPT_DIR/monitor_salud_tunel.sh" << 'EOMST'
#!/bin/bash

# Monitor de Salud Túnel Nativo

LOG_FILE="/var/log/monitor_salud_tunel.log"
STATUS_FILE="/var/lib/webmin/tunel_nativo_status.json"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [HEALTH-MONITOR] $1" | tee -a "$LOG_FILE"
}

check_tunnel_connectivity() {
    local tunnel_active=false
    local webmin_accessible=false
    local public_ip=""
    local tunnel_clients=0
    
    # Verificar interfaz túnel
    if ip link show tun0 >/dev/null 2>&1; then
        tunnel_active=true
        tunnel_clients=$(netstat -i | grep tun0 | awk '{print $3}' || echo "0")
    fi
    
    # Verificar acceso a Webmin
    if curl -s -k -I "https://127.0.0.1:10000" | grep -q "HTTP"; then
        webmin_accessible=true
    fi
    
    # Obtener IP pública actual
    public_ip=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || echo "unknown")
    
    # Actualizar estado
    cat > "$STATUS_FILE" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "tunnel_active": $tunnel_active,
    "webmin_accessible": $webmin_accessible,
    "public_ip": "$public_ip",
    "tunnel_clients": $tunnel_clients,
    "services": {
        "nginx_proxy": "$(systemctl is-active nginx 2>/dev/null || echo 'inactive')",
        "tunnel_forward_webmin": "$(systemctl is-active tunnel-forward-webmin 2>/dev/null || echo 'inactive')",
        "dns_local": "$(systemctl is-active dnsmasq 2>/dev/null || echo 'inactive')"
    },
    "security_status": {
        "firewall_active": "$(ufw status | grep -q 'Status: active' && echo 'true' || echo 'false')",
        "fail2ban_active": "$(systemctl is-active fail2ban 2>/dev/null | grep -q 'active' && echo 'true' || echo 'false')"
    }
}
EOF
    
    # Log del estado
    if [ "$tunnel_active" = "true" ] && [ "$webmin_accessible" = "true" ]; then
        log_message "✅ Túnel nativo completamente operativo"
        log_message "IP Pública: $public_ip | Clientes: $tunnel_clients"
        return 0
    else
        log_message "❌ Problemas en túnel nativo"
        return 1
    fi
}

repair_tunnel() {
    log_message "🔧 Reparando túnel nativo..."
    
    # Reiniciar servicios de túnel
    systemctl restart systemd-networkd
    systemctl restart tunnel-forward-webmin
    systemctl restart tunnel-forward-http
    systemctl restart tunnel-forward-https
    systemctl restart nginx
    
    # Reconfigurar iptables
    /etc/iptables/tunnel-native-security.rules
    
    # Verificar después de 30 segundos
    sleep 30
    
    if check_tunnel_connectivity; then
        log_message "✅ Túnel reparado exitosamente"
        return 0
    else
        log_message "❌ Reparación de túnel falló"
        return 1
    fi
}

# Monitor continuo
monitor_continuous() {
    local failed_checks=0
    local max_failures=3
    
    while true; do
        if check_tunnel_connectivity; then
            failed_checks=0
        else
            ((failed_checks++))
            log_message "⚠️  Verificación falló ($failed_checks/$max_failures)"
            
            if [ "$failed_checks" -ge "$max_failures" ]; then
                log_message "🔄 Iniciando reparación automática"
                repair_tunnel
                failed_checks=0
            fi
        fi
        
        sleep 30
    done
}

# Ejecutar según parámetro
case "${1:-check}" in
    check)
        check_tunnel_connectivity
        ;;
    monitor)
        monitor_continuous
        ;;
    repair)
        repair_tunnel
        ;;
    *)
        echo "Monitor de Salud Túnel Nativo"
        echo "Uso: $0 {check|monitor|repair}"
        ;;
esac
EOMST

    chmod +x "$SCRIPT_DIR/monitor_salud_tunel.sh"
    log_message "✓ Monitor de salud creado"
}

auto_configure_public_ip() {
    log_message "=== CONFIGURANDO IP PÚBLICA AUTOMÁTICA ==="
    
    # Detectar configuración de red actual
    local local_ip=$(ip route get 8.8.8.8 | grep -oP 'src \K\S+' 2>/dev/null)
    local gateway_ip=$(ip route | grep default | awk '{print $3}')
    local interface=$(ip route | grep default | awk '{print $5}')
    
    log_message "IP Local: $local_ip"
    log_message "Gateway: $gateway_ip"
    log_message "Interfaz: $interface"
    
    # Ejecutar DNS dinámico
    "$SCRIPT_DIR/dns_dinamico_nativo.sh"
    
    # Configurar reenvío automático
    "$SCRIPT_DIR/auto_port_forward.sh"
    
    # Iniciar monitor de salud
    "$SCRIPT_DIR/monitor_salud_tunel.sh" monitor &
    
    # Guardar PID del monitor
    echo $! > /var/run/tunnel_health_monitor.pid
    
    log_message "✓ IP pública automática configurada"
}

create_tunnel_persistence() {
    log_message "=== CONFIGURANDO PERSISTENCIA DEL TÚNEL ==="
    
    # Crear servicio principal del túnel nativo
    cat > /etc/systemd/system/tunnel-nativo.service << EOF
[Unit]
Description=Túnel Nativo Webmin/Virtualmin
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
User=root
ExecStart=$SCRIPT_DIR/sub_agente_tunel_nativo_automatico.sh start
ExecStop=$SCRIPT_DIR/sub_agente_tunel_nativo_automatico.sh stop
ExecReload=$SCRIPT_DIR/sub_agente_tunel_nativo_automatico.sh restart
Restart=always
RestartSec=10
PIDFile=/var/run/tunnel_nativo.pid

[Install]
WantedBy=multi-user.target
EOF

    # Crear servicio de monitoreo continuo
    cat > /etc/systemd/system/tunnel-nativo-monitor.service << EOF
[Unit]
Description=Monitor Túnel Nativo
After=tunnel-nativo.service
Requires=tunnel-nativo.service

[Service]
Type=simple
User=root
ExecStart=$SCRIPT_DIR/monitor_salud_tunel.sh monitor
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable tunnel-nativo.service tunnel-nativo-monitor.service
    
    log_message "✓ Servicios de persistencia creados"
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")" "/var/lib/webmin" "/var/cache" 2>/dev/null || true
    log_message "=== INICIANDO TÚNEL NATIVO AUTOMÁTICO ==="
    
    load_config
    
    case "${1:-auto}" in
        auto)
            create_native_tunnel_server
            setup_network_tunnel
            create_auto_port_forward
            setup_reverse_proxy_native
            create_dynamic_dns_native
            setup_tunnel_security
            create_tunnel_health_monitor
            auto_configure_public_ip
            create_tunnel_persistence
            ;;
        start)
            log_message "Iniciando túnel nativo..."
            systemctl start tunnel-nativo tunnel-nativo-monitor
            auto_configure_public_ip
            echo $$ > /var/run/tunnel_nativo.pid
            ;;
        stop)
            log_message "Deteniendo túnel nativo..."
            systemctl stop tunnel-nativo-monitor tunnel-nativo 2>/dev/null || true
            pkill -f "monitor_salud_tunel.sh" || true
            rm -f /var/run/tunnel_nativo.pid
            ;;
        restart)
            "$0" stop
            sleep 5
            "$0" start
            ;;
        status)
            if [ -f "$STATUS_FILE" ]; then
                jq '.' "$STATUS_FILE"
            else
                log_message "Estado no disponible"
            fi
            ;;
        test)
            "$SCRIPT_DIR/monitor_salud_tunel.sh" check
            ;;
        security)
            setup_tunnel_security
            ;;
        *)
            echo "Sub-Agente Túnel Nativo Automático"
            echo "Uso: $0 {auto|start|stop|restart|status|test|security}"
            echo ""
            echo "Comandos:"
            echo "  auto     - Configuración automática completa"
            echo "  start    - Iniciar túnel nativo"
            echo "  stop     - Detener túnel nativo"
            echo "  restart  - Reiniciar túnel nativo"
            echo "  status   - Estado del túnel"
            echo "  test     - Probar conectividad"
            echo "  security - Configurar seguridad"
            echo ""
            echo "🚀 Instalación rápida: $0 auto"
            exit 1
            ;;
    esac
    
    log_message "Túnel nativo automático completado"
}

main "$@"
