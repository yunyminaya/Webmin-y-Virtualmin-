#!/bin/bash
# Script para verificar y configurar túnel automático para IPs no públicas
# Permite exposición automática de servicios Webmin/Virtualmin sin IP pública

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Función de logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar tipo de IP
verificar_tipo_ip() {
    log "Verificando tipo de IP pública..."
    local ip_publica=$(curl -s --max-time 5 ifconfig.me || echo "")
    local ip_local=$(hostname -I | awk '{print $1}')
    if [[ -z "$ip_publica" ]]; then
        log_error "No se pudo obtener IP pública - posiblemente detrás de NAT"
        return 1
    fi
    if [[ $ip_publica =~ ^10\. ]] || [[ $ip_publica =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || [[ $ip_publica =~ ^192\.168\. ]] || [[ $ip_publica =~ ^127\. ]]; then
        log_warning "IP detectada es privada: $ip_publica - Necesario túnel NAT"
        return 1
    else
        log "IP pública válida detectada: $ip_publica"
        return 0
    fi
}

# Verificar servicios de túnel disponibles
verificar_servicios_tunnel() {
    log "Verificando servicios de túnel disponibles..."
    local servicios_disponibles=()
    if command -v cloudflared >/dev/null 2>&1; then
        servicios_disponibles+=("cloudflare")
        log "✅ Cloudflare Tunnel disponible"
    else
        log_warning "❌ Cloudflare Tunnel no instalado"
    fi
    if command -v ngrok >/dev/null 2>&1; then
        servicios_disponibles+=("ngrok")
        log "✅ ngrok disponible"
    else
        log_warning "❌ ngrok no instalado"
    fi
    if command -v lt >/dev/null 2>&1; then
        servicios_disponibles+=("localtunnel")
        log "✅ localtunnel disponible"
    else
        log_warning "❌ localtunnel no instalado"
    fi
    if command -v upnpc >/dev/null 2>&1; then
        servicios_disponibles+=("upnp")
        log "✅ UPnP disponible"
    else
        log_warning "❌ UPnP no instalado"
    fi
    echo "${servicios_disponibles[@]}"
}

# Instalar Cloudflare Tunnel
instalar_cloudflare_tunnel() {
    log "Instalando Cloudflare Tunnel..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared
        chmod +x /usr/local/bin/cloudflared
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install cloudflared || {
            curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-amd64.tgz | tar xz -C /usr/local/bin/
            chmod +x /usr/local/bin/cloudflared
        }
    fi
    log "✅ Cloudflare Tunnel instalado"
}

# Configurar túnel automático con Cloudflare
configurar_tunnel_cloudflare() {
    log "Configurando túnel automático con Cloudflare..."
    local dominio="${1:-webmin-tunnel.local}"
    mkdir -p /etc/cloudflared
    cat > /etc/cloudflared/config.yml << EOF
tunnel: webmin-tunnel
credentials-file: /etc/cloudflared/webmin-tunnel.json
ingress:
  - hostname: ${dominio}
    service: https://localhost:10000
  - hostname: mail.${dominio}
    service: https://localhost:20000
  - service: http_status:404
EOF
    cat > /etc/systemd/system/cloudflared-webmin.service << EOF
[Unit]
Description=Cloudflare Tunnel for Webmin
After=network.target
[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/cloudflared tunnel --config /etc/cloudflared/config.yml run
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable cloudflared-webmin
    log "✅ Túnel Cloudflare configurado"
}

# Configurar túnel con ngrok
configurar_tunnel_ngrok() {
    log "Configurando túnel automático con ngrok..."
    mkdir -p ~/.ngrok2
    cat > ~/.ngrok2/ngrok.yml << EOF
authtoken: ${NGROK_AUTH_TOKEN:-your_token_here}
tunnels:
  webmin:
    addr: 10000
    proto: http
    bind_tls: true
  usermin:
    addr: 20000
    proto: http
    bind_tls: true
EOF
    cat > /etc/systemd/system/ngrok-webmin.service << EOF
[Unit]
Description=ngrok tunnel for Webmin
After=network.target
[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/ngrok start --all --config=/root/.ngrok2/ngrok.yml
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable ngrok-webmin
    log "✅ Túnel ngrok configurado"
}

# Configurar UPnP para port forwarding automático
configurar_upnp() {
    log "Configurando UPnP para port forwarding automático..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y miniupnpc
    elif command -v yum >/dev/null 2>&1; then
        yum install -y miniupnpc
    elif command -v brew >/dev/null 2>&1; then
        brew install miniupnpc
    fi
    cat > /usr/local/bin/upnp-port-forward.sh << 'EOF'
#!/bin/bash
PORTS=(10000 20000 80 443 22)
for port in "${PORTS[@]}"; do
    upnpc -a $(hostname -I | awk '{print $1}') $port $port TCP >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ Puerto $port abierto vía UPnP"
    else
        echo "⚠️  No se pudo abrir puerto $port vía UPnP"
    fi
done
EOF
    chmod +x /usr/local/bin/upnp-port-forward.sh
    echo "@reboot root /usr/local/bin/upnp-port-forward.sh" >> /etc/crontab
    log "✅ UPnP configurado para port forwarding automático"
}

# Verificar configuración actual de NAT
verificar_config_nat() {
    log "Verificando configuración actual de NAT..."
    local ip_local=$(hostname -I | awk '{print $1}')
    local ip_publica=$(curl -s --max-time 5 ifconfig.me || echo "")
    if [[ "$ip_local" != "$ip_publica" ]] && [[ -n "$ip_publica" ]]; then
        log_warning "Detectado NAT: IP Local ($ip_local) ≠ IP Pública ($ip_publica)"
        if timeout 5 nc -z $ip_publica 10000 2>/dev/null; then
            log "✅ Puerto 10000 accesible desde internet"
        else
            log_warning "❌ Puerto 10000 no accesible - necesario túnel/port forwarding"
            return 1
        fi
    else
        log "✅ Sin NAT detectado o IP pública directa"
    fi
    return 0
}

# Crear script de detección y configuración automática
crear_script_automatico() {
    log "Creando script de detección y configuración automática..."
    cat > /usr/local/bin/auto-tunnel-manager.sh << 'EOF'
#!/bin/bash
LOG_FILE="/var/log/auto-tunnel.log"
CONFIG_FILE="/etc/auto-tunnel.conf"
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}
verificar_necesidad_tunnel() {
    local ip_publica=$(curl -s --max-time 5 ifconfig.me || echo "")
    local ip_local=$(hostname -I | awk '{print $1}')
    if [[ "$ip_publica" == "$ip_local" ]] || [[ -z "$ip_publica" ]]; then
        log "IP pública detectada o no disponible - no se necesita túnel"
        return 1
    fi
    if timeout 5 nc -z $ip_publica 10000 2>/dev/null; then
        log "Puertos accesibles - no se necesita túnel"
        return 1
    fi
    log "Necesario túnel - NAT detectado"
    return 0
}
iniciar_tunnel() {
    log "Iniciando configuración de túnel automático..."
    if command -v cloudflared >/dev/null 2>&1; then
        log "Usando Cloudflare Tunnel..."
        systemctl start cloudflared-webmin
        return 0
    fi
    if command -v ngrok >/dev/null 2>&1 && [[ -n "$NGROK_AUTH_TOKEN" ]]; then
        log "Usando ngrok..."
        systemctl start ngrok-webmin
        return 0
    fi
    if command -v upnpc >/dev/null 2>&1; then
        log "Usando UPnP..."
        /usr/local/bin/upnp-port-forward.sh
        return 0
    fi
    log "Ningún servicio de túnel disponible"
    return 1
}
monitorear_tunnel() {
    while true; do
        if verificar_necesidad_tunnel; then
            iniciar_tunnel
        fi
        sleep 300
    done
}
case "${1:-monitor}" in
    "check")
        verificar_necesidad_tunnel
        ;;
    "start")
        iniciar_tunnel
        ;;
    "monitor")
        monitorear_tunnel
        ;;
    *)
        echo "Uso: $0 [check|start|monitor]"
        ;;
