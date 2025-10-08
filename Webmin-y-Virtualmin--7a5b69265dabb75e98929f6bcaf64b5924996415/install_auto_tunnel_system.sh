#!/bin/bash
# install_auto_tunnel_system.sh
# Instalador automático del Sistema de Túnel Automático

# Configuración
SCRIPT_VERSION="2.0.0"
SCRIPT_NAME="Auto Tunnel System Installer"
LOG_FILE="/var/log/auto_tunnel_install.log"
BACKUP_DIR="/root/auto-tunnel-backup-$(date +%Y%m%d_%H%M%S)"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función de logging
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" >> "$LOG_FILE"
    echo -e "${timestamp} [${level}] ${message}"
}

# Función para verificar si estamos ejecutando como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Este instalador debe ejecutarse como root${NC}"
        echo -e "${YELLOW}Use: sudo $0${NC}"
        exit 1
    fi
}

# Función para detectar el sistema operativo
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    elif [[ -f /etc/redhat-release ]]; then
        OS="rhel"
        VERSION=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+' | head -1)
    else
        OS="unknown"
        VERSION="unknown"
    fi

    log "INFO" "Sistema operativo detectado: $OS $VERSION"
}

# Función para instalar dependencias
install_dependencies() {
    log "INFO" "Instalando dependencias del sistema..."

    case $OS in
        "ubuntu"|"debian")
            apt-get update
            apt-get install -y curl wget ssh openssh-client openssh-server jq net-tools

            # Instalar Node.js para servicios de túnel autónomos
            log "INFO" "Instalando Node.js para servicios de túnel autónomos..."
            curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
            apt-get install -y nodejs
            ;;
        "centos"|"rhel"|"fedora")
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y curl wget openssh-clients openssh-server jq net-tools

                # Instalar Node.js para servicios de túnel autónomos
                log "INFO" "Instalando Node.js para servicios de túnel autónomos..."
                curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -
                dnf install -y nodejs
            else
                yum install -y curl wget openssh-clients openssh-server jq net-tools

                # Instalar Node.js para servicios de túnel autónomos
                log "INFO" "Instalando Node.js para servicios de túnel autónomos..."
                curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -
                yum install -y nodejs
            fi
            ;;
        "opensuse"|"sles")
            zypper install -y curl wget openssh jq net-tools

            # Instalar Node.js para servicios de túnel autónomos
            log "INFO" "Instalando Node.js para servicios de túnel autónomos..."
            zypper install -y nodejs npm
            ;;
        *)
            log "WARNING" "Sistema operativo no reconocido. Intentando instalación genérica..."
            if command -v apt-get >/dev/null 2>&1; then
                apt-get update && apt-get install -y curl wget ssh jq net-tools

                # Instalar Node.js
                curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
                apt-get install -y nodejs
            elif command -v yum >/dev/null 2>&1; then
                yum install -y curl wget openssh-clients jq net-tools

                # Instalar Node.js
                curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -
                yum install -y nodejs
            else
                log "ERROR" "No se pudo instalar dependencias automáticamente"
                return 1
            fi
            ;;
    esac

    # Verificar instalación de Node.js
    if command -v node >/dev/null 2>&1; then
        local node_version=$(node --version 2>/dev/null)
        log "SUCCESS" "Node.js instalado: $node_version"
    else
        log "WARNING" "Node.js no se pudo instalar - algunos servicios de túnel pueden no funcionar"
    fi

    log "SUCCESS" "Dependencias instaladas correctamente"
}

# Función para crear directorios necesarios
create_directories() {
    log "INFO" "Creando directorios necesarios..."

    mkdir -p /etc/auto-tunnel
    mkdir -p /var/log
    mkdir -p /var/run
    mkdir -p /usr/local/bin
    mkdir -p /usr/lib/cgi-bin

    # Crear directorio de backup
    mkdir -p "$BACKUP_DIR"

    log "SUCCESS" "Directorios creados correctamente"
}

# Función para hacer backup de archivos existentes
backup_existing_files() {
    log "INFO" "Realizando backup de archivos existentes..."

    # Backup de archivos de configuración
    [[ -f /etc/auto_tunnel_config.conf ]] && cp /etc/auto_tunnel_config.conf "$BACKUP_DIR/"
    [[ -f /etc/ssh/sshd_config ]] && cp /etc/ssh/sshd_config "$BACKUP_DIR/"

    # Backup de servicios
    [[ -f /etc/systemd/system/auto-tunnel.service ]] && cp /etc/systemd/system/auto-tunnel.service "$BACKUP_DIR/"

    log "SUCCESS" "Backup completado en: $BACKUP_DIR"
}

