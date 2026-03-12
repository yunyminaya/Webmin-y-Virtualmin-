#!/bin/bash

# Optimizador Completo del Sistema Ubuntu
# Para Webmin/Virtualmin Mejorado

set -euo pipefail

# Configuración
SCRIPT_VERSION="2.0.0"
LOG_FILE="/var/log/ubuntu_system_optimizer_$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="/opt/system_optimizer_backup_$(date +%Y%m%d_%H%M%S)"
TEMP_DIR="/tmp/system_optimizer_$$"

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables globales
TOTAL_TASKS=0
COMPLETED_TASKS=0
FAILED_TASKS=0
WARNING_TASKS=0

# Función de logging
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Función para registrar progreso
task_result() {
    local task_name="$1"
    local status="$2"
    local details="$3"
    
    ((TOTAL_TASKS++))
    
    case $status in
        "SUCCESS")
            ((COMPLETED_TASKS++))
            echo -e "${GREEN}✅ COMPLETADO${NC}: $task_name"
            log_message "INFO" "COMPLETADO: $task_name - $details"
            ;;
        "FAILED")
            ((FAILED_TASKS++))
            echo -e "${RED}❌ FALLÓ${NC}: $task_name"
            log_message "ERROR" "FALLÓ: $task_name - $details"
            ;;
        "WARNING")
            ((WARNING_TASKS++))
            echo -e "${YELLOW}⚠️  ADVERTENCIA${NC}: $task_name"
            log_message "WARNING" "ADVERTENCIA: $task_name - $details"
            ;;
    esac
}

# Función para verificar si se ejecuta como root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error: Este script debe ejecutarse como root${NC}"
        echo "Ejecuta: sudo $0"
        exit 1
    fi
}

# Función para detectar versión de Ubuntu
detect_ubuntu_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$VERSION_ID"
    else
        echo "unknown"
    fi
}

# Función para crear backup del sistema
create_system_backup() {
    echo -e "\n${BLUE}📦 Creando Backup del Sistema${NC}"
    log_message "INFO" "Iniciando backup del sistema"
    
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$TEMP_DIR"
    
    # Backup de configuraciones críticas
    local critical_configs=(
        "/etc/apt/sources.list"
        "/etc/hosts"
        "/etc/hostname"
        "/etc/resolv.conf"
        "/etc/ssh/sshd_config"
        "/etc/fstab"
        "/etc/passwd"
        "/etc/group"
        "/etc/shadow"
    )
    
    for config in "${critical_configs[@]}"; do
        if [ -f "$config" ]; then
            cp "$config" "$BACKUP_DIR/" 2>/dev/null || true
        fi
    done
    
    # Backup de Webmin/Virtualmin si existe
    if [ -d "/etc/webmin" ]; then
        cp -r /etc/webmin "$BACKUP_DIR/" 2>/dev/null || true
    fi
    
    if [ -d "/etc/virtualmin" ]; then
        cp -r /etc/virtualmin "$BACKUP_DIR/" 2>/dev/null || true
    fi
    
    # Crear lista de paquetes instalados
    dpkg --get-selections > "$BACKUP_DIR/installed_packages.txt" 2>/dev/null || true
    
    task_result "Backup del Sistema" "SUCCESS" "Backup creado en $BACKUP_DIR"
}

