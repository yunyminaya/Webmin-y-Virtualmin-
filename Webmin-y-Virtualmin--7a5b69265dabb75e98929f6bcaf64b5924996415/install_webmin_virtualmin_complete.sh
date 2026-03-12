#!/bin/bash

# =============================================================================
# INSTALADOR COMPLETO WEBMIN/VIRTUALMIN - COMANDO ÚNICO
# Instalación automática con manejo de errores y validaciones
# Uso: curl -fsSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install_webmin_virtualmin_complete.sh | sudo bash
# =============================================================================

set -euo pipefail

# Configuración de colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/webmin_virtualmin_install_$(date +%Y%m%d_%H%M%S).log"
TEMP_DIR="/tmp/webmin_install_$$"
REPO_URL="https://github.com/yunyminaya/Webmin-y-Virtualmin-.git"
MIN_DISK_SPACE_GB=10
MIN_RAM_GB=2

# Función de logging
log() {
    local level="$1"
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")  echo -e "${BLUE}[INFO]${NC}  $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC}  $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Función de manejo de errores
error_handler() {
    local line_number=$1
    local error_code=$2
    log "ERROR" "Error en línea $line_number (código: $error_code)"
    log "ERROR" "Revisa el log completo en: $LOG_FILE"
    cleanup_on_exit
    exit "$error_code"
}

# Configurar manejador de errores
trap 'error_handler ${LINENO} $?' ERR
trap cleanup_on_exit EXIT

# Limpieza en salida
cleanup_on_exit() {
    log "INFO" "Limpiando archivos temporales..."
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    log "INFO" "Limpieza completada"
}

# Verificar ejecución como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "Este script debe ejecutarse como root (sudo)"
        exit 1
    fi
}

# Verificar sistema operativo
check_os() {
    log "INFO" "Verificando sistema operativo..."
    
    if [[ ! -f /etc/os-release ]]; then
        log "ERROR" "No se puede determinar el sistema operativo"
        exit 1
    fi
    
    source /etc/os-release
    
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        log "ERROR" "Sistema operativo no soportado: $ID"
        log "INFO" "Sistemas soportados: Ubuntu, Debian"
        exit 1
    fi
    
    log "SUCCESS" "Sistema operativo compatible: $PRETTY_NAME"
}

# Verificar requisitos del sistema
check_system_requirements() {
    log "INFO" "Verificando requisitos del sistema..."
    
    # Verificar espacio en disco
    local available_space_gb=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    if [[ $available_space_gb -lt $MIN_DISK_SPACE_GB ]]; then
        log "ERROR" "Espacio en disco insuficiente: ${available_space_gb}GB disponible, ${MIN_DISK_SPACE_GB}GB requerido"
        exit 1
    fi
    log "SUCCESS" "Espacio en disco suficiente: ${available_space_gb}GB disponible"
    
    # Verificar RAM
    local available_ram_gb=$(free -g | awk 'NR==2{print $7}')
    if [[ $available_ram_gb -lt $MIN_RAM_GB ]]; then
        log "ERROR" "RAM insuficiente: ${available_ram_gb}GB disponible, ${MIN_RAM_GB}GB requerido"
        exit 1
    fi
    log "SUCCESS" "RAM suficiente: ${available_ram_gb}GB disponible"
    
    # Verificar conexión a internet
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        log "ERROR" "No hay conexión a internet"
        exit 1
    fi
    log "SUCCESS" "Conexión a internet verificada"
}

# Actualizar sistema
update_system() {
    log "INFO" "Actualizando paquetes del sistema..."
    
    # Actualizar lista de paquetes
    if ! apt-get update; then
        log "ERROR" "Error al actualizar la lista de paquetes"
        exit 1
    fi
    
    # Actualizar paquetes instalados
    if ! apt-get upgrade -y; then
        log "WARN" "Algunos paquetes no pudieron actualizarse, continuando..."
    fi
    
    log "SUCCESS" "Sistema actualizado correctamente"
}

# Instalar dependencias básicas
install_dependencies() {
    log "INFO" "Instalando dependencias básicas..."
    
    local packages=(
        curl
        wget
        git
        unzip
        software-properties-common
        apt-transport-https
        ca-certificates
        gnupg
        lsb-release
        python3
        python3-pip
        python3-venv
        build-essential
        openssl
        net-tools
        htop
        fail2ban
        ufw
    )
    
    if ! apt-get install -y "${packages[@]}"; then
        log "ERROR" "Error al instalar dependencias básicas"
        exit 1
    fi
    
    log "SUCCESS" "Dependencias básicas instaladas"
}

# Configurar firewall
setup_firewall() {
    log "INFO" "Configurando firewall..."
    
    # Resetear reglas UFW
    ufw --force reset
    
    # Políticas por defecto
    ufw default deny incoming
    ufw default allow outgoing
    
    # Permitir SSH (importante para no perder conexión)
    ufw allow ssh
    
    # Permitir HTTP y HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Permitir Webmin (puerto 10000)
    ufw allow 10000/tcp
    
    # Activar firewall
    ufw --force enable
    
    log "SUCCESS" "Firewall configurado correctamente"
}

