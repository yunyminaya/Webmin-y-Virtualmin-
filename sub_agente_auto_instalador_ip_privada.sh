#!/bin/bash

# Sub-Agente Auto-Instalador para IP Privada
# Instalación automática cuando el servidor no tiene IP pública

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/sub_agente_auto_instalador_ip_privada.log"
STATUS_FILE="/var/lib/webmin/ip_privada_status.json"
CONFIG_FILE="/etc/webmin/ip_privada_config.conf"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [AUTO-INSTALADOR] $1" | tee -a "$LOG_FILE"
}

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Configuración Auto-Instalador IP Privada
AUTO_INSTALL_ENABLED=true
TUNNEL_PRIORITY=cloudflare
BACKUP_TUNNEL=ngrok
WEBMIN_PORT=10000
SSL_AUTO_SETUP=true
DNS_UPDATE_ENABLED=false
NOTIFICATION_WEBHOOK=""
INSTALL_DEPENDENCIES=true
FIREWALL_AUTO_CONFIG=true
EOF
    fi
    source "$CONFIG_FILE"
}

detect_network_environment() {
    log_message "=== DETECTANDO ENTORNO DE RED ==="
    
    # Obtener información de red
    local local_ip=$(ip route get 8.8.8.8 | grep -oP 'src \K\S+' 2>/dev/null || echo "")
    local gateway_ip=$(ip route | grep default | awk '{print $3}' | head -1)
    local public_ip=""
    
    # Intentar obtener IP pública
    for service in "ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ident.me"; do
        public_ip=$(curl -s --connect-timeout 10 "$service" 2>/dev/null || echo "")
        if [ -n "$public_ip" ] && [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            break
        fi
    done
    
    # Determinar tipo de red
    local network_type="unknown"
    local needs_tunnel=false
    
    if [ -n "$local_ip" ] && [ -n "$public_ip" ]; then
        if [ "$local_ip" = "$public_ip" ]; then
            network_type="public_direct"
            needs_tunnel=false
        else
            network_type="private_with_nat"
            needs_tunnel=true
        fi
    elif [[ "$local_ip" =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.) ]]; then
        network_type="private_network"
        needs_tunnel=true
    elif [ -n "$local_ip" ]; then
        network_type="public_direct"
        needs_tunnel=false
    fi
    
    # Detectar proveedor de cloud
    local cloud_provider="unknown"
    if curl -s --connect-timeout 5 "http://169.254.169.254/latest/meta-data/" >/dev/null 2>&1; then
        cloud_provider="aws"
    elif curl -s --connect-timeout 5 "http://metadata.google.internal/computeMetadata/v1/" >/dev/null 2>&1; then
        cloud_provider="gcp"
    elif curl -s --connect-timeout 5 "http://169.254.169.254/metadata/instance" >/dev/null 2>&1; then
        cloud_provider="azure"
    elif curl -s --connect-timeout 5 "http://169.254.169.254/metadata/v1/" >/dev/null 2>&1; then
        cloud_provider="digitalocean"
    fi
    
    # Guardar estado
    cat > "$STATUS_FILE" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "local_ip": "$local_ip",
    "public_ip": "$public_ip",
    "gateway_ip": "$gateway_ip",
    "network_type": "$network_type",
    "needs_tunnel": $needs_tunnel,
    "cloud_provider": "$cloud_provider",
    "auto_install_triggered": false,
    "tunnel_installed": false
}
EOF
    
    log_message "Red detectada: $network_type (Cloud: $cloud_provider)"
    log_message "IP Local: $local_ip | IP Pública: $public_ip"
    log_message "Túnel requerido: $needs_tunnel"
    
    return $([[ "$needs_tunnel" == "true" ]] && echo 0 || echo 1)
}