# Función para actualizar el sistema
update_system() {
    echo -e "\n${BLUE}🔄 Actualizando el Sistema${NC}"
    log_message "INFO" "Iniciando actualización del sistema"
    
    # Actualizar lista de paquetes
    if apt update; then
        task_result "Actualización de lista de paquetes" "SUCCESS" "Lista de paquetes actualizada"
    else
        task_result "Actualización de lista de paquetes" "FAILED" "Error al actualizar lista de paquetes"
        return 1
    fi
    
    # Actualizar paquetes del sistema
    if apt upgrade -y; then
        task_result "Actualización de paquetes" "SUCCESS" "Paquetes del sistema actualizados"
    else
        task_result "Actualización de paquetes" "FAILED" "Error al actualizar paquetes"
        return 1
    fi
    
    # Actualizar distribución
    if apt dist-upgrade -y; then
        task_result "Actualización de distribución" "SUCCESS" "Distribución actualizada"
    else
        task_result "Actualización de distribución" "WARNING" "Error en actualización de distribución"
    fi
    
    # Limpiar paquetes no necesarios
    if apt autoremove -y; then
        task_result "Limpieza de paquetes" "SUCCESS" "Paquetes no necesarios eliminados"
    else
        task_result "Limpieza de paquetes" "WARNING" "Error en limpieza de paquetes"
    fi
    
    # Limpiar caché de apt
    if apt autoclean; then
        task_result "Limpieza de caché" "SUCCESS" "Caché de apt limpiada"
    else
        task_result "Limpieza de caché" "WARNING" "Error en limpieza de caché"
    fi
}

# Función para instalar dependencias básicas
install_dependencies() {
    echo -e "\n${BLUE}📦 Instalando Dependencias Básicas${NC}"
    log_message "INFO" "Instalando dependencias básicas"
    
    local dependencies=(
        "curl"
        "wget"
        "unzip"
        "zip"
        "git"
        "vim"
        "nano"
        "htop"
        "tree"
        "build-essential"
        "software-properties-common"
        "apt-transport-https"
        "ca-certificates"
        "gnupg"
        "lsb-release"
        "python3"
        "python3-pip"
        "python3-venv"
        "ufw"
        "fail2ban"
        "logrotate"
        "rsync"
        "backup-manager"
    )
    
    for dep in "${dependencies[@]}"; do
        if dpkg -l | grep -q "^ii.*$dep"; then
            log_message "INFO" "$dep ya está instalado"
        else
            if apt install -y "$dep"; then
                task_result "Instalación de $dep" "SUCCESS" "$dep instalado correctamente"
            else
                task_result "Instalación de $dep" "FAILED" "Error al instalar $dep"
            fi
        fi
    done
}

# Función para configurar seguridad básica
configure_basic_security() {
    echo -e "\n${BLUE}🔒 Configurando Seguridad Básica${NC}"
    log_message "INFO" "Configurando seguridad básica del sistema"
    
    # Configurar UFW (Firewall)
    if command -v ufw >/dev/null 2>&1; then
        # Permitir SSH
        ufw allow ssh
        
        # Permitir HTTP/HTTPS
        ufw allow 80/tcp
        ufw allow 443/tcp
        
        # Permitir Webmin (puerto 10000)
        ufw allow 10000/tcp
        
        # Habilitar firewall
        ufw --force enable
        
        task_result "Configuración de UFW" "SUCCESS" "Firewall UFW configurado y habilitado"
    else
        task_result "Configuración de UFW" "FAILED" "UFW no está disponible"
    fi
    
    # Configurar fail2ban
    if [ -f "/etc/fail2ban/jail.local" ]; then
        # Copiar configuración por defecto
        cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
        
        # Configurar jails básicos
        cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log

[webmin]
enabled = true
port = 10000
logpath = /var/log/webmin/miniserv.log
EOF
        
        systemctl restart fail2ban
        task_result "Configuración de Fail2Ban" "SUCCESS" "Fail2Ban configurado para SSH y Webmin"
    else
        task_result "Configuración de Fail2Ban" "FAILED" "No se encontró configuración de Fail2Ban"
    fi
    
    # Configurar seguridad SSH
    if [ -f "/etc/ssh/sshd_config" ]; then
        # Backup de configuración original
        cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.backup"
        
        # Mejoras de seguridad SSH
        sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
        sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
        sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
        sed -i 's/#Protocol 2/Protocol 2/' /etc/ssh/sshd_config
        
        systemctl restart sshd
        task_result "Configuración de SSH" "SUCCESS" "Seguridad SSH mejorada"
    else
        task_result "Configuración de SSH" "FAILED" "No se encontró configuración SSH"
    fi
}

