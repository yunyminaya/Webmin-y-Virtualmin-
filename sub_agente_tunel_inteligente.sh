#!/bin/bash

# Sub-Agente Túnel Inteligente
# Gestión automática de túneles para servidores sin IP pública

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/sub_agente_tunel_inteligente.log"
CONFIG_FILE="/etc/webmin/tunel_config.conf"
TUNNEL_STATUS_FILE="/var/lib/webmin/tunnel_status.json"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [TUNEL-INT] $1" | tee -a "$LOG_FILE"
}

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Configuración de Túneles Inteligentes
TUNNEL_ENABLED=true
TUNNEL_TYPE=cloudflare
TUNNEL_CHECK_INTERVAL=60
TUNNEL_RESTART_THRESHOLD=3
WEBMIN_PORT=10000
VIRTUALMIN_DOMAINS_CHECK=true
AUTO_INSTALL_ON_PRIVATE_IP=true
TUNNEL_REDUNDANCY=true
HEALTH_CHECK_URL="http://localhost:10000"
NOTIFICATION_WEBHOOK=""
EOF
    fi
    source "$CONFIG_FILE"
}

detect_network_setup() {
    log_message "=== DETECTANDO CONFIGURACIÓN DE RED ==="
    
    # Obtener IP pública
    local public_ip=""
    public_ip=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "")
    
    # Obtener IP local
    local local_ip=$(ip route get 8.8.8.8 | grep -oP 'src \K\S+' 2>/dev/null || echo "")
    
    # Verificar si tiene IP pública
    local has_public_ip=false
    if [ -n "$public_ip" ] && [ -n "$local_ip" ] && [ "$public_ip" = "$local_ip" ]; then
        has_public_ip=true
    fi
    
    log_message "IP Local: $local_ip"
    log_message "IP Pública detectada: $public_ip"
    log_message "Tiene IP pública directa: $has_public_ip"
    
    # Actualizar estado
    cat > "$TUNNEL_STATUS_FILE" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "local_ip": "$local_ip",
    "public_ip": "$public_ip",
    "has_public_ip": $has_public_ip,
    "tunnel_needed": $([ "$has_public_ip" = "false" ] && echo "true" || echo "false"),
    "tunnel_active": false,
    "last_check": "$(date -Iseconds)"
}
EOF
    
    if [ "$has_public_ip" = "false" ]; then
        log_message "⚠️  Servidor sin IP pública - Túnel requerido"
        return 1
    else
        log_message "✅ Servidor con IP pública - Túnel opcional"
        return 0
    fi
}

install_cloudflare_tunnel() {
    log_message "=== INSTALANDO CLOUDFLARE TUNNEL ==="
    
    # Verificar si cloudflared ya está instalado
    if ! command -v cloudflared &> /dev/null; then
        log_message "Instalando cloudflared..."
        
        # Descargar e instalar cloudflared
        if [ "$(uname -m)" = "x86_64" ]; then
            wget -O /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
        else
            wget -O /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
        fi
        
        dpkg -i /tmp/cloudflared.deb || apt-get install -f -y
        rm -f /tmp/cloudflared.deb
        
        log_message "✓ Cloudflared instalado"
    else
        log_message "✓ Cloudflared ya está disponible"
    fi
    
    # Crear directorio de configuración
    mkdir -p /etc/cloudflared
    
    # Configuración del túnel
    cat > /etc/cloudflared/config.yml << EOF
tunnel: webmin-virtualmin-$(hostname)
credentials-file: /etc/cloudflared/cert.pem

ingress:
  - hostname: webmin.$(hostname).tunnel.com
    service: http://localhost:${WEBMIN_PORT}
    originRequest:
      noTLSVerify: true
  - hostname: "*.$(hostname).tunnel.com"
    service: http://localhost:80
  - service: http_status:404

EOF
    
    log_message "✓ Configuración de túnel creada"
}