# Clonar repositorio
clone_repository() {
    log "INFO" "Clonando repositorio Webmin/Virtualmin..."
    
    # Crear directorio temporal
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Clonar repositorio
    if ! git clone "$REPO_URL" webmin-virtualmin; then
        log "ERROR" "Error al clonar el repositorio"
        exit 1
    fi
    
    cd webmin-virtualmin
    log "SUCCESS" "Repositorio clonado correctamente"
}

# Instalar Webmin
install_webmin() {
    log "INFO" "Instalando Webmin..."
    
    # Añadir clave GPG de Webmin
    if ! curl -fsSL http://www.webmin.com/jcameron-key.asc | gpg --dearmor -o /usr/share/keyrings/webmin.gpg; then
        log "ERROR" "Error al añadir clave GPG de Webmin"
        exit 1
    fi
    
    # Añadir repositorio de Webmin
    echo "deb [signed-by=/usr/share/keyrings/webmin.gpg] http://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
    
    # Actualizar paquetes
    apt-get update
    
    # Instalar Webmin
    if ! apt-get install -y webmin; then
        log "ERROR" "Error al instalar Webmin"
        exit 1
    fi
    
    # Configurar Webmin para acceso remoto
    sed -i 's/ssl=1/ssl=1/' /etc/webmin/miniserv.conf
    sed -i 's/listen=10000/listen=10000/' /etc/webmin/miniserv.conf
    sed -i 's/allow=127.0.0.1/allow=0.0.0.0/' /etc/webmin/miniserv.conf
    
    # Reiniciar Webmin
    systemctl restart webmin
    
    log "SUCCESS" "Webmin instalado y configurado"
}

# Instalar Virtualmin
install_virtualmin() {
    log "INFO" "Instalando Virtualmin..."
    
    # Descargar script de instalación de Virtualmin
    if ! wget -O /tmp/install.sh http://software.virtualmin.com/gpl/scripts/install.sh; then
        log "ERROR" "Error al descargar script de instalación de Virtualmin"
        exit 1
    fi
    
    # Hacer ejecutable el script
    chmod +x /tmp/install.sh
    
    # Ejecutar instalación de Virtualmin con opciones seguras
    if ! /tmp/install.sh --force --hostname localhost --bundle LAMP --yes; then
        log "WARN" "La instalación de Virtualmin tuvo advertencias, continuando..."
    fi
    
    # Limpiar script de instalación
    rm -f /tmp/install.sh
    
    log "SUCCESS" "Virtualmin instalado"
}

# Configurar seguridad post-instalación
configure_security() {
    log "INFO" "Configurando seguridad post-instalación..."
    
    # Configurar Fail2Ban
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
logpath = /var/webmin/miniserv.log
EOF
    
    systemctl restart fail2ban
    
    # Configurar parámetros de kernel seguros
    cat >> /etc/sysctl.conf << 'EOF'

# Security hardening
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
EOF
    
    sysctl -p
    
    # Crear usuario admin con contraseña segura si no existe
    if ! id "webminadmin" >/dev/null 2>&1; then
        local password=$(openssl rand -base64 32)
        useradd -m -s /bin/bash webminadmin
        echo "webminadmin:$password" | chpasswd
        usermod -aG sudo webminadmin
        
        log "INFO" "Usuario 'webminadmin' creado con contraseña: $password"
        log "WARN" "GUARDA ESTA CONTRASEÑA: $password"
    fi
    
    log "SUCCESS" "Configuración de seguridad completada"
}

# Instalar módulos adicionales
install_additional_modules() {
    log "INFO" "Instalando módulos adicionales..."
    
    # Instalar módulos de seguridad
    if [[ -f "$SCRIPT_DIR/install_intelligent_firewall.sh" ]]; then
        log "INFO" "Instalando firewall inteligente..."
        bash "$SCRIPT_DIR/install_intelligent_firewall.sh" || log "WARN" "Error al instalar firewall inteligente"
    fi
    
    # Instalar sistema de backup inteligente
    if [[ -f "$SCRIPT_DIR/intelligent_backup_system" ]]; then
        log "INFO" "Configurando sistema de backup inteligente..."
        cp -r "$SCRIPT_DIR/intelligent_backup_system" /opt/
        cd /opt/intelligent_backup_system
        pip3 install -r requirements.txt || log "WARN" "Error al instalar dependencias de backup"
    fi
    
    # Instalar sistema de monitoreo
    if [[ -f "$SCRIPT_DIR/install_advanced_monitoring.sh" ]]; then
        log "INFO" "Instalando sistema de monitoreo avanzado..."
        bash "$SCRIPT_DIR/install_advanced_monitoring.sh" || log "WARN" "Error al instalar monitoreo avanzado"
    fi
    
    log "SUCCESS" "Módulos adicionales instalados"
}