# Función para optimizar rendimiento del sistema
optimize_performance() {
    echo -e "\n${BLUE}⚡ Optimizando Rendimiento del Sistema${NC}"
    log_message "INFO" "Optimizando rendimiento del sistema"
    
    # Configurar límites de sistema
    cat > /etc/security/limits.conf << 'EOF'
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
root soft nofile 65536
root hard nofile 65536
root soft nproc 32768
root hard nproc 32768
EOF
    
    task_result "Configuración de límites del sistema" "SUCCESS" "Límites de archivos y procesos configurados"
    
    # Optimizar parámetros del kernel
    cat > /etc/sysctl.d/99-optimizer.conf << 'EOF'
# Optimización de red
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr

# Optimización de memoria
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5

# Seguridad de red
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
EOF
    
    # Aplicar configuración del kernel
    sysctl -p /etc/sysctl.d/99-optimizer.conf
    
    task_result "Optimización del kernel" "SUCCESS" "Parámetros del kernel optimizados"
    
    # Configurar swap (si no existe)
    if [ $(swapon --show | wc -l) -eq 0 ]; then
        # Crear archivo swap de 2GB
        fallocate -l 2G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        
        # Agregar a fstab
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        
        task_result "Configuración de Swap" "SUCCESS" "Archivo swap de 2GB creado y activado"
    else
        task_result "Configuración de Swap" "SUCCESS" "Swap ya está configurado"
    fi
}

# Función para instalar y configurar Webmin/Virtualmin
install_webmin_virtualmin() {
    echo -e "\n${BLUE}🌐 Instalando Webmin/Virtualmin${NC}"
    log_message "INFO" "Instalando Webmin/Virtualmin"
    
    # Agregar repositorio de Webmin
    curl -fsSL http://www.webmin.com/jcameron-key.asc | apt-key add -
    echo "deb http://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
    
    # Actualizar repositorios
    apt update
    
    # Instalar Webmin
    if apt install -y webmin; then
        task_result "Instalación de Webmin" "SUCCESS" "Webmin instalado correctamente"
    else
        task_result "Instalación de Webmin" "FAILED" "Error al instalar Webmin"
        return 1
    fi
    
    # Descargar e instalar Virtualmin
    if [ ! -f "/usr/sbin/virtualmin" ]; then
        cd /tmp
        wget http://software.virtualmin.com/gpl/scripts/install.sh
        chmod +x install.sh
        
        # Instalar Virtualmin en modo no interactivo
        if ./install.sh --force --hostname $(hostname) --minimal; then
            task_result "Instalación de Virtualmin" "SUCCESS" "Virtualmin instalado correctamente"
        else
            task_result "Instalación de Virtualmin" "FAILED" "Error al instalar Virtualmin"
        fi
        
        # Limpiar
        rm -f /tmp/install.sh
    else
        task_result "Instalación de Virtualmin" "SUCCESS" "Virtualmin ya está instalado"
    fi
    
    # Configurar servicios para iniciar automáticamente
    systemctl enable webmin
    systemctl start webmin
    
    task_result "Configuración de servicios Webmin" "SUCCESS" "Servicios Webmin configurados"
}