install_tunnel_dependencies() {
    log_message "=== INSTALANDO DEPENDENCIAS DE TÚNEL ==="
    
    # Actualizar sistema
    apt-get update
    
    # Dependencias básicas
    apt-get install -y curl wget unzip jq bc net-tools
    
    # Instalar Cloudflared
    if [ "$TUNNEL_PRIORITY" = "cloudflare" ] || [ "$BACKUP_TUNNEL" = "cloudflare" ]; then
        log_message "Instalando Cloudflared..."
        
        local arch=$(uname -m)
        case "$arch" in
            x86_64)
                wget -O /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
                ;;
            aarch64|arm64)
                wget -O /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
                ;;
            *)
                log_message "❌ Arquitectura no soportada para Cloudflared: $arch"
                return 1
                ;;
        esac
        
        dpkg -i /tmp/cloudflared.deb || apt-get install -f -y
        rm -f /tmp/cloudflared.deb
        
        log_message "✓ Cloudflared instalado"
    fi
    
    # Instalar Ngrok
    if [ "$TUNNEL_PRIORITY" = "ngrok" ] || [ "$BACKUP_TUNNEL" = "ngrok" ]; then
        log_message "Instalando Ngrok..."
        
        wget -O /tmp/ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip
        unzip /tmp/ngrok.zip -d /usr/local/bin/
        chmod +x /usr/local/bin/ngrok
        rm -f /tmp/ngrok.zip
        
        log_message "✓ Ngrok instalado"
    fi
    
    # Instalar herramientas adicionales
    apt-get install -y screen tmux supervisor
    
    log_message "✓ Todas las dependencias instaladas"
}

auto_configure_tunnel() {
    log_message "=== CONFIGURACIÓN AUTOMÁTICA DE TÚNEL ==="
    
    # Crear directorio de configuración
    mkdir -p /etc/tunnels
    
    # Configurar túnel principal
    case "$TUNNEL_PRIORITY" in
        cloudflare)
            setup_cloudflare_auto
            ;;
        ngrok)
            setup_ngrok_auto
            ;;
    esac
    
    # Configurar túnel de respaldo
    case "$BACKUP_TUNNEL" in
        cloudflare)
            setup_cloudflare_backup
            ;;
        ngrok)
            setup_ngrok_backup
            ;;
    esac
    
    # Crear script de inicio automático
    create_tunnel_startup_script
}

setup_cloudflare_auto() {
    log_message "Configurando Cloudflare Tunnel automático"
    
    # Configuración automática sin autenticación manual
    cat > /etc/cloudflared/config.yml << EOF
tunnel: auto-$(hostname)-$(date +%Y%m%d)
credentials-file: /etc/cloudflared/credentials.json

ingress:
  - hostname: webmin-$(hostname).trycloudflare.com
    service: https://localhost:${WEBMIN_PORT}
    originRequest:
      noTLSVerify: true
  - hostname: "*.$(hostname).trycloudflare.com"
    service: http://localhost:80
  - service: http_status:404

EOF
    
    # Crear credenciales temporales (quick tunnel)
    cat > /etc/cloudflared/quick-tunnel.yml << EOF
url: https://localhost:${WEBMIN_PORT}
logfile: /var/log/cloudflared-quick.log
EOF
    
    log_message "✓ Cloudflare configurado para arranque automático"
}

setup_ngrok_auto() {
    log_message "Configurando Ngrok automático"
    
    mkdir -p ~/.ngrok2
    cat > ~/.ngrok2/ngrok.yml << EOF
version: "2"
console_ui: false
log_level: info
log_format: json
log: /var/log/ngrok.log

tunnels:
  webmin:
    addr: ${WEBMIN_PORT}
    proto: http
    bind_tls: true
    inspect: false
  web:
    addr: 80
    proto: http
    bind_tls: true
    inspect: false
EOF
    
    log_message "✓ Ngrok configurado para arranque automático"
}

create_tunnel_startup_script() {
    log_message "Creando script de inicio automático"
    
    cat > "$SCRIPT_DIR/iniciar_tuneles_auto.sh" << 'EOF'
#!/bin/bash

# Inicio Automático de Túneles

LOG_FILE="/var/log/iniciar_tuneles_auto.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [TUNEL-AUTO] $1" | tee -a "$LOG_FILE"
}

start_primary_tunnel() {
    case "cloudflare" in
        cloudflare)
            log_message "Iniciando Cloudflare Quick Tunnel..."
            
            # Quick tunnel sin autenticación
            nohup cloudflared tunnel --url https://localhost:10000 --logfile /var/log/cloudflared-auto.log >/dev/null 2>&1 &
            
            sleep 15
            
            # Obtener URL del túnel
            local tunnel_url=$(grep -o 'https://[^.]*\.trycloudflare\.com' /var/log/cloudflared-auto.log | tail -1)
            if [ -n "$tunnel_url" ]; then
                log_message "✅ Cloudflare Tunnel activo: $tunnel_url"
                echo "$tunnel_url" > /tmp/webmin_tunnel_url.txt
                return 0
            else
                log_message "❌ Error al obtener URL de Cloudflare"
                return 1
            fi
            ;;
        ngrok)
            log_message "Iniciando Ngrok Tunnel..."
            
            nohup ngrok http 10000 --log /var/log/ngrok-auto.log >/dev/null 2>&1 &
            
            sleep 10
            
            # Obtener URL del túnel
            local tunnel_url=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url' 2>/dev/null)
            if [ -n "$tunnel_url" ] && [ "$tunnel_url" != "null" ]; then
                log_message "✅ Ngrok Tunnel activo: $tunnel_url"
                echo "$tunnel_url" > /tmp/webmin_tunnel_url.txt
                return 0
            else
                log_message "❌ Error al obtener URL de Ngrok"
                return 1
            fi
            ;;
    esac
}