# Función para instalar archivos del sistema
install_files() {
    log "INFO" "Instalando archivos del sistema..."

    # Copiar script principal
    cp auto_tunnel_system.sh /usr/local/bin/
    chmod +x /usr/local/bin/auto_tunnel_system.sh

    # Crear enlace simbólico
    ln -sf /usr/local/bin/auto_tunnel_system.sh /usr/local/bin/auto-tunnel

    # Instalar servicio systemd
    cp auto-tunnel.service /etc/systemd/system/
    systemctl daemon-reload

    # Instalar CGI script
    cp tunnel_status.cgi /usr/lib/cgi-bin/
    chmod +x /usr/lib/cgi-bin/tunnel_status.cgi

    # Instalar dashboard
    mkdir -p /var/www/html/tunnel-monitor
    cp tunnel_monitor_dashboard.html /var/www/html/tunnel-monitor/index.html

    log "SUCCESS" "Archivos instalados correctamente"
}

# Función para configurar SSH
configure_ssh() {
    log "INFO" "Configurando SSH para túnel automático..."

    local ssh_config="/etc/ssh/sshd_config"

    # Backup del archivo original
    cp "$ssh_config" "${ssh_config}.backup.$(date +%s)"

    # Configuraciones básicas para túnel
    if ! grep -q "PermitRootLogin" "$ssh_config"; then
        echo "PermitRootLogin yes" >> "$ssh_config"
    fi

    if ! grep -q "PasswordAuthentication" "$ssh_config"; then
        echo "PasswordAuthentication yes" >> "$ssh_config"
    fi

    if ! grep -q "AllowTcpForwarding" "$ssh_config"; then
        echo "AllowTcpForwarding yes" >> "$ssh_config"
    fi

    if ! grep -q "GatewayPorts" "$ssh_config"; then
        echo "GatewayPorts yes" >> "$ssh_config"
    fi

    # Configuraciones de seguridad
    if ! grep -q "MaxAuthTries" "$ssh_config"; then
        echo "MaxAuthTries 3" >> "$ssh_config"
    fi

    if ! grep -q "ClientAliveInterval" "$ssh_config"; then
        echo "ClientAliveInterval 300" >> "$ssh_config"
    fi

    if ! grep -q "ClientAliveCountMax" "$ssh_config"; then
        echo "ClientAliveCountMax 2" >> "$ssh_config"
    fi

    # Reiniciar SSH
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true

    log "SUCCESS" "SSH configurado para túnel automático"
}

# Función para configurar firewall
configure_firewall() {
    log "INFO" "Configurando firewall..."

    # Detectar sistema de firewall
    if command -v ufw >/dev/null 2>&1; then
        # UFW (Ubuntu/Debian)
        ufw allow 22/tcp comment "SSH para túnel automático"
        ufw --force enable
        log "SUCCESS" "UFW configurado"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        # Firewalld (CentOS/RHEL/Fedora)
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --reload
        log "SUCCESS" "Firewalld configurado"
    else
        log "WARNING" "No se detectó sistema de firewall conocido"
    fi
}

# Función para crear archivo de configuración
create_config() {
    log "INFO" "Creando archivo de configuración..."

    local config_file="/etc/auto_tunnel_config.conf"

    if [[ ! -f "$config_file" ]]; then
        cat > "$config_file" << 'EOF'
# Configuración del Sistema de Túnel Automático
# MODIFIQUE ESTOS VALORES SEGÚN SUS NECESIDADES

# Configuración del servidor remoto para túnel SSH
# IMPORTANTE: Configure estos valores antes de iniciar el servicio
TUNNEL_REMOTE_HOST="su-servidor-remoto.com"
TUNNEL_REMOTE_USER="tunnel_user"
TUNNEL_REMOTE_PORT="22"
TUNNEL_LOCAL_PORT="80"
TUNNEL_PORT="8080"

# Configuración de monitoreo
MONITOR_INTERVAL="60"
ENABLE_AUTO_RESTART="true"

# Configuración de alertas (opcional)
# Para recibir alertas por email, configure un servidor SMTP
ALERT_EMAIL=""
ALERT_WEBHOOK=""

# Configuración avanzada
SSH_KEY_PATH="/root/.ssh/auto_tunnel_key"
LOG_LEVEL="INFO"
MAX_RETRY_ATTEMPTS="5"
RETRY_DELAY="30"
EOF

        chmod 600 "$config_file"
        log "SUCCESS" "Archivo de configuración creado: $config_file"
        echo -e "${YELLOW}⚠️  IMPORTANTE: Configure los parámetros en $config_file antes de continuar${NC}"
    else
        log "INFO" "Archivo de configuración ya existe"
    fi
}