# Función para integrar sistema de credenciales seguras
integrate_secure_credentials() {
    echo -e "\n${BLUE}🔐 Integrando Sistema de Credenciales Seguras${NC}"
    log_message "INFO" "Integrando sistema de gestión segura de credenciales"
    
    # Crear directorio para el sistema de credenciales
    mkdir -p /opt/webmin_credential_system
    
    # Copiar archivos del sistema de credenciales
    if [ -f "lib/secure_credentials_test.sh" ]; then
        cp lib/secure_credentials_test.sh /opt/webmin_credential_system/
        chmod +x /opt/webmin_credential_system/secure_credentials_test.sh
        
        # Crear enlace simbólico en PATH
        ln -sf /opt/webmin_credential_system/secure_credentials_test.sh /usr/local/bin/secure_credentials
        
        task_result "Integración de sistema de credenciales" "SUCCESS" "Sistema de credenciales integrado en /opt/webmin_credential_system"
    else
        task_result "Integración de sistema de credenciales" "FAILED" "No se encontró el archivo del sistema de credenciales"
    fi
    
    # Crear script de integración con Webmin
    cat > /opt/webmin_credential_system/webmin_integration.sh << 'EOF'
#!/bin/bash
# Integración del sistema de credenciales con Webmin

source /opt/webmin_credential_system/secure_credentials_test.sh

# Función para usar en scripts de Webmin
webmin_store_credential() {
    local service="$1"
    local username="$2"
    local password="$3"
    
    /opt/webmin_credential_system/secure_credentials_test.sh store "$service" "$username" "$password"
}

webmin_retrieve_credential() {
    local service="$1"
    
    /opt/webmin_credential_system/secure_credentials_test.sh retrieve "$service"
}

# Exportar funciones para uso en otros scripts
export -f webmin_store_credential
export -f webmin_retrieve_credential
EOF
    
    chmod +x /opt/webmin_credential_system/webmin_integration.sh
    
    task_result "Script de integración Webmin" "SUCCESS" "Script de integración creado"
}

# Función para configurar monitoreo avanzado
setup_advanced_monitoring() {
    echo -e "\n${BLUE}📊 Configurando Monitoreo Avanzado${NC}"
    log_message "INFO" "Configurando sistema de monitoreo avanzado"
    
    # Instalar Node Exporter de Prometheus
    if [ ! -f "/usr/local/bin/node_exporter" ]; then
        cd /tmp
        wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
        tar xvfz node_exporter-1.6.1.linux-amd64.tar.gz
        mv node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
        rm -rf node_exporter-1.6.1.linux-amd64*
        
        # Crear usuario y servicio
        useradd --no-create-home --shell /bin/false node_exporter
        
        cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable node_exporter
        systemctl start node_exporter
        
        task_result "Instalación de Node Exporter" "SUCCESS" "Node Exporter instalado y configurado"
    else
        task_result "Instalación de Node Exporter" "SUCCESS" "Node Exporter ya está instalado"
    fi
    
    # Instalar y configurar nuestro sistema de monitoreo
    if [ -f "advanced_monitoring.sh" ]; then
        cp advanced_monitoring.sh /opt/webmin_credential_system/
        chmod +x /opt/webmin_credential_system/advanced_monitoring.sh
        
        # Crear servicio systemd para monitoreo
        cat > /etc/systemd/system/webmin-monitoring.service << 'EOF'
[Unit]
Description=Webmin Advanced Monitoring
After=network.target

[Service]
Type=simple
ExecStart=/opt/webmin_credential_system/advanced_monitoring.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable webmin-monitoring
        systemctl start webmin-monitoring
        
        task_result "Configuración de monitoreo avanzado" "SUCCESS" "Sistema de monitoreo avanzado configurado"
    else
        task_result "Configuración de monitoreo avanzado" "WARNING" "No se encontró el script de monitoreo avanzado"
    fi
}

# Función para configurar sistema SSL/TLS
setup_ssl_system() {
    echo -e "\n${BLUE}🔒 Configurando Sistema SSL/TLS${NC}"
    log_message "INFO" "Configurando sistema SSL/TLS"
    
    # Instalar Certbot para certificados SSL gratuitos
    if ! command -v certbot >/dev/null 2>&1; then
        apt install -y certbot python3-certbot-apache
        
        task_result "Instalación de Certbot" "SUCCESS" "Certbot instalado para certificados SSL"
    else
        task_result "Instalación de Certbot" "SUCCESS" "Certbot ya está instalado"
    fi
    
    # Copiar nuestro gestor SSL avanzado
    if [ -f "advanced_ssl_manager.sh" ]; then
        cp advanced_ssl_manager.sh /opt/webmin_credential_system/
        chmod +x /opt/webmin_credential_system/advanced_ssl_manager.sh
        
        task_result "Integración de gestor SSL" "SUCCESS" "Gestor SSL avanzado integrado"
    else
        task_result "Integración de gestor SSL" "WARNING" "No se encontró el gestor SSL avanzado"
    fi
    
    # Configurar renovación automática de certificados
    cat > /etc/cron.d/certbot-renewal << 'EOF'
0 3 * * * root certbot renew --quiet --post-hook "systemctl reload apache2 || systemctl reload nginx"
EOF
    
    task_result "Configuración de renovación SSL" "SUCCESS" "Renovación automática de certificados configurada"
}

