#!/bin/bash

# Script para realizar una verificación rápida del estado actual del sistema Webmin/Virtualmin

# Colores para los mensajes
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
MAGENTA="\033[0;35m"
CYAN="\033[0;36m"
NC="\033[0m" # No Color

# Función para mostrar mensajes
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $timestamp - $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $timestamp - $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $timestamp - $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $timestamp - $message"
            ;;
        *)
            echo -e "$timestamp - $message"
            ;;
    esac
}

# Función para mostrar el banner
show_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║   Verificación Rápida de Estado                               ║"
    echo "║   para Webmin y Virtualmin                                   ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Función para verificar si un servicio está activo
service_is_active() {
    local service_name="$1"
    
    if command -v systemctl &> /dev/null; then
        systemctl is-active --quiet "$service_name" 2>/dev/null
        return $?
    elif command -v service &> /dev/null; then
        service "$service_name" status &>/dev/null
        return $?
    elif [ -f "/etc/init.d/$service_name" ]; then
        /etc/init.d/"$service_name" status &>/dev/null
        return $?
    elif command -v launchctl &> /dev/null; then
        launchctl list | grep -q "$service_name"
        return $?
    else
        ps aux | grep -v grep | grep -q "$service_name"
        return $?
    fi
}

# Función para verificar el estado de Webmin
check_webmin_status() {
    log "INFO" "Verificando estado de Webmin..."
    
    echo -e "\n${CYAN}Estado de Webmin${NC}"
    
    # Verificar si Webmin está instalado
    if [ -d "/usr/share/webmin" ] || [ -d "/usr/libexec/webmin" ] || [ -d "/opt/webmin" ]; then
        echo -e "${GREEN}✓ Webmin está instalado${NC}"
        
        # Verificar si el servicio está activo
        if service_is_active "webmin"; then
            echo -e "${GREEN}✓ Servicio Webmin está activo${NC}"
            
            # Verificar versión
            if [ -f "/etc/webmin/version" ]; then
                WEBMIN_VERSION=$(cat /etc/webmin/version)
                echo -e "${BLUE}ℹ Versión de Webmin: $WEBMIN_VERSION${NC}"
            fi
            
            # Verificar puerto
            WEBMIN_PORT=$(grep -E "^port=" /etc/webmin/miniserv.conf 2>/dev/null | cut -d= -f2)
            if [ -n "$WEBMIN_PORT" ]; then
                echo -e "${BLUE}ℹ Puerto de Webmin: $WEBMIN_PORT${NC}"
                
                # Verificar si el puerto está abierto
                if command -v nc &> /dev/null; then
                    if nc -z localhost "$WEBMIN_PORT" &>/dev/null; then
                        echo -e "${GREEN}✓ Puerto $WEBMIN_PORT está abierto${NC}"
                    else
                        echo -e "${RED}✗ Puerto $WEBMIN_PORT no está abierto${NC}"
                    fi
                fi
            fi
            
            # Verificar SSL
            if grep -q "^ssl=1" /etc/webmin/miniserv.conf 2>/dev/null; then
                echo -e "${GREEN}✓ SSL está habilitado${NC}"
            else
                echo -e "${RED}✗ SSL no está habilitado${NC}"
            fi
        else
            echo -e "${RED}✗ Servicio Webmin no está activo${NC}"
        fi
    else
        echo -e "${RED}✗ Webmin no está instalado${NC}"
    fi
}