start_backup_tunnel() {
    log_message "Iniciando túnel de respaldo..."
    
    case "ngrok" in
        ngrok)
            nohup ngrok http 10000 --log /var/log/ngrok-backup.log >/dev/null 2>&1 &
            sleep 10
            local backup_url=$(curl -s http://localhost:4041/api/tunnels | jq -r '.tunnels[0].public_url' 2>/dev/null)
            if [ -n "$backup_url" ] && [ "$backup_url" != "null" ]; then
                log_message "✅ Túnel de respaldo activo: $backup_url"
                echo "$backup_url" > /tmp/webmin_backup_tunnel_url.txt
            fi
            ;;
        cloudflare)
            nohup cloudflared tunnel --url https://localhost:10000 --logfile /var/log/cloudflared-backup.log >/dev/null 2>&1 &
            sleep 15
            local backup_url=$(grep -o 'https://[^.]*\.trycloudflare\.com' /var/log/cloudflared-backup.log | tail -1)
            if [ -n "$backup_url" ]; then
                log_message "✅ Túnel de respaldo activo: $backup_url"
                echo "$backup_url" > /tmp/webmin_backup_tunnel_url.txt
            fi
            ;;
    esac
}

# Detectar si necesita túnel y configurar
if ! curl -s --connect-timeout 5 ifconfig.me >/dev/null 2>&1; then
    log_message "⚠️  No se puede detectar IP pública - Iniciando túneles"
    start_primary_tunnel || start_backup_tunnel
else
    local public_ip=$(curl -s ifconfig.me)
    local local_ip=$(ip route get 8.8.8.8 | grep -oP 'src \K\S+')
    
    if [ "$public_ip" != "$local_ip" ]; then
        log_message "⚠️  Servidor detrás de NAT - Iniciando túneles"
        start_primary_tunnel || start_backup_tunnel
    else
        log_message "✅ IP pública directa - Túnel no requerido"
    fi
fi
EOF

    chmod +x "$SCRIPT_DIR/iniciar_tuneles_auto.sh"
    
    # Crear servicio systemd
    cat > /etc/systemd/system/auto-installer-tunnel.service << EOF
[Unit]
Description=Auto-Instalador de Túneles para IP Privada
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=root
ExecStart=$SCRIPT_DIR/sub_agente_auto_instalador_ip_privada.sh auto-install
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable auto-installer-tunnel.service
    
    log_message "✓ Servicio de auto-instalación creado"
}

auto_install_webmin_virtualmin() {
    log_message "=== AUTO-INSTALACIÓN WEBMIN/VIRTUALMIN ==="
    
    # Verificar si ya están instalados
    if command -v webmin &> /dev/null || [ -d "/usr/share/webmin" ]; then
        log_message "✅ Webmin ya está instalado"
    else
        log_message "Instalando Webmin..."
        
        # Descargar e instalar Webmin
        wget -O /tmp/webmin-current.deb http://prdownloads.sourceforge.net/webadmin/webmin_2.105_all.deb
        dpkg -i /tmp/webmin-current.deb || apt-get install -f -y
        rm -f /tmp/webmin-current.deb
        
        log_message "✓ Webmin instalado"
    fi
    
    # Verificar Virtualmin
    if command -v virtualmin &> /dev/null; then
        log_message "✅ Virtualmin ya está instalado"
    else
        log_message "Instalando Virtualmin..."
        
        # Script oficial de instalación de Virtualmin
        wget -O /tmp/install.sh https://software.virtualmin.com/gpl/scripts/install.sh
        chmod +x /tmp/install.sh
        /tmp/install.sh --force --hostname "$(hostname)"
        rm -f /tmp/install.sh
        
        log_message "✓ Virtualmin instalado"
    fi
    
    # Configurar acceso remoto
    configure_remote_access
}