# Función para configurar sistema de respaldos
setup_backup_system() {
    echo -e "\n${BLUE}💾 Configurando Sistema de Respaldos${NC}"
    log_message "INFO" "Configurando sistema de respaldos"
    
    # Crear directorio de respaldos
    mkdir -p /opt/backups/{daily,weekly,monthly}
    
    # Configurar backup-manager si está instalado
    if command -v backup-manager >/dev/null 2>&1; then
        cat > /etc/backup-manager.conf << 'EOF'
# Configuración básica de Backup Manager
export BM_REPOSITORY_ROOT="/opt/backups"
export BM_REPOSITORY_SECURE="true"
export BM_REPOSITORY_USER="root"
export BM_REPOSITORY_GROUP="root"
export BM_REPOSITORY_CHMOD="770"

# Métodos de respaldo
export BM_ARCHIVE_METHOD="tarball-incremental tarball"
export BM_TARBALL_DIRECTORIES="/etc /home /var/www /opt/webmin_credential_system"
export BM_TARBALL_BLACKLIST="/opt/backups /tmp /var/tmp"

# Retención
export BM_ARCHIVE_TTL="5"
export BM_ARCHIVE_WEEKLY_TTL="4"
export BM_ARCHIVE_MONTHLY_TTL="12"

# Compresión
export BM_TARBALL_FILETYPE="tar.gz"
export BM_TARBALL_OVER_SSH="false"
export BM_TARBALL_OVER_FTP="false"

# Notificaciones
export BM_MAIL_REPORT="false"
EOF
        
        task_result "Configuración de Backup Manager" "SUCCESS" "Backup Manager configurado"
    else
        task_result "Configuración de Backup Manager" "WARNING" "Backup Manager no está instalado"
    fi
    
    # Crear script de respaldo personalizado
    cat > /opt/webmin_credential_system/backup_system.sh << 'EOF'
#!/bin/bash
# Script de respaldo personalizado para Webmin/Virtualmin

BACKUP_DIR="/opt/backups/daily"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="webmin_backup_$DATE.tar.gz"

# Crear backup
tar -czf "$BACKUP_DIR/$BACKUP_FILE" \
    /etc/webmin \
    /etc/virtualmin \
    /opt/webmin_credential_system \
    /var/www \
    /etc/apache2 \
    /etc/nginx \
    /home

# Mantener solo los últimos 7 días
find "$BACKUP_DIR" -name "webmin_backup_*.tar.gz" -mtime +7 -delete

echo "Backup completado: $BACKUP_FILE"
EOF
    
    chmod +x /opt/webmin_credential_system/backup_system.sh
    
    # Configurar cron para respaldos diarios
    echo "0 2 * * * root /opt/webmin_credential_system/backup_system.sh" > /etc/cron.d/webmin-backup
    
    task_result "Configuración de respaldos personalizados" "SUCCESS" "Sistema de respaldos configurado"
}