setup_ngrok_tunnel() {
    log_message "=== CONFIGURANDO TÚNEL NGROK ==="
    
    if ! command -v ngrok &> /dev/null; then
        log_message "Instalando ngrok..."
        
        # Descargar ngrok
        wget -O /tmp/ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip
        unzip /tmp/ngrok.zip -d /usr/local/bin/
        chmod +x /usr/local/bin/ngrok
        rm -f /tmp/ngrok.zip
        
        log_message "✓ Ngrok instalado"
    fi
    
    # Crear configuración ngrok
    mkdir -p ~/.ngrok2
    cat > ~/.ngrok2/ngrok.yml << EOF
version: "2"
authtoken: "YOUR_NGROK_TOKEN_HERE"
tunnels:
  webmin:
    addr: ${WEBMIN_PORT}
    proto: http
    bind_tls: true
  web:
    addr: 80
    proto: http
    bind_tls: true
  web-ssl:
    addr: 443
    proto: http
    bind_tls: true
EOF
    
    log_message "✓ Configuración ngrok creada"
}

create_tunnel_monitor() {
    log_message "=== CREANDO MONITOR DE TÚNELES ==="
    
    cat > "$SCRIPT_DIR/monitor_tunel.sh" << 'EOMT'
#!/bin/bash

# Monitor de Túneles - Verificación Continua

LOG_FILE="/var/log/monitor_tunel.log"
STATUS_FILE="/var/lib/webmin/tunnel_status.json"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [MONITOR-TUNEL] $1" | tee -a "$LOG_FILE"
}

check_tunnel_health() {
    local tunnel_active=false
    local tunnel_url=""
    
    # Verificar Cloudflare Tunnel
    if pgrep -f cloudflared >/dev/null; then
        log_message "✓ Cloudflare Tunnel activo"
        tunnel_active=true
        tunnel_url=$(cloudflared tunnel info 2>/dev/null | grep -o 'https://[^.]*\.trycloudflare\.com' | head -1 || echo "")
    fi
    
    # Verificar Ngrok
    if pgrep -f ngrok >/dev/null; then
        log_message "✓ Ngrok Tunnel activo"
        tunnel_active=true
        tunnel_url=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url' 2>/dev/null || echo "")
    fi
    
    # Actualizar estado
    cat > "$STATUS_FILE" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "tunnel_active": $tunnel_active,
    "tunnel_url": "$tunnel_url",
    "webmin_accessible": false,
    "last_health_check": "$(date -Iseconds)"
}
EOF
    
    # Verificar acceso a Webmin a través del túnel
    if [ "$tunnel_active" = "true" ] && [ -n "$tunnel_url" ]; then
        if curl -s -k -I "$tunnel_url" | grep -q "HTTP"; then
            log_message "✅ Webmin accesible a través del túnel: $tunnel_url"
            # Actualizar JSON con acceso exitoso
            sed -i 's/"webmin_accessible": false/"webmin_accessible": true/' "$STATUS_FILE"
        else
            log_message "❌ Webmin NO accesible a través del túnel"
        fi
    fi
    
    return $([[ "$tunnel_active" == "true" ]] && echo 0 || echo 1)
}

restart_tunnel() {
    log_message "Reiniciando túneles..."
    
    # Detener túneles existentes
    pkill -f cloudflared || true
    pkill -f ngrok || true
    
    sleep 5
    
    # Reiniciar según configuración
    if [ "$TUNNEL_TYPE" = "cloudflare" ]; then
        start_cloudflare_tunnel
    elif [ "$TUNNEL_TYPE" = "ngrok" ]; then
        start_ngrok_tunnel
    fi
}

start_cloudflare_tunnel() {
    log_message "Iniciando Cloudflare Tunnel..."
    
    # Verificar autenticación
    if [ ! -f "/etc/cloudflared/cert.pem" ]; then
        log_message "⚠️  Certificado Cloudflare no encontrado"
        log_message "Ejecute: cloudflared tunnel login"
        return 1
    fi
    
    # Iniciar túnel
    nohup cloudflared tunnel --config /etc/cloudflared/config.yml run >/var/log/cloudflared.log 2>&1 &
    
    sleep 10
    
    if pgrep -f cloudflared >/dev/null; then
        log_message "✅ Cloudflare Tunnel iniciado exitosamente"
        return 0
    else
        log_message "❌ Error al iniciar Cloudflare Tunnel"
        return 1
    fi
}