esac
EOF
    chmod +x /usr/local/bin/auto-tunnel-manager.sh
    cat > /etc/systemd/system/auto-tunnel-manager.service << EOF
[Unit]
Description=Auto Tunnel Manager for Webmin/Virtualmin
After=network.target
[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/auto-tunnel-manager.sh monitor
Restart=always
RestartSec=30
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable auto-tunnel-manager
    log "✅ Script automático creado en /usr/local/bin/auto-tunnel-manager.sh"
}

# Función principal
main() {
    log "🚀 Iniciando verificación de túnel automático para IPs no públicas"
    verificar_tipo_ip
    local tipo_ip=$?
    if [[ $tipo_ip -eq 0 ]]; then
        log "✅ IP pública detectada - no se necesita túnel"
        exit 0
    fi
    servicios=$(verificar_servicios_tunnel)
    if [[ -z "$servicios" ]]; then
        log_warning "No hay servicios de túnel disponibles - instalando Cloudflare Tunnel..."
        instalar_cloudflare_tunnel
        configurar_tunnel_cloudflare
    fi
    for servicio in $servicios; do
        case $servicio in
            "cloudflare")
                configurar_tunnel_cloudflare
                break
                ;;
            "ngrok")
                configurar_tunnel_ngrok
                break
                ;;
            "upnp")
                configurar_upnp
                break
                ;;
        esac
    done
    crear_script_automatico
    verificar_config_nat
    log "🎉 Configuración de túnel automático completada"
    echo
    echo "=== RESUMEN DE CONFIGURACIÓN ==="
    echo "🔍 Script de detección: /usr/local/bin/auto-tunnel-manager.sh"
    echo "🔄 Servicio automático: systemctl start auto-tunnel-manager"
    echo "📊 Logs: tail -f /var/log/auto-tunnel.log"
    echo
    echo "Comandos útiles:"
    echo "  auto-tunnel-manager.sh check    # Verificar necesidad"
    echo "  auto-tunnel-manager.sh start    # Iniciar túnel"
    echo "  auto-tunnel-manager.sh monitor  # Monitorear continuamente"
    echo
}

# Ejecutar función principal
main "$@"