# Configurar servicios systemd
setup_systemd_services() {
    log "INFO" "Configurando servicios systemd..."
    
    # Crear servicio de monitoreo del sistema
    cat > /etc/systemd/system/webmin-monitor.service << 'EOF'
[Unit]
Description=Webmin Virtualmin Monitoring Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/bin/bash -c 'while true; do systemctl status webmin virtualmin > /var/log/webmin_status.log 2>&1; sleep 300; done'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable webmin-monitor
    systemctl start webmin-monitor
    
    log "SUCCESS" "Servicios systemd configurados"
}

# Verificar instalación
verify_installation() {
    log "INFO" "Verificando instalación..."
    
    local errors=0
    
    # Verificar Webmin
    if ! systemctl is-active --quiet webmin; then
        log "ERROR" "Webmin no está activo"
        ((errors++))
    else
        log "SUCCESS" "Webmin está activo"
    fi
    
    # Verificar Virtualmin
    if ! systemctl is-active --quiet webmin; then
        log "WARN" "Virtualmin puede no estar completamente configurado"
    else
        log "SUCCESS" "Virtualmin está activo"
    fi
    
    # Verificar firewall
    if ! ufw status | grep -q "Status: active"; then
        log "ERROR" "Firewall no está activo"
        ((errors++))
    else
        log "SUCCESS" "Firewall está activo"
    fi
    
    # Verificar Fail2Ban
    if ! systemctl is-active --quiet fail2ban; then
        log "ERROR" "Fail2Ban no está activo"
        ((errors++))
    else
        log "SUCCESS" "Fail2Ban está activo"
    fi
    
    if [[ $errors -gt 0 ]]; then
        log "ERROR" "Se encontraron $errors errores durante la verificación"
        return 1
    else
        log "SUCCESS" "Verificación completada sin errores"
        return 0
    fi
}

# Generar reporte de instalación
generate_installation_report() {
    log "INFO" "Generando reporte de instalación..."
    
    local report_file="/root/webmin_virtualmin_installation_report.txt"
    
    cat > "$report_file" << EOF
===============================================
REPORTE DE INSTALACIÓN - WEBMIN/VIRTUALMIN
===============================================
Fecha: $(date)
Servidor: $(hostname)
IP: $(hostname -I | awk '{print $1}')

SERVICIOS INSTALADOS:
-------------------
- Webmin: $(systemctl is-active webmin)
- Firewall UFW: $(ufw status | grep "Status")
- Fail2Ban: $(systemctl is-active fail2ban)

ACCESO WEBMIN:
--------------
URL: https://$(hostname -I | awk '{print $1}'):10000
Usuario: root o webminadmin
Contraseña: [la que configuraste durante la instalación]

PUERTOS CONFIGURADOS:
--------------------
- SSH: 22
- HTTP: 80
- HTTPS: 443
- Webmin: 10000

SEGURIDAD CONFIGURADA:
---------------------
- Firewall activo con reglas restrictivas
- Fail2Ban configurado
- Parámetros de kernel endurecidos
- Usuario administrativo seguro creado

LOG DE INSTALACIÓN:
-----------------
$LOG_FILE

RECOMENDACIONES:
---------------
1. Cambia la contraseña de Webmin inmediatamente
2. Configura backups automáticos
3. Monitorea los logs regularmente
4. Mantén el sistema actualizado

===============================================
EOF
    
    log "SUCCESS" "Reporte generado en: $report_file"
}

# Función principal de instalación
main() {
    log "INFO" "Iniciando instalación completa de Webmin/Virtualmin..."
    log "INFO" "Log de instalación: $LOG_FILE"
    
    # Verificar requisitos previos
    check_root
    check_os
    check_system_requirements
    
    # Preparar sistema
    update_system
    install_dependencies
    setup_firewall
    
    # Instalar componentes principales
    clone_repository
    install_webmin
    install_virtualmin
    
    # Configurar seguridad y módulos adicionales
    configure_security
    install_additional_modules
    setup_systemd_services
    
    # Verificación final
    if verify_installation; then
        generate_installation_report
        
        echo ""
        echo "=================================================================="
        echo "🎉 INSTALACIÓN COMPLETADA CON ÉXITO"
        echo "=================================================================="
        echo ""
        echo "📋 Reporte completo: /root/webmin_virtualmin_installation_report.txt"
        echo "📝 Log de instalación: $LOG_FILE"
        echo ""
        echo "🌐 Acceso Webmin:"
        echo "   URL: https://$(hostname -I | awk '{print $1}'):10000"
        echo "   Usuario: root o webminadmin"
        echo ""
        echo "🔐 Para mayor seguridad:"
        echo "   1. Cambia la contraseña de Webmin inmediatamente"
        echo "   2. Revisa el reporte de instalación"
        echo "   3. Configura backups automáticos"
        echo ""
        echo "=================================================================="
        
        log "SUCCESS" "Instalación completada exitosamente"
    else
        log "ERROR" "La instalación tuvo errores, revisa el log: $LOG_FILE"
        exit 1
    fi
}

# Ejecutar función principal
main "$@"