start_ngrok_tunnel() {
    log_message "Iniciando Ngrok Tunnel..."
    
    # Verificar token
    if ! grep -q "authtoken" ~/.ngrok2/ngrok.yml 2>/dev/null; then
        log_message "⚠️  Token Ngrok no configurado"
        log_message "Configure su token en ~/.ngrok2/ngrok.yml"
        return 1
    fi
    
    # Iniciar túneles
    nohup ngrok start webmin web >/var/log/ngrok.log 2>&1 &
    
    sleep 10
    
    if pgrep -f ngrok >/dev/null; then
        log_message "✅ Ngrok Tunnel iniciado exitosamente"
        return 0
    else
        log_message "❌ Error al iniciar Ngrok Tunnel"
        return 1
    fi
}

monitor_continuous() {
    log_message "=== INICIANDO MONITOREO CONTINUO ==="
    
    local failed_checks=0
    
    while true; do
        if check_tunnel_health; then
            failed_checks=0
            log_message "✅ Túnel funcionando correctamente"
        else
            ((failed_checks++))
            log_message "❌ Verificación de túnel falló ($failed_checks/${TUNNEL_RESTART_THRESHOLD})"
            
            if [ "$failed_checks" -ge "$TUNNEL_RESTART_THRESHOLD" ]; then
                log_message "🔄 Reiniciando túnel por fallos repetidos"
                restart_tunnel
                failed_checks=0
            fi
        fi
        
        sleep "$TUNNEL_CHECK_INTERVAL"
    done
}
EOMT

    chmod +x "$SCRIPT_DIR/monitor_tunel.sh"
    log_message "✓ Monitor de túneles creado"
}

auto_setup_tunnel() {
    log_message "=== CONFIGURACIÓN AUTOMÁTICA DE TÚNEL ==="
    
    # Detectar si necesita túnel
    if ! detect_network_setup; then
        log_message "Configurando túnel automáticamente..."
        
        # Instalar herramientas según preferencia
        case "$TUNNEL_TYPE" in
            cloudflare)
                install_cloudflare_tunnel
                ;;
            ngrok)
                setup_ngrok_tunnel
                ;;
            *)
                log_message "Instalando ambas opciones..."
                install_cloudflare_tunnel
                setup_ngrok_tunnel
                ;;
        esac
        
        create_tunnel_monitor
        
        # Crear servicio systemd para el monitor
        cat > /etc/systemd/system/tunnel-monitor.service << EOF
[Unit]
Description=Monitor de Túneles Webmin/Virtualmin
After=network.target

[Service]
Type=simple
User=root
ExecStart=$SCRIPT_DIR/sub_agente_tunel_inteligente.sh monitor
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable tunnel-monitor.service
        
        log_message "✓ Servicio de monitoreo de túneles instalado"
    else
        log_message "✅ Servidor con IP pública - Túnel no requerido"
    fi
}

test_domain_connectivity() {
    log_message "=== PROBANDO CONECTIVIDAD DE DOMINIOS ==="
    
    # Leer dominios de Virtualmin
    local domains_file="/etc/webmin/virtual-server/domains"
    local test_report="/var/log/test_dominios_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== PRUEBA DE CONECTIVIDAD DE DOMINIOS ==="
        echo "Fecha: $(date)"
        echo ""
        
        if [ -f "$domains_file" ]; then
            while read domain_line; do
                local domain=$(echo "$domain_line" | awk '{print $1}')
                if [ -n "$domain" ] && [[ "$domain" != "#"* ]]; then
                    echo "Probando dominio: $domain"
                    
                    # Test DNS
                    if nslookup "$domain" >/dev/null 2>&1; then
                        echo "  ✅ DNS resuelve"
                    else
                        echo "  ❌ DNS no resuelve"
                    fi
                    
                    # Test HTTP
                    if curl -s -I "http://$domain" | grep -q "HTTP"; then
                        echo "  ✅ HTTP responde"
                    else
                        echo "  ❌ HTTP no responde"
                    fi
                    
                    # Test HTTPS
                    if curl -s -k -I "https://$domain" | grep -q "HTTP"; then
                        echo "  ✅ HTTPS responde"
                    else
                        echo "  ⚠️  HTTPS no responde"
                    fi
                    
                    echo ""
                fi
            done < "$domains_file"
        else
            echo "No se encontró archivo de dominios Virtualmin"
        fi
        
    } > "$test_report"
    
    log_message "✓ Reporte de dominios: $test_report"
}