# Función para configurar sistema de defensa con IA
setup_ai_defense() {
    echo -e "\n${BLUE}🤖 Configurando Sistema de Defensa con IA${NC}"
    log_message "INFO" "Configurando sistema de defensa con IA"
    
    # Instalar dependencias de Python para IA
    pip3 install --upgrade pip
    pip3 install scikit-learn numpy pandas matplotlib seaborn
    
    task_result "Instalación de dependencias de IA" "SUCCESS" "Dependencias de Python para IA instaladas"
    
    # Copiar nuestro sistema AI Defense
    if [ -f "ai_defense_system.sh" ]; then
        cp ai_defense_system.sh /opt/webmin_credential_system/
        chmod +x /opt/webmin_credential_system/ai_defense_system.sh
        
        # Crear servicio para AI Defense
        cat > /etc/systemd/system/ai-defense.service << 'EOF'
[Unit]
Description=AI Defense System
After=network.target

[Service]
Type=simple
ExecStart=/opt/webmin_credential_system/ai_defense_system.sh
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable ai-defense
        systemctl start ai-defense
        
        task_result "Configuración de AI Defense" "SUCCESS" "Sistema de defensa con IA configurado"
    else
        task_result "Configuración de AI Defense" "WARNING" "No se encontró el sistema AI Defense"
    fi
}