configure_remote_access() {
    log_message "=== CONFIGURANDO ACCESO REMOTO ==="
    
    # Configurar Webmin para acceso remoto
    local webmin_config="/etc/webmin/miniserv.conf"
    if [ -f "$webmin_config" ]; then
        # Backup
        cp "$webmin_config" "${webmin_config}.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Permitir acceso desde cualquier IP
        sed -i 's/^allow=.*/allow=0.0.0.0\/0/' "$webmin_config"
        sed -i 's/^bind=.*/bind=0.0.0.0/' "$webmin_config"
        
        # Configurar SSL
        if [ "$SSL_AUTO_SETUP" = "true" ]; then
            sed -i 's/^ssl=.*/ssl=1/' "$webmin_config"
            sed -i 's/^ssl_redirect=.*/ssl_redirect=1/' "$webmin_config"
        fi
        
        systemctl restart webmin
        log_message "✓ Webmin configurado para acceso remoto"
    fi
    
    # Configurar firewall si está habilitado
    if [ "$FIREWALL_AUTO_CONFIG" = "true" ]; then
        # UFW
        if command -v ufw &> /dev/null; then
            ufw allow "$WEBMIN_PORT"/tcp
            ufw allow 80/tcp
            ufw allow 443/tcp
            ufw allow 22/tcp
            log_message "✓ Firewall configurado"
        fi
        
        # Configurar iptables para túneles
        iptables -A INPUT -p tcp --dport "$WEBMIN_PORT" -j ACCEPT
        iptables -A INPUT -p tcp --dport 80 -j ACCEPT
        iptables -A INPUT -p tcp --dport 443 -j ACCEPT
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    fi
}

setup_auto_ssl() {
    log_message "=== CONFIGURANDO SSL AUTOMÁTICO ==="
    
    # Instalar Certbot
    if ! command -v certbot &> /dev/null; then
        apt-get update && apt-get install -y certbot
        
        if systemctl is-active --quiet apache2; then
            apt-get install -y python3-certbot-apache
        fi
        
        if systemctl is-active --quiet nginx; then
            apt-get install -y python3-certbot-nginx
        fi
    fi
    
    # Crear script de renovación automática
    cat > /etc/cron.weekly/renew-ssl << 'EOF'
#!/bin/bash

# Renovación automática de certificados SSL

LOG_FILE="/var/log/ssl_renewal.log"

echo "=== RENOVACIÓN SSL - $(date) ===" >> "$LOG_FILE"

# Renovar certificados
certbot renew --quiet >> "$LOG_FILE" 2>&1

# Reiniciar servicios si es necesario
if systemctl is-active --quiet apache2; then
    systemctl reload apache2
fi

if systemctl is-active --quiet nginx; then
    systemctl reload nginx
fi

if systemctl is-active --quiet webmin; then
    systemctl restart webmin
fi

echo "Renovación completada" >> "$LOG_FILE"
EOF

    chmod +x /etc/cron.weekly/renew-ssl
    
    log_message "✓ SSL automático configurado"
}