# Función para crear configuración automática con valores por defecto
create_auto_config() {
    log "INFO" "Creando configuración automática con valores por defecto..."

    local config_file="/etc/auto_tunnel_config.conf"

    cat > "$config_file" << 'EOF'
# Configuración del Sistema de Túnel Automático - Configuración Automática
# Valores por defecto configurados automáticamente para funcionamiento autónomo

# === CONFIGURACIÓN DE MODO DE TÚNEL ===
# Modos disponibles: "autonomous" (automático), "ssh" (servidores remotos), "auto" (inteligente)
TUNNEL_MODE="autonomous"  # Recomendado: autonomous para funcionamiento sin intervención

# === CONFIGURACIÓN DE TÚNELES AUTÓNOMOS ===
# Servicios de túnel automático (prioridad: localtunnel > serveo > ngrok)
ENABLE_AUTONOMOUS_TUNNEL="true"
TUNNEL_SERVICES=("localtunnel" "serveo" "ngrok")
NGROK_AUTH_TOKEN=""  # Opcional: token de ngrok para acceso premium

# === CONFIGURACIÓN DE SERVIDORES REMOTOS SSH (modo legacy) ===
# Formato: "host:user:port:weight" - weight determina prioridad en balanceo de carga
TUNNEL_REMOTE_SERVERS=(
    "tunnel.example.com:tunnel_user:22:10"
    "backup-tunnel.example.com:tunnel_user:22:8"
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
ALERT_EMAIL_RECIPIENTS="admin@localhost"  # Destinatarios de email separados por comas
ALERT_WEBHOOK_URLS=""                 # URLs de webhooks separados por comas
ALERT_DASHBOARD_FILE="/var/log/auto_tunnel_alerts.json"  # Archivo para dashboard de alertas

# Configuración de monitoreo de dominios 24/7
MONITORED_DOMAINS=(
    "google.com:80:443"
    "cloudflare.com:80:443"
    "github.com:22:80:443"
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

    chmod 600 "$config_file"
    log "SUCCESS" "Configuración automática creada: $config_file"
}

# Función para crear configuración de servidores de túnel
create_tunnel_servers_config() {
    log "INFO" "Creando configuración de servidores de túnel..."

    local servers_file="/etc/auto-tunnel/tunnel_servers.conf"

    mkdir -p /etc/auto-tunnel
    chmod 700 /etc/auto-tunnel

    cat > "$servers_file" << 'EOF'
# Configuración de servidores de túnel
# Formato: host:port:user:description

# Servidores principales
tunnel.example.com:22:tunnel:Servidor principal de túnel
backup-tunnel.example.com:22:tunnel:Servidor de respaldo

# Servidores adicionales (deshabilitados por defecto)
# tunnel2.example.com:22:tunnel:Servidor secundario
# tunnel3.example.com:22:tunnel:Servidor terciario
EOF

    chmod 600 "$servers_file"
    log "SUCCESS" "Configuración de servidores creada: $servers_file"
}

# Función para crear configuración de dominios públicos
create_domains_config() {
    log "INFO" "Creando configuración de dominios públicos..."

    local domains_file="/etc/auto-tunnel/domains.conf"

    mkdir -p /etc/auto-tunnel

    cat > "$domains_file" << 'EOF'
# Configuración de dominios públicos
# Formato: dominio:puerto:descripción

# Dominios locales
localhost:80:Dominio local para desarrollo
127.0.0.1:80:IP local

# Dominios de ejemplo (modificar según necesidades)
example.com:80:Dominio de ejemplo
test.example.com:80:Dominio de pruebas

# Dominios adicionales (deshabilitados por defecto)
# api.example.com:8080:Dominio API
# admin.example.com:8443:Dominio administración
EOF

    chmod 600 "$domains_file"
    log "SUCCESS" "Configuración de dominios creada: $domains_file"
}

# Función para crear configuración de alertas
create_alerts_config() {
    log "INFO" "Creando configuración de alertas..."

    local alerts_file="/etc/auto-tunnel/alerts.conf"

    mkdir -p /etc/auto-tunnel

    cat > "$alerts_file" << 'EOF'
# Configuración de alertas del sistema de túnel
# Formato: tipo:destino:condición:mensaje

# Alertas por email
email:admin@localhost:tunnel_down:Túnel SSH caído - Requiere atención inmediata
email:admin@localhost:tunnel_restored:Túnel SSH restaurado automáticamente

# Alertas por webhook (deshabilitadas por defecto)
# webhook:http://webhook.example.com/alert:tunnel_down:Túnel caído
# webhook:http://webhook.example.com/alert:tunnel_restored:Túnel restaurado

# Alertas de rendimiento
email:admin@localhost:high_latency:Alta latencia detectada en túnel
email:admin@localhost:connection_timeout:Timeout de conexión detectado

# Configuración general de alertas
ALERT_RETRY_ATTEMPTS="3"
ALERT_RETRY_DELAY="60"
ENABLE_DEDUPLICATION="true"
DEDUPLICATION_WINDOW="300"
EOF

    chmod 600 "$alerts_file"
    log "SUCCESS" "Configuración de alertas creada: $alerts_file"
}

# Función para configurar Apache/Nginx para CGI
configure_web_server() {
    log "INFO" "Configurando servidor web para dashboard CGI..."

    # Detectar servidor web
    if systemctl is-active --quiet apache2 2>/dev/null; then
        # Apache
        a2enmod cgi 2>/dev/null || true
        systemctl restart apache2 2>/dev/null || true
        log "SUCCESS" "Apache configurado para CGI"
    elif systemctl is-active --quiet nginx 2>/dev/null; then
        # Nginx - crear configuración para CGI
        local nginx_config="/etc/nginx/sites-available/tunnel-monitor"
        cat > "$nginx_config" << 'EOF'
server {
    listen 8081;
    server_name localhost;

    location /cgi-bin/ {
        root /usr/lib;
        fastcgi_pass unix:/var/run/fcgiwrap.socket;
        fastcgi_param SCRIPT_FILENAME $document_root$cgi-bin/$fastcgi_script_name;
        include fastcgi_params;
    }

    location /tunnel-monitor/ {
        alias /var/www/html/tunnel-monitor/;
        index index.html;
    }
}
EOF
        ln -sf "$nginx_config" /etc/nginx/sites-enabled/
        systemctl restart nginx 2>/dev/null || true
        log "SUCCESS" "Nginx configurado para dashboard"
    else
        log "WARNING" "No se detectó servidor web Apache/Nginx"
    fi
}

# Función para probar la instalación
test_installation() {
    log "INFO" "Probando instalación..."

    local errors=0

    # Verificar archivos
    if [[ ! -x /usr/local/bin/auto_tunnel_system.sh ]]; then
        log "ERROR" "Script principal no encontrado o no ejecutable"
        ((errors++))
    fi

    if [[ ! -f /etc/systemd/system/auto-tunnel.service ]]; then
        log "ERROR" "Servicio systemd no instalado"
        ((errors++))
    fi

    if [[ ! -f /etc/auto_tunnel_config.conf ]]; then
        log "ERROR" "Archivo de configuración no creado"
        ((errors++))
    fi

    # Verificar servicios
    if ! systemctl is-enabled auto-tunnel.service 2>/dev/null; then
        log "WARNING" "Servicio no habilitado para inicio automático"
    fi

    # Verificar conectividad
    if ! curl -s --ssl-reqd --connect-timeout 10 --max-time 30 --retry 3 --retry-delay 2 --user-agent "Auto-Tunnel-Installer/$SCRIPT_VERSION" https://api.ipify.org >/dev/null 2>&1; then
        log "WARNING" "No se puede acceder a servicios externos (posible problema de red)"
    fi

    if [[ $errors -eq 0 ]]; then
        log "SUCCESS" "Instalación completada exitosamente"
        return 0
    else
        log "ERROR" "Instalación completada con $errors errores"
        return 1
    fi
}

# Función para mostrar información post-instalación
show_post_install_info() {
    echo
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                INSTALACIÓN COMPLETADA                       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${GREEN}✅ Sistema de Túnel Automático instalado exitosamente${NC}"
    echo -e "${GREEN}✅ Configurado para modo AUTÓNOMO - Sin intervención manual requerida${NC}"
    echo

    # Verificar si se instaló con configuración automática
    if [[ -f "/etc/auto_tunnel_config.conf" ]] && grep -q "TUNNEL_MODE=\"autonomous\"" "/etc/auto_tunnel_config.conf" 2>/dev/null; then
        echo -e "${CYAN}🤖 MODO AUTÓNOMO ACTIVADO:${NC}"
        echo -e "   El sistema funcionará automáticamente sin configuración adicional"
        echo -e "   Servicios de túnel: localtunnel, serveo, ngrok (con fallback automático)"
        echo
        echo -e "${CYAN}📋 PASOS SIGUIENTES:${NC}"
        echo -e "   1. Inicie el servicio: ${YELLOW}systemctl start auto-tunnel${NC}"
        echo -e "   2. Habilite inicio automático: ${YELLOW}systemctl enable auto-tunnel${NC}"
        echo -e "   3. Verifique estado: ${YELLOW}auto-tunnel status${NC}"
        echo
    else
        echo -e "${CYAN}📋 PASOS SIGUIENTES:${NC}"
        echo -e "   1. Configure el archivo: ${YELLOW}/etc/auto_tunnel_config.conf${NC}"
        echo -e "   2. Configure el servidor remoto para túnel SSH"
        echo -e "   3. Inicie el servicio: ${YELLOW}systemctl start auto-tunnel${NC}"
        echo -e "   4. Habilite inicio automático: ${YELLOW}systemctl enable auto-tunnel${NC}"
        echo
    fi

    echo -e "${CYAN}🌐 DASHBOARD WEB:${NC}"
    echo -e "   URL: ${YELLOW}http://su-servidor/tunnel-monitor/${NC}"
    echo -e "   CGI: ${YELLOW}http://su-servidor:8081/cgi-bin/tunnel_status.cgi${NC}"
    echo
    echo -e "${CYAN}🛠️  COMANDOS ÚTILES:${NC}"
    echo -e "   Estado: ${YELLOW}auto-tunnel status${NC}"
    echo -e "   Iniciar: ${YELLOW}auto-tunnel start${NC}"
    echo -e "   Detener: ${YELLOW}auto-tunnel stop${NC}"
    echo -e "   Logs: ${YELLOW}tail -f /var/log/auto_tunnel_system.log${NC}"
    echo
    echo -e "${PURPLE}📁 ARCHIVOS DE BACKUP: $BACKUP_DIR${NC}"
    echo -e "${PURPLE}📋 LOG DE INSTALACIÓN: $LOG_FILE${NC}"
    echo
}

# Función principal de instalación
install_system() {
    echo -e "${BLUE}🚀 INSTALANDO SISTEMA DE TÚNEL AUTOMÁTICO ${SCRIPT_VERSION}${NC}"
    echo -e "${BLUE}═════════════════════════════════════════════════════${NC}"
    echo

    # Verificaciones iniciales
    check_root
    detect_os

    # Pasos de instalación
    local steps=(
        "Instalando dependencias del sistema"
        "Creando directorios necesarios"
        "Realizando backup de archivos existentes"
        "Instalando archivos del sistema"
        "Configurando SSH"
        "Configurando firewall"
        "Creando archivo de configuración"
        "Configurando servidor web"
        "Probando instalación"
    )

    local step_num=1
    local total_steps=${#steps[@]}

    for step in "${steps[@]}"; do
        echo -e "${CYAN}[$step_num/$total_steps] ${step}...${NC}"
        case $step_num in
            1) install_dependencies ;;
            2) create_directories ;;
            3) backup_existing_files ;;
            4) install_files ;;
            5) configure_ssh ;;
            6) configure_firewall ;;
            7) create_config ;;
            8) configure_web_server ;;
            9) test_installation ;;
        esac

        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}   ✅ Completado${NC}"
        else
            echo -e "${RED}   ❌ Error en el paso $step_num${NC}"
            return 1
        fi

        ((step_num++))
        echo
    done

    # Mostrar información final
    show_post_install_info

    log "SUCCESS" "Instalación del Sistema de Túnel Automático completada"
}