# Función para verificar el estado de Virtualmin
check_virtualmin_status() {
    log "INFO" "Verificando estado de Virtualmin..."
    
    echo -e "\n${CYAN}Estado de Virtualmin${NC}"
    
    # Verificar si Virtualmin está instalado
    if [ -d "/etc/webmin/virtual-server" ]; then
        echo -e "${GREEN}✓ Virtualmin está instalado${NC}"
        
        # Verificar versión
        if [ -f "/etc/webmin/virtual-server/version" ]; then
            VIRTUALMIN_VERSION=$(cat /etc/webmin/virtual-server/version)
            echo -e "${BLUE}ℹ Versión de Virtualmin: $VIRTUALMIN_VERSION${NC}"
        fi
        
        # Contar dominios
        if [ -f "/etc/webmin/virtual-server/domains" ]; then
            DOMAIN_COUNT=$(wc -l < /etc/webmin/virtual-server/domains)
            echo -e "${BLUE}ℹ Número de dominios: $DOMAIN_COUNT${NC}"
            
            # Contar dominios con SSL
            SSL_COUNT=0
            if [ -d "/etc/webmin/virtual-server/domains" ]; then
                for domain_file in /etc/webmin/virtual-server/domains/*; do
                    if grep -q "^ssl=1" "$domain_file" 2>/dev/null; then
                        SSL_COUNT=$((SSL_COUNT + 1))
                    fi
                done
            fi
            
            echo -e "${BLUE}ℹ Dominios con SSL: $SSL_COUNT${NC}"
            
            if [ "$SSL_COUNT" -lt "$DOMAIN_COUNT" ]; then
                echo -e "${YELLOW}⚠ No todos los dominios usan SSL${NC}"
            else
                echo -e "${GREEN}✓ Todos los dominios usan SSL${NC}"
            fi
        fi
    else
        echo -e "${RED}✗ Virtualmin no está instalado${NC}"
    fi
}

# Función para verificar el estado del servidor web
check_web_server_status() {
    log "INFO" "Verificando estado del servidor web..."
    
    echo -e "\n${CYAN}Estado del Servidor Web${NC}"
    
    # Verificar Apache
    if command -v apache2 &> /dev/null || command -v httpd &> /dev/null; then
        if command -v apache2 &> /dev/null; then
            APACHE_CMD="apache2"
        else
            APACHE_CMD="httpd"
        fi
        
        echo -e "${GREEN}✓ Apache está instalado${NC}"
        
        # Verificar versión
        APACHE_VERSION=$($APACHE_CMD -v 2>/dev/null | grep -E "^Server version" | awk -F"/" '{print $2}' | awk '{print $1}')
        if [ -n "$APACHE_VERSION" ]; then
            echo -e "${BLUE}ℹ Versión de Apache: $APACHE_VERSION${NC}"
        fi
        
        # Verificar si el servicio está activo
        if service_is_active "apache2" || service_is_active "httpd"; then
            echo -e "${GREEN}✓ Servicio Apache está activo${NC}"
            
            # Verificar módulos de seguridad
            if $APACHE_CMD -M 2>/dev/null | grep -q "ssl_module"; then
                echo -e "${GREEN}✓ Módulo SSL está habilitado${NC}"
            else
                echo -e "${RED}✗ Módulo SSL no está habilitado${NC}"
            fi
            
            if $APACHE_CMD -M 2>/dev/null | grep -q "security2_module"; then
                echo -e "${GREEN}✓ ModSecurity está habilitado${NC}"
            fi
            
            if $APACHE_CMD -M 2>/dev/null | grep -q "evasive_module"; then
                echo -e "${GREEN}✓ mod_evasive está habilitado${NC}"
            fi
        else
            echo -e "${RED}✗ Servicio Apache no está activo${NC}"
        fi
    fi
    
    # Verificar Nginx
    if command -v nginx &> /dev/null; then
        echo -e "${GREEN}✓ Nginx está instalado${NC}"
        
        # Verificar versión
        NGINX_VERSION=$(nginx -v 2>&1 | awk -F"/" '{print $2}')
        if [ -n "$NGINX_VERSION" ]; then
            echo -e "${BLUE}ℹ Versión de Nginx: $NGINX_VERSION${NC}"
        fi
        
        # Verificar si el servicio está activo
        if service_is_active "nginx"; then
            echo -e "${GREEN}✓ Servicio Nginx está activo${NC}"
            
            # Verificar configuración de SSL
            if grep -r "ssl_certificate" /etc/nginx/sites-enabled/* 2>/dev/null | grep -v "#" &>/dev/null || \
               grep -r "ssl_certificate" /etc/nginx/conf.d/* 2>/dev/null | grep -v "#" &>/dev/null; then
                echo -e "${GREEN}✓ SSL está configurado${NC}"
            else
                echo -e "${RED}✗ SSL no está configurado${NC}"
            fi
        else
            echo -e "${RED}✗ Servicio Nginx no está activo${NC}"
        fi
    fi
    
    if ! command -v apache2 &> /dev/null && ! command -v httpd &> /dev/null && ! command -v nginx &> /dev/null; then
        echo -e "${RED}✗ No se encontró ningún servidor web${NC}"
    fi
}

# Función para verificar el estado de la base de datos
check_database_status() {
    log "INFO" "Verificando estado de la base de datos..."
    
    echo -e "\n${CYAN}Estado de la Base de Datos${NC}"
    
    # Verificar MySQL/MariaDB
    if command -v mysql &> /dev/null; then
        echo -e "${GREEN}✓ MySQL/MariaDB está instalado${NC}"
        
        # Verificar versión
        DB_VERSION=$(mysql --version 2>/dev/null | awk '{print $3}')
        if [ -n "$DB_VERSION" ]; then
            echo -e "${BLUE}ℹ Versión de MySQL/MariaDB: $DB_VERSION${NC}"
            
            # Verificar si la versión es antigua
            if [[ "$DB_VERSION" == 5.* ]] || [[ "$DB_VERSION" == 10.0.* ]] || [[ "$DB_VERSION" == 10.1.* ]] || [[ "$DB_VERSION" == 10.2.* ]]; then
                echo -e "${YELLOW}⚠ Versión antigua: $DB_VERSION${NC}"
            fi
        fi
        
        # Verificar si el servicio está activo
        if service_is_active "mysql" || service_is_active "mariadb"; then
            echo -e "${GREEN}✓ Servicio MySQL/MariaDB está activo${NC}"
        else
            echo -e "${RED}✗ Servicio MySQL/MariaDB no está activo${NC}"
        fi
    fi
    
    # Verificar PostgreSQL
    if command -v psql &> /dev/null; then
        echo -e "${GREEN}✓ PostgreSQL está instalado${NC}"
        
        # Verificar versión
        PG_VERSION=$(psql --version 2>/dev/null | awk '{print $3}')
        if [ -n "$PG_VERSION" ]; then
            echo -e "${BLUE}ℹ Versión de PostgreSQL: $PG_VERSION${NC}"
            
            # Verificar si la versión es antigua
            if [[ "$PG_VERSION" == 9.* ]] || [[ "$PG_VERSION" == 10.* ]] || [[ "$PG_VERSION" == 11.* ]]; then
                echo -e "${YELLOW}⚠ Versión antigua: $PG_VERSION${NC}"
            fi
        fi
        
        # Verificar si el servicio está activo
        if service_is_active "postgresql"; then
            echo -e "${GREEN}✓ Servicio PostgreSQL está activo${NC}"
        else
            echo -e "${RED}✗ Servicio PostgreSQL no está activo${NC}"
        fi
    fi
    
    if ! command -v mysql &> /dev/null && ! command -v psql &> /dev/null; then
        echo -e "${RED}✗ No se encontró ninguna base de datos${NC}"
    fi
}

# Función para verificar el estado del firewall
check_firewall_status() {
    log "INFO" "Verificando estado del firewall..."
    
    echo -e "\n${CYAN}Estado del Firewall${NC}"
    
    FIREWALL_FOUND=false
    
    # Verificar UFW
    if command -v ufw &> /dev/null; then
        FIREWALL_FOUND=true
        echo -e "${GREEN}✓ UFW está instalado${NC}"
        
        # Verificar si está activo
        if ufw status | grep -q "Status: active"; then
            echo -e "${GREEN}✓ UFW está activo${NC}"
            
            # Verificar reglas para Webmin
            if ufw status | grep -q "10000"; then
                echo -e "${GREEN}✓ Puerto de Webmin (10000) está permitido${NC}"
            else
                echo -e "${RED}✗ Puerto de Webmin (10000) no está permitido${NC}"
            fi
            
            # Verificar reglas para SSH
            if ufw status | grep -q "22"; then
                echo -e "${GREEN}✓ Puerto SSH (22) está permitido${NC}"
            else
                echo -e "${RED}✗ Puerto SSH (22) no está permitido${NC}"
            fi
            
            # Verificar reglas para HTTP/HTTPS
            if ufw status | grep -q "80"; then
                echo -e "${GREEN}✓ Puerto HTTP (80) está permitido${NC}"
            else
                echo -e "${RED}✗ Puerto HTTP (80) no está permitido${NC}"
            fi
            
            if ufw status | grep -q "443"; then
                echo -e "${GREEN}✓ Puerto HTTPS (443) está permitido${NC}"
            else
                echo -e "${RED}✗ Puerto HTTPS (443) no está permitido${NC}"
            fi
        else
            echo -e "${RED}✗ UFW no está activo${NC}"
        fi
    fi
    
    # Verificar firewalld
    if command -v firewall-cmd &> /dev/null; then
        FIREWALL_FOUND=true
        echo -e "${GREEN}✓ firewalld está instalado${NC}"
        
        # Verificar si está activo
        if firewall-cmd --state 2>/dev/null | grep -q "running"; then
            echo -e "${GREEN}✓ firewalld está activo${NC}"
            
            # Verificar reglas para Webmin
            if firewall-cmd --list-ports 2>/dev/null | grep -q "10000"; then
                echo -e "${GREEN}✓ Puerto de Webmin (10000) está permitido${NC}"
            else
                echo -e "${RED}✗ Puerto de Webmin (10000) no está permitido${NC}"
            fi
            
            # Verificar reglas para SSH
            if firewall-cmd --list-services 2>/dev/null | grep -q "ssh"; then
                echo -e "${GREEN}✓ Servicio SSH está permitido${NC}"
            else
                echo -e "${RED}✗ Servicio SSH no está permitido${NC}"
            fi
            
            # Verificar reglas para HTTP/HTTPS
            if firewall-cmd --list-services 2>/dev/null | grep -q "http"; then
                echo -e "${GREEN}✓ Servicio HTTP está permitido${NC}"
            else
                echo -e "${RED}✗ Servicio HTTP no está permitido${NC}"
            fi
            
            if firewall-cmd --list-services 2>/dev/null | grep -q "https"; then
                echo -e "${GREEN}✓ Servicio HTTPS está permitido${NC}"
            else
                echo -e "${RED}✗ Servicio HTTPS no está permitido${NC}"
            fi
        else
            echo -e "${RED}✗ firewalld no está activo${NC}"
        fi
    fi
    
    # Verificar iptables
    if command -v iptables &> /dev/null && ! command -v ufw &> /dev/null && ! command -v firewall-cmd &> /dev/null; then
        FIREWALL_FOUND=true
        echo -e "${GREEN}✓ iptables está disponible${NC}"
        
        # Verificar si hay reglas configuradas
        IPTABLES_RULES=$(iptables -L -n 2>/dev/null | grep -v "Chain" | grep -v "target" | grep -v "^$" | wc -l)
        
        if [ "$IPTABLES_RULES" -gt 0 ]; then
            echo -e "${GREEN}✓ iptables tiene reglas configuradas ($IPTABLES_RULES reglas)${NC}"
            
            # Verificar reglas para Webmin
            if iptables -L -n 2>/dev/null | grep -q "dpt:10000"; then
                echo -e "${GREEN}✓ Puerto de Webmin (10000) está permitido${NC}"
            else
                echo -e "${RED}✗ Puerto de Webmin (10000) no está permitido${NC}"
            fi
            
            # Verificar reglas para SSH
            if iptables -L -n 2>/dev/null | grep -q "dpt:22"; then
                echo -e "${GREEN}✓ Puerto SSH (22) está permitido${NC}"
            else
                echo -e "${RED}✗ Puerto SSH (22) no está permitido${NC}"
            fi
            
            # Verificar reglas para HTTP/HTTPS
            if iptables -L -n 2>/dev/null | grep -q "dpt:80"; then
                echo -e "${GREEN}✓ Puerto HTTP (80) está permitido${NC}"
            else
                echo -e "${RED}✗ Puerto HTTP (80) no está permitido${NC}"
            fi
            
            if iptables -L -n 2>/dev/null | grep -q "dpt:443"; then
                echo -e "${GREEN}✓ Puerto HTTPS (443) está permitido${NC}"
            else
                echo -e "${RED}✗ Puerto HTTPS (443) no está permitido${NC}"
            fi
        else
            echo -e "${RED}✗ iptables no tiene reglas configuradas${NC}"
        fi
    fi
    
    # Verificar pf (macOS/FreeBSD)
    if command -v pfctl &> /dev/null; then
        FIREWALL_FOUND=true
        echo -e "${GREEN}✓ pf está disponible${NC}"
        
        # Verificar si está activo
        if pfctl -s info 2>/dev/null | grep -q "Status: Enabled"; then
            echo -e "${GREEN}✓ pf está activo${NC}"
        else
            echo -e "${RED}✗ pf no está activo${NC}"
        fi
    fi
    
    if [ "$FIREWALL_FOUND" = false ]; then
        echo -e "${RED}✗ No se encontró ningún firewall${NC}"
    fi
}

# Función para verificar actualizaciones pendientes
check_pending_updates() {
    log "INFO" "Verificando actualizaciones pendientes..."
    
    echo -e "\n${CYAN}Actualizaciones Pendientes${NC}"
    
    # Detectar el sistema operativo
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
    elif [ -f /etc/debian_version ]; then
        OS="debian"
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
    elif [ -f /etc/centos-release ]; then
        OS="centos"
    elif [ -f /etc/fedora-release ]; then
        OS="fedora"
    elif [ -f /etc/SuSE-release ]; then
        OS="suse"
    elif [ -f /etc/arch-release ]; then
        OS="arch"
    elif [ -f /etc/alpine-release ]; then
        OS="alpine"
    elif [ -f /etc/gentoo-release ]; then
        OS="gentoo"
    elif [ -x /usr/bin/sw_vers ]; then
        OS="macos"
    elif [ -x /usr/bin/freebsd-version ]; then
        OS="freebsd"
    else
        OS="unknown"
    fi
    
    echo -e "${BLUE}ℹ Sistema operativo: $OS${NC}"
    
    case "$OS" in
        "ubuntu"|"debian")
            # Verificar actualizaciones pendientes en Ubuntu/Debian
            if command -v apt &> /dev/null; then
                apt update -qq &>/dev/null
                UPDATES=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." | wc -l)
                SECURITY_UPDATES=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)
                
                echo -e "${BLUE}ℹ Actualizaciones pendientes: $UPDATES${NC}"
                echo -e "${BLUE}ℹ Actualizaciones de seguridad pendientes: $SECURITY_UPDATES${NC}"
                
                if [ "$SECURITY_UPDATES" -gt 0 ]; then
                    echo -e "${RED}✗ Hay actualizaciones de seguridad pendientes${NC}"
                elif [ "$UPDATES" -gt 0 ]; then
                    echo -e "${YELLOW}⚠ Hay actualizaciones pendientes${NC}"
                else
                    echo -e "${GREEN}✓ Sistema actualizado${NC}"
                fi
            fi
            ;;
        "rhel"|"centos"|"fedora")
            # Verificar actualizaciones pendientes en RHEL/CentOS/Fedora
            if command -v yum &> /dev/null; then
                UPDATES=$(yum check-update -q 2>/dev/null | grep -v "^$" | wc -l)
                SECURITY_UPDATES=$(yum check-update --security -q 2>/dev/null | grep -v "^$" | wc -l)
                
                echo -e "${BLUE}ℹ Actualizaciones pendientes: $UPDATES${NC}"
                echo -e "${BLUE}ℹ Actualizaciones de seguridad pendientes: $SECURITY_UPDATES${NC}"
                
                if [ "$SECURITY_UPDATES" -gt 0 ]; then
                    echo -e "${RED}✗ Hay actualizaciones de seguridad pendientes${NC}"
                elif [ "$UPDATES" -gt 0 ]; then
                    echo -e "${YELLOW}⚠ Hay actualizaciones pendientes${NC}"
                else
                    echo -e "${GREEN}✓ Sistema actualizado${NC}"
                fi
            elif command -v dnf &> /dev/null; then
                UPDATES=$(dnf check-update -q 2>/dev/null | grep -v "^$" | wc -l)
                SECURITY_UPDATES=$(dnf check-update --security -q 2>/dev/null | grep -v "^$" | wc -l)
                
                echo -e "${BLUE}ℹ Actualizaciones pendientes: $UPDATES${NC}"
                echo -e "${BLUE}ℹ Actualizaciones de seguridad pendientes: $SECURITY_UPDATES${NC}"
                
                if [ "$SECURITY_UPDATES" -gt 0 ]; then
                    echo -e "${RED}✗ Hay actualizaciones de seguridad pendientes${NC}"
                elif [ "$UPDATES" -gt 0 ]; then
                    echo -e "${YELLOW}⚠ Hay actualizaciones pendientes${NC}"
                else
                    echo -e "${GREEN}✓ Sistema actualizado${NC}"
                fi
            fi
            ;;
        "macos")
            # Verificar actualizaciones pendientes en macOS
            if command -v softwareupdate &> /dev/null; then
                UPDATES=$(softwareupdate -l 2>/dev/null | grep -i "recommended" | wc -l)
                
                echo -e "${BLUE}ℹ Actualizaciones pendientes: $UPDATES${NC}"
                
                if [ "$UPDATES" -gt 0 ]; then
                    echo -e "${YELLOW}⚠ Hay actualizaciones pendientes${NC}"
                else
                    echo -e "${GREEN}✓ Sistema actualizado${NC}"
                fi
            fi
            ;;
        *)
            echo -e "${YELLOW}⚠ No se pudo determinar el sistema de actualizaciones${NC}"
            ;;
    esac
    
    # Verificar actualizaciones de Webmin
    if [ -f "/etc/webmin/version" ]; then
        WEBMIN_VERSION=$(cat /etc/webmin/version)
        
        if command -v curl &> /dev/null; then
            LATEST_WEBMIN=$(curl -s https://download.webmin.com/download/version)
            
            if [ -n "$LATEST_WEBMIN" ]; then
                echo -e "${BLUE}ℹ Versión actual de Webmin: $WEBMIN_VERSION${NC}"
                echo -e "${BLUE}ℹ Última versión de Webmin: $LATEST_WEBMIN${NC}"
                
                if [ "$WEBMIN_VERSION" != "$LATEST_WEBMIN" ]; then
                    echo -e "${YELLOW}⚠ Hay una actualización disponible para Webmin${NC}"
                else
                    echo -e "${GREEN}✓ Webmin está actualizado${NC}"
                fi
            fi
        fi
    fi
}

# Función para verificar el estado de los servicios críticos
check_critical_services() {
    log "INFO" "Verificando estado de servicios críticos..."
    
    echo -e "\n${CYAN}Estado de Servicios Críticos${NC}"
    
    # Lista de servicios críticos
    SERVICES=("webmin" "apache2" "httpd" "nginx" "mysql" "mariadb" "postgresql" "postfix" "dovecot" "sshd" "fail2ban" "ufw" "firewalld" "iptables")
    
    for service in "${SERVICES[@]}"; do
        if service_is_active "$service"; then
            echo -e "${GREEN}✓ $service está activo${NC}"
        elif command -v "$service" &> /dev/null || [ -f "/etc/init.d/$service" ] || [ -f "/usr/lib/systemd/system/$service.service" ] || [ -f "/etc/systemd/system/$service.service" ]; then
            echo -e "${RED}✗ $service está instalado pero no activo${NC}"
        fi
    done
}

# Función para verificar los puertos abiertos
check_open_ports() {
    log "INFO" "Verificando puertos abiertos..."
    
    echo -e "\n${CYAN}Puertos Abiertos${NC}"
    
    if command -v netstat &> /dev/null; then
        echo -e "${BLUE}ℹ Puertos TCP abiertos:${NC}"
        netstat -tuln | grep "LISTEN" | grep "tcp" | awk '{print $4}' | awk -F":" '{print $NF}' | sort -n | uniq | while read -r port; do
            echo -e "  - Puerto $port"
        done
    elif command -v ss &> /dev/null; then
        echo -e "${BLUE}ℹ Puertos TCP abiertos:${NC}"
        ss -tuln | grep "LISTEN" | grep "tcp" | awk '{print $5}' | awk -F":" '{print $NF}' | sort -n | uniq | while read -r port; do
            echo -e "  - Puerto $port"
        done
    elif command -v lsof &> /dev/null; then
        echo -e "${BLUE}ℹ Puertos TCP abiertos:${NC}"
        lsof -i -P -n | grep "LISTEN" | awk '{print $9}' | awk -F":" '{print $NF}' | sort -n | uniq | while read -r port; do
            echo -e "  - Puerto $port"
        done
    else
        echo -e "${YELLOW}⚠ No se pudo determinar los puertos abiertos${NC}"
    fi
    
    # Verificar puertos específicos
    CRITICAL_PORTS=(22 80 443 10000 20000 25 110 143 993 995)
    
    for port in "${CRITICAL_PORTS[@]}"; do
        if command -v nc &> /dev/null; then
            if nc -z localhost "$port" &>/dev/null; then
                case "$port" in
                    22)
                        echo -e "${GREEN}✓ Puerto SSH (22) está abierto${NC}"
                        ;;
                    80)
                        echo -e "${GREEN}✓ Puerto HTTP (80) está abierto${NC}"
                        ;;
                    443)
                        echo -e "${GREEN}✓ Puerto HTTPS (443) está abierto${NC}"
                        ;;
                    10000)
                        echo -e "${GREEN}✓ Puerto Webmin (10000) está abierto${NC}"
                        ;;
                    20000)
                        echo -e "${GREEN}✓ Puerto Usermin (20000) está abierto${NC}"
                        ;;
                    25)
                        echo -e "${GREEN}✓ Puerto SMTP (25) está abierto${NC}"
                        ;;
                    110)
                        echo -e "${GREEN}✓ Puerto POP3 (110) está abierto${NC}"
                        ;;
                    143)
                        echo -e "${GREEN}✓ Puerto IMAP (143) está abierto${NC}"
                        ;;
                    993)
                        echo -e "${GREEN}✓ Puerto IMAPS (993) está abierto${NC}"
                        ;;
                    995)
                        echo -e "${GREEN}✓ Puerto POP3S (995) está abierto${NC}"
                        ;;
                    *)
                        echo -e "${GREEN}✓ Puerto $port está abierto${NC}"
                        ;;
                esac
            fi
        fi
    done
}

# Función principal
main() {
    clear
    show_banner
    
    # Ejecutar todas las verificaciones
    check_webmin_status
    check_virtualmin_status
    check_web_server_status
    check_database_status
    check_firewall_status
    check_pending_updates
    check_critical_services
    check_open_ports
    
    echo -e "\n${GREEN}Verificación rápida completada${NC}"
    echo -e "${YELLOW}Para una verificación completa, ejecute: ./verificar_seguridad_completa.sh${NC}"
    
    return 0
}

# Ejecutar la función principal
main