create_installation_report() {
    log_message "=== GENERANDO REPORTE DE INSTALACIÓN ==="
    
    local install_report="/var/log/instalacion_automatica_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "REPORTE DE INSTALACIÓN AUTOMÁTICA"
        echo "=========================================="
        echo "Fecha: $(date)"
        echo "Servidor: $(hostname)"
        echo ""
        
        echo "=== INFORMACIÓN DE RED ==="
        if [ -f "$STATUS_FILE" ]; then
            jq -r '
                "IP Local: " + .local_ip,
                "IP Pública: " + .public_ip,
                "Tipo de Red: " + .network_type,
                "Proveedor Cloud: " + .cloud_provider,
                "Túnel Requerido: " + (.needs_tunnel | tostring)
            ' "$STATUS_FILE"
        fi
        
        echo ""
        echo "=== SERVICIOS INSTALADOS ==="
        echo "Webmin: $(systemctl is-active webmin 2>/dev/null || echo 'no instalado')"
        echo "Virtualmin: $(command -v virtualmin >/dev/null && echo 'instalado' || echo 'no instalado')"
        echo "Apache: $(systemctl is-active apache2 2>/dev/null || echo 'inactivo')"
        echo "Nginx: $(systemctl is-active nginx 2>/dev/null || echo 'inactivo')"
        echo "MySQL: $(systemctl is-active mysql 2>/dev/null || systemctl is-active mariadb 2>/dev/null || echo 'inactivo')"
        
        echo ""
        echo "=== TÚNELES CONFIGURADOS ==="
        if pgrep -f cloudflared >/dev/null; then
            echo "Cloudflare: ✅ ACTIVO"
            if [ -f "/tmp/webmin_tunnel_url.txt" ]; then
                echo "URL: $(cat /tmp/webmin_tunnel_url.txt)"
            fi
        else
            echo "Cloudflare: ❌ INACTIVO"
        fi
        
        if pgrep -f ngrok >/dev/null; then
            echo "Ngrok: ✅ ACTIVO"
            if [ -f "/tmp/webmin_tunnel_url.txt" ]; then
                echo "URL: $(cat /tmp/webmin_tunnel_url.txt)"
            fi
        else
            echo "Ngrok: ❌ INACTIVO"
        fi
        
        echo ""
        echo "=== ACCESO AL PANEL ==="
        if [ -f "/tmp/webmin_tunnel_url.txt" ]; then
            local tunnel_url=$(cat /tmp/webmin_tunnel_url.txt)
            echo "🌐 Acceso Webmin: $tunnel_url"
            echo "👤 Usuario: root"
            echo "🔑 Contraseña: [usar contraseña del sistema root]"
        else
            echo "⚠️  URL de túnel no disponible"
            echo "🔧 Verifique logs: /var/log/cloudflared-auto.log o /var/log/ngrok-auto.log"
        fi
        
        echo ""
        echo "=== INSTRUCCIONES POST-INSTALACIÓN ==="
        echo "1. Acceda al panel usando la URL del túnel"
        echo "2. Configure dominios en Virtualmin"
        echo "3. Active los sub-agentes de monitoreo:"
        echo "   ./coordinador_sub_agentes.sh start"
        echo "4. Configure alertas y notificaciones"
        echo "5. Realice backup inicial:"
        echo "   ./sub_agente_backup.sh start"
        
    } > "$install_report"
    
    log_message "✓ Reporte de instalación: $install_report"
    echo ""
    echo "📋 INSTALACIÓN COMPLETADA"
    echo "Reporte completo en: $install_report"
    echo ""
    cat "$install_report"
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")" "/var/lib/webmin" 2>/dev/null || true
    log_message "=== INICIANDO AUTO-INSTALADOR PARA IP PRIVADA ==="
    
    load_config
    
    case "${1:-auto-install}" in
        auto-install)
            if detect_network_environment; then
                log_message "✅ IP pública detectada - Instalación estándar"
                auto_install_webmin_virtualmin
                setup_auto_ssl
            else
                log_message "⚠️  IP privada detectada - Instalación con túneles"
                install_tunnel_dependencies
                auto_install_webmin_virtualmin
                auto_configure_tunnel
                create_tunnel_startup_script
                "$SCRIPT_DIR/iniciar_tuneles_auto.sh"
                setup_auto_ssl
            fi
            create_installation_report
            ;;
        detect)
            detect_network_environment
            ;;
        install-dependencies)
            install_tunnel_dependencies
            ;;
        configure-tunnel)
            auto_configure_tunnel
            ;;
        install-webmin)
            auto_install_webmin_virtualmin
            ;;
        setup-ssl)
            setup_auto_ssl
            ;;
        report)
            create_installation_report
            ;;
        status)
            if [ -f "$STATUS_FILE" ]; then
                jq '.' "$STATUS_FILE"
            else
                echo '{"error": "No hay estado disponible"}'
            fi
            ;;
        *)
            echo "Sub-Agente Auto-Instalador para IP Privada"
            echo "Uso: $0 {auto-install|detect|install-dependencies|configure-tunnel|install-webmin|setup-ssl|report|status}"
            echo ""
            echo "Comandos:"
            echo "  auto-install        - Instalación automática completa"
            echo "  detect              - Detectar tipo de red"
            echo "  install-dependencies - Instalar dependencias de túnel"
            echo "  configure-tunnel    - Configurar túneles"
            echo "  install-webmin      - Instalar Webmin/Virtualmin"
            echo "  setup-ssl           - Configurar SSL automático"
            echo "  report              - Mostrar reporte de instalación"
            echo "  status              - Estado actual"
            echo ""
            echo "🚀 Uso rápido: $0 auto-install"
            exit 1
            ;;
    esac
    
    log_message "Auto-instalador completado"
}

main "$@"