create_tunnel_failover() {
    log_message "=== CONFIGURANDO FAILOVER DE TÚNELES ==="
    
    cat > "$SCRIPT_DIR/tunnel_failover.sh" << 'EOF'
#!/bin/bash

# Sistema de Failover para Túneles

LOG_FILE="/var/log/tunnel_failover.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [FAILOVER] $1" | tee -a "$LOG_FILE"
}

check_primary_tunnel() {
    # Verificar Cloudflare primero
    if pgrep -f cloudflared >/dev/null; then
        local cf_url=$(grep -o 'https://[^.]*\.trycloudflare\.com' /var/log/cloudflared.log 2>/dev/null | tail -1)
        if [ -n "$cf_url" ] && curl -s -I "$cf_url" | grep -q "HTTP"; then
            log_message "✅ Cloudflare Tunnel operativo: $cf_url"
            return 0
        fi
    fi
    
    # Verificar Ngrok como respaldo
    if pgrep -f ngrok >/dev/null; then
        local ngrok_url=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url' 2>/dev/null)
        if [ -n "$ngrok_url" ] && curl -s -I "$ngrok_url" | grep -q "HTTP"; then
            log_message "✅ Ngrok Tunnel operativo: $ngrok_url"
            return 0
        fi
    fi
    
    return 1
}

activate_failover() {
    log_message "⚠️  Activando sistema de failover"
    
    # Detener túneles problemáticos
    pkill -f cloudflared || true
    pkill -f ngrok || true
    
    sleep 5
    
    # Iniciar Cloudflare como primario
    log_message "Iniciando Cloudflare Tunnel..."
    nohup cloudflared tunnel --url http://localhost:10000 >/var/log/cloudflared.log 2>&1 &
    
    sleep 15
    
    # Verificar si funcionó
    if check_primary_tunnel; then
        log_message "✅ Failover exitoso - Cloudflare activo"
        return 0
    fi
    
    # Si Cloudflare falla, usar ngrok
    log_message "Iniciando Ngrok como respaldo..."
    nohup ngrok http 10000 >/var/log/ngrok.log 2>&1 &
    
    sleep 10
    
    if check_primary_tunnel; then
        log_message "✅ Failover exitoso - Ngrok activo"
        return 0
    fi
    
    log_message "❌ Failover falló - No hay túneles disponibles"
    return 1
}

# Verificar y activar failover si es necesario
if ! check_primary_tunnel; then
    activate_failover
fi
EOF

    chmod +x "$SCRIPT_DIR/tunnel_failover.sh"
    log_message "✓ Sistema de failover creado"
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")" "/var/lib/webmin" 2>/dev/null || true
    log_message "=== INICIANDO SUB-AGENTE TÚNEL INTELIGENTE ==="
    
    load_config
    
    case "${1:-auto}" in
        auto)
            if ! detect_network_setup; then
                auto_setup_tunnel
            fi
            test_domain_connectivity
            ;;
        setup)
            auto_setup_tunnel
            ;;
        monitor)
            monitor_continuous
            ;;
        test)
            detect_network_setup
            test_domain_connectivity
            ;;
        failover)
            create_tunnel_failover
            "$SCRIPT_DIR/tunnel_failover.sh"
            ;;
        cloudflare)
            install_cloudflare_tunnel
            start_cloudflare_tunnel
            ;;
        ngrok)
            setup_ngrok_tunnel
            start_ngrok_tunnel
            ;;
        status)
            if [ -f "$TUNNEL_STATUS_FILE" ]; then
                cat "$TUNNEL_STATUS_FILE"
            else
                echo '{"error": "No hay estado disponible"}'
            fi
            ;;
        *)
            echo "Sub-Agente Túnel Inteligente - Webmin/Virtualmin"
            echo "Uso: $0 {auto|setup|monitor|test|failover|cloudflare|ngrok|status}"
            echo ""
            echo "Comandos:"
            echo "  auto      - Configuración automática según red"
            echo "  setup     - Configurar túneles manualmente"
            echo "  monitor   - Monitoreo continuo de túneles"
            echo "  test      - Probar conectividad de dominios"
            echo "  failover  - Configurar sistema de respaldo"
            echo "  cloudflare - Usar solo Cloudflare Tunnel"
            echo "  ngrok     - Usar solo Ngrok"
            echo "  status    - Estado actual de túneles"
            exit 1
            ;;
    esac
    
    log_message "Sub-agente túnel inteligente completado"
}

main "$@"