# Función principal de instalación automática
install_auto() {
    echo -e "${BLUE}🚀 INSTALACIÓN AUTOMÁTICA DEL SISTEMA DE TÚNEL AUTOMÁTICO ${SCRIPT_VERSION}${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo

    # Verificaciones iniciales
    check_root
    detect_os

    # Pasos de instalación automática
    local steps=(
        "Instalando dependencias del sistema"
        "Creando directorios necesarios"
        "Realizando backup de archivos existentes"
        "Instalando archivos del sistema"
        "Configurando SSH"
        "Configurando firewall"
        "Creando directorio de configuración"
        "Creando configuración automática"
        "Creando configuración de servidores de túnel"
        "Creando configuración de dominios"
        "Creando configuración de alertas"
        "Configurando servidor web"
        "Probando instalación"
    )

    local step_num=1
    local total_steps=${#steps[@]}

    for step in "${steps[@]}"; do
        echo -e "${CYAN}[$step_num/$total_steps] ${step}...${NC}"
        case $step_num in
            1) install_dependencies ;;
            2) create_directories ;;
            3) backup_existing_files ;;
            4) install_files ;;
            5) configure_ssh ;;
            6) configure_firewall ;;
            7) mkdir -p /etc/auto-tunnel ; log "SUCCESS" "Directorio de configuración creado" ;;
            8) create_auto_config ;;
            9) create_tunnel_servers_config ;;
            10) create_domains_config ;;
            11) create_alerts_config ;;
            12) configure_web_server ;;
            13) test_installation ;;
        esac

        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}   ✅ Completado${NC}"
        else
            echo -e "${RED}   ❌ Error en el paso $step_num${NC}"
            return 1
        fi

        ((step_num++))
        echo
    done

    # Mostrar información final
    show_post_install_info

    log "SUCCESS" "Instalación automática del Sistema de Túnel Automático completada"
}

# Función de desinstalación
uninstall_system() {
    echo -e "${YELLOW}⚠️  DESINSTALANDO SISTEMA DE TÚNEL AUTOMÁTICO${NC}"
    echo

    read -p "¿Está seguro de que desea desinstalar? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Desinstalación cancelada${NC}"
        exit 0
    fi

    log "INFO" "Iniciando desinstalación"

    # Detener y deshabilitar servicio
    systemctl stop auto-tunnel 2>/dev/null || true
    systemctl disable auto-tunnel 2>/dev/null || true

    # Remover archivos
    rm -f /usr/local/bin/auto_tunnel_system.sh
    rm -f /usr/local/bin/auto-tunnel
    rm -f /etc/systemd/system/auto-tunnel.service
    rm -f /usr/lib/cgi-bin/tunnel_status.cgi
    rm -rf /var/www/html/tunnel-monitor
    rm -f /etc/auto_tunnel_config.conf
    rm -f /var/log/auto_tunnel_system.log
    rm -f /var/run/auto_tunnel_system.pid
    rm -f /var/run/ssh_tunnel.pid
    rm -f /var/run/tunnel_monitor.pid

    # Recargar systemd
    systemctl daemon-reload

    echo -e "${GREEN}✅ Sistema de Túnel Automático desinstalado${NC}"
    log "SUCCESS" "Desinstalación completada"
}

# Función principal
main() {
    local command="${1:-install}"

    case "$command" in
        "install")
            install_system
            ;;
        "auto")
            install_auto
            ;;
        "uninstall")
            uninstall_system
            ;;
        "help"|"-h"|"--help")
            echo -e "${BLUE}=== INSTALADOR DEL SISTEMA DE TÚNEL AUTOMÁTICO ===${NC}"
            echo
            echo -e "${CYAN}Uso:${NC} $0 [comando]"
            echo
            echo -e "${GREEN}Comandos disponibles:${NC}"
            echo "  install     - Instalar el sistema completo (interactivo)"
            echo "  auto        - Instalar el sistema automáticamente con configuración por defecto"
            echo "  uninstall   - Desinstalar el sistema"
            echo "  help        - Mostrar esta ayuda"
            echo
            echo -e "${YELLOW}Ejemplos:${NC}"
            echo "  $0 install          # Instalar el sistema (interactivo)"
            echo "  $0 auto             # Instalar automáticamente"
            echo "  $0 uninstall        # Desinstalar el sistema"
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