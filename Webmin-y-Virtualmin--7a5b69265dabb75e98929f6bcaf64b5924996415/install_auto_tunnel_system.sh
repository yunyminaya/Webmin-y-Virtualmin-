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
            ;;
        "centos"|"rhel"|"fedora")
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y curl wget openssh-clients openssh-server jq net-tools
            else
                yum install -y curl wget openssh-clients openssh-server jq net-tools
            fi
            ;;
        "opensuse"|"sles")
            zypper install -y curl wget openssh jq net-tools
            ;;
        *)
            log "WARNING" "Sistema operativo no reconocido. Intentando instalación genérica..."
            if command -v apt-get >/dev/null 2>&1; then
                apt-get update && apt-get install -y curl wget ssh jq net-tools
            elif command -v yum >/dev/null 2>&1; then
                yum install -y curl wget openssh-clients jq net-tools
            else
                log "ERROR" "No se pudo instalar dependencias automáticamente"
                return 1
            fi
            ;;
    esac

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
    if ! curl -s --connect-timeout 5 https://api.ipify.org >/dev/null 2>&1; then
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
    echo
    echo -e "${CYAN}📋 PASOS SIGUIENTES:${NC}"
    echo -e "   1. Configure el archivo: ${YELLOW}/etc/auto_tunnel_config.conf${NC}"
    echo -e "   2. Configure el servidor remoto para túnel SSH"
    echo -e "   3. Inicie el servicio: ${YELLOW}systemctl start auto-tunnel${NC}"
    echo -e "   4. Habilite inicio automático: ${YELLOW}systemctl enable auto-tunnel${NC}"
    echo
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
        "uninstall")
            uninstall_system
            ;;
        "help"|"-h"|"--help")
            echo -e "${BLUE}=== INSTALADOR DEL SISTEMA DE TÚNEL AUTOMÁTICO ===${NC}"
            echo
            echo -e "${CYAN}Uso:${NC} $0 [comando]"
            echo
            echo -e "${GREEN}Comandos disponibles:${NC}"
            echo "  install     - Instalar el sistema completo"
            echo "  uninstall   - Desinstalar el sistema"
            echo "  help        - Mostrar esta ayuda"
            echo
            echo -e "${YELLOW}Ejemplos:${NC}"
            echo "  $0 install          # Instalar el sistema"
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