# Función para configurar firewall inteligente
setup_intelligent_firewall() {
    echo -e "\n${BLUE}🛡️ Configurando Firewall Inteligente${NC}"
    log_message "INFO" "Configurando firewall inteligente"
    
    # Copiar archivos del firewall inteligente
    if [ -d "intelligent-firewall" ]; then
        cp -r intelligent-firewall /opt/webmin_credential_system/
        chmod +x /opt/webmin_credential_system/intelligent-firewall/*.pl
        
        # Instalar dependencias de Perl si es necesario
        apt install -y libjson-perl libwww-perl libio-socket-ssl-perl
        
        # Crear servicio para firewall inteligente
        cat > /etc/systemd/system/intelligent-firewall.service << 'EOF'
[Unit]
Description=Intelligent Firewall System
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/perl /opt/webmin_credential_system/intelligent-firewall/init_firewall.pl
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable intelligent-firewall
        systemctl start intelligent-firewall
        
        task_result "Configuración de firewall inteligente" "SUCCESS" "Firewall inteligente configurado"
    else
        task_result "Configuración de firewall inteligente" "WARNING" "No se encontró el directorio del firewall inteligente"
    fi
}

# Función para generar reporte final
generate_final_report() {
    echo -e "\n${PURPLE}📋 Generando Reporte Final${NC}"
    log_message "INFO" "Generando reporte final de optimización"
    
    local report_file="/opt/system_optimization_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
========================================
REPORTE DE OPTIMIZACIÓN DEL SISTEMA UBUNTU
========================================
Versión del script: $SCRIPT_VERSION
Fecha de ejecución: $(date)
Versión de Ubuntu: $(detect_ubuntu_version)
Hostname: $(hostname)
IP: $(hostname -I | awk '{print $1}')

RESUMEN DE TAREAS EJECUTADAS
===========================
Total de tareas: $TOTAL_TASKS
Completadas exitosamente: $COMPLETED_TASKS
Fallidas: $FAILED_TASKS
Con advertencias: $WARNING_TASKS

Tasa de éxito: $(( (COMPLETED_TASKS * 100) / TOTAL_TASKS ))%

SERVICIOS CONFIGURADOS
=====================
EOF
    
    # Agregar estado de los servicios
    echo "" >> "$report_file"
    echo "ESTADO DE SERVICIOS" >> "$report_file"
    echo "===================" >> "$report_file"
    
    local services=("webmin" "ssh" "ufw" "fail2ban" "node_exporter" "webmin-monitoring" "ai-defense" "intelligent-firewall")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            echo "$service: ACTIVO" >> "$report_file"
        else
            echo "$service: INACTIVO" >> "$report_file"
        fi
    done
    
    # Agregar información de acceso
    echo "" >> "$report_file"
    echo "INFORMACIÓN DE ACCESO" >> "$report_file"
    echo "=====================" >> "$report_file"
    echo "Webmin: https://$(hostname -I | awk '{print $1}'):10000" >> "$report_file"
    echo "Node Exporter: http://$(hostname -I | awk '{print $1}'):9100" >> "$report_file"
    
    # Agregar ubicación de backups
    echo "" >> "$report_file"
    echo "BACKUPS Y LOGS" >> "$report_file"
    echo "==============" >> "$report_file"
    echo "Backup del sistema: $BACKUP_DIR" >> "$report_file"
    echo "Log de optimización: $LOG_FILE" >> "$report_file"
    echo "Directorio de respaldos: /opt/backups" >> "$report_file"
    
    # Agregar recomendaciones
    echo "" >> "$report_file"
    echo "RECOMENDACIONES POST-INSTALACIÓN" >> "$report_file"
    echo "=================================" >> "$report_file"
    echo "1. Cambiar contraseñas por defecto de Webmin" >> "$report_file"
    echo "2. Configurar certificados SSL con: certbot --apache" >> "$report_file"
    echo "3. Revisar logs de seguridad regularmente en /var/log/" >> "$report_file"
    echo "4. Monitorear el rendimiento con el sistema de monitoreo configurado" >> "$report_file"
    echo "5. Probar el sistema de respaldos manualmente" >> "$report_file"
    echo "6. Configurar notificaciones por correo del sistema" >> "$report_file"
    
    task_result "Generación de reporte final" "SUCCESS" "Reporte generado en $report_file"
    
    echo -e "\n${CYAN}📄 Reporte completo disponible en: $report_file${NC}"
}

# Función principal de optimización
main_optimizer() {
    echo -e "${PURPLE}🚀 OPTIMIZADOR COMPLETO DEL SISTEMA UBUNTU PARA WEBMIN/VIRTUALMIN${NC}"
    echo -e "${PURPLE}Versión: $SCRIPT_VERSION${NC}"
    echo -e "${PURPLE}================================================${NC}"
    
    # Verificar requisitos
    check_root
    
    # Detectar versión de Ubuntu
    local ubuntu_version=$(detect_ubuntu_version)
    echo -e "${BLUE}Versión de Ubuntu detectada: $ubuntu_version${NC}"
    
    if [[ "$ubuntu_version" < "20.04" ]]; then
        echo -e "${YELLOW}Advertencia: Este script está optimizado para Ubuntu 20.04 o superior${NC}"
        read -p "¿Desea continuar? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Crear backup
    create_system_backup
    
    # Ejecutar todas las optimizaciones
    update_system
    install_dependencies
    configure_basic_security
    optimize_performance
    install_webmin_virtualmin
    integrate_secure_credentials
    setup_advanced_monitoring
    setup_ssl_system
    setup_backup_system
    setup_ai_defense
    setup_intelligent_firewall
    
    # Generar reporte final
    generate_final_report
    
    # Mostrar resumen final
    echo -e "\n${PURPLE}📊 RESUMEN FINAL DE OPTIMIZACIÓN${NC}"
    echo -e "${PURPLE}==================================${NC}"
    echo "Total de tareas: $TOTAL_TASKS"
    echo -e "Completadas: ${GREEN}$COMPLETED_TASKS${NC}"
    echo -e "Fallidas: ${RED}$FAILED_TASKS${NC}"
    echo -e "Advertencias: ${YELLOW}$WARNING_TASKS${NC}"
    
    local success_rate=$(( (COMPLETED_TASKS * 100) / TOTAL_TASKS ))
    echo "Tasa de éxito: $success_rate%"
    
    if [ $success_rate -ge 90 ]; then
        echo -e "${GREEN}🎉 Optimización completada con ÉXITO${NC}"
    elif [ $success_rate -ge 75 ]; then
        echo -e "${GREEN}✅ Optimización completada exitosamente${NC}"
    else
        echo -e "${YELLOW}⚠️  Optimización completada con algunas advertencias${NC}"
    fi
    
    echo -e "\n${CYAN}🔄 El sistema se reiniciará en 30 segundos para aplicar todos los cambios${NC}"
    echo -e "${CYAN}Presiona Ctrl+C para cancelar el reinicio${NC}"
    
    sleep 30
    reboot
}

# Ejecutar optimización principal
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_optimizer "$@"
fi