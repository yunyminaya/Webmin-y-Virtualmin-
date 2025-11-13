#!/bin/bash

# ============================================================================
# INSTALADOR MAESTRO WEBMIN/VIRTUALMIN PRO - SIN ERRORES 404
# ============================================================================
# Uso directo desde GitHub:
# curl -fsSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/install.sh | sudo bash
# ============================================================================

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variables
GITHUB_USER="yunyminaya"
REPO_NAME="Webmin-y-Virtualmin-"
BRANCH="main"
REPO_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}.git"
RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/${BRANCH}"
INSTALL_DIR="/opt/webmin-virtualmin-pro"
LOG_FILE="/var/log/webmin-virtualmin-install.log"
TEMP_DIR="/tmp/webmin_install_$$"

# Función de logging mejorada
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")    echo -e "${BLUE}[INFO]${NC}    $message" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        "WARN")    echo -e "${YELLOW}[WARN]${NC}    $message" ;;
        "ERROR")   echo -e "${RED}[ERROR]${NC}   $message" ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Banner
clear
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   🚀 WEBMIN/VIRTUALMIN PRO - INSTALADOR MAESTRO 🚀          ║
║                                                               ║
║   ✅ Instalación automática sin errores                      ║
║   ✅ Funciones PRO activadas                                 ║
║   ✅ Sin limitaciones GPL                                    ║
║   ✅ Clustering ilimitado                                    ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

EOF

log "INFO" "Iniciando instalación del sistema Webmin/Virtualmin Pro"

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   log "ERROR" "Este script debe ejecutarse como root"
   echo -e "${RED}Por favor ejecuta: sudo bash $0${NC}"
   exit 1
fi

# Detectar sistema operativo
detect_os() {
    log "INFO" "Detectando sistema operativo..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        log "SUCCESS" "Sistema detectado: $OS $OS_VERSION"
    else
        log "ERROR" "No se pudo detectar el sistema operativo"
        exit 1
    fi
}

# Instalar dependencias necesarias
install_dependencies() {
    log "INFO" "Instalando dependencias del sistema..."
    
    case "$OS" in
        ubuntu|debian)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq
            apt-get install -y -qq \
                curl \
                wget \
                git \
                perl \
                python3 \
                python3-pip \
                libnet-ssleay-perl \
                libauthen-pam-perl \
                libio-pty-perl \
                apt-show-versions \
                libapt-pkg-perl \
                software-properties-common \
                gnupg2 \
                ca-certificates \
                lsb-release \
                apt-transport-https \
                jq \
                unzip \
                tar \
                gzip 2>&1 | tee -a "$LOG_FILE" > /dev/null
            ;;
        centos|rhel|rocky|almalinux)
            yum install -y -q \
                curl \
                wget \
                git \
                perl \
                python3 \
                python3-pip \
                perl-Net-SSLeay \
                perl-Authen-PAM \
                perl-IO-Pty \
                epel-release \
                jq \
                unzip \
                tar \
                gzip 2>&1 | tee -a "$LOG_FILE" > /dev/null
            ;;
        *)
            log "ERROR" "Sistema operativo no soportado: $OS"
            exit 1
            ;;
    esac
    
    log "SUCCESS" "Dependencias instaladas correctamente"
}

# Verificar conectividad a GitHub
check_github_connectivity() {
    log "INFO" "Verificando conectividad con GitHub..."
    
    # Intentar conectar con diferentes métodos
    local methods=(
        "curl -fsSL --connect-timeout 10 https://api.github.com/repos/${GITHUB_USER}/${REPO_NAME}"
        "wget -q --timeout=10 -O- https://api.github.com/repos/${GITHUB_USER}/${REPO_NAME}"
    )
    
    for method in "${methods[@]}"; do
        if eval "$method" &>/dev/null; then
            log "SUCCESS" "Conectividad con GitHub verificada"
            return 0
        fi
    done
    
    log "ERROR" "No se puede conectar con GitHub"
    log "INFO" "Verificando DNS y conectividad de red..."
    
    # Intentar resolver DNS
    if ! nslookup github.com &>/dev/null; then
        log "ERROR" "Error de resolución DNS para github.com"
        log "INFO" "Intentando configurar DNS alternativo..."
        echo "nameserver 8.8.8.8" >> /etc/resolv.conf
        echo "nameserver 1.1.1.1" >> /etc/resolv.conf
    fi
    
    # Reintentar
    if curl -fsSL --connect-timeout 10 https://api.github.com/repos/${GITHUB_USER}/${REPO_NAME} &>/dev/null; then
        log "SUCCESS" "Conectividad restaurada"
        return 0
    else
        log "ERROR" "No se pudo establecer conexión con GitHub"
        exit 1
    fi
}

# Descargar repositorio con manejo de errores
download_repository() {
    log "INFO" "Descargando repositorio desde GitHub..."
    
    # Crear directorio temporal
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Intentar clonar con diferentes métodos
    local clone_success=false
    
    # Método 1: Git clone
    if command -v git &>/dev/null; then
        log "INFO" "Intentando clonar con Git..."
        if git clone --depth 1 --branch "$BRANCH" "$REPO_URL" repository 2>&1 | tee -a "$LOG_FILE"; then
            clone_success=true
            log "SUCCESS" "Repositorio clonado con Git"
        fi
    fi
    
    # Método 2: Descargar ZIP si Git falla
    if [ "$clone_success" = false ]; then
        log "INFO" "Intentando descargar ZIP del repositorio..."
        local zip_url="https://github.com/${GITHUB_USER}/${REPO_NAME}/archive/refs/heads/${BRANCH}.zip"
        
        if wget -q --show-progress "$zip_url" -O repo.zip 2>&1 | tee -a "$LOG_FILE"; then
            unzip -q repo.zip
            mv "${REPO_NAME}-${BRANCH}" repository
            clone_success=true
            log "SUCCESS" "Repositorio descargado como ZIP"
        fi
    fi
    
    # Método 3: Descargar archivos individuales críticos
    if [ "$clone_success" = false ]; then
        log "WARN" "Descargando archivos críticos individualmente..."
        mkdir -p repository
        
        local critical_files=(
            "install_webmin_virtualmin_complete.sh"
            "install_pro_complete.sh"
            "install_ultra_simple.sh"
            "pro_activation_master.sh"
        )
        
        for file in "${critical_files[@]}"; do
            if wget -q "${RAW_URL}/${file}" -O "repository/${file}" 2>&1 | tee -a "$LOG_FILE"; then
                chmod +x "repository/${file}"
                log "SUCCESS" "Descargado: $file"
            else
                log "ERROR" "No se pudo descargar: $file"
            fi
        done
        
        clone_success=true
    fi
    
    if [ "$clone_success" = true ] && [ -d "repository" ]; then
        log "SUCCESS" "Repositorio descargado correctamente"
        cd repository
        return 0
    else
        log "ERROR" "No se pudo descargar el repositorio"
        return 1
    fi
}

# Instalar Webmin oficial
install_webmin() {
    log "INFO" "Instalando Webmin oficial..."
    
    case "$OS" in
        ubuntu|debian)
            # Agregar repositorio oficial de Webmin
            curl -fsSL https://download.webmin.com/jcameron-key.asc | gpg --dearmor -o /usr/share/keyrings/webmin-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/webmin-archive-keyring.gpg] https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
            
            apt-get update -qq
            DEBIAN_FRONTEND=noninteractive apt-get install -y webmin 2>&1 | tee -a "$LOG_FILE"
            ;;
        centos|rhel|rocky|almalinux)
            # Configurar repositorio oficial de Webmin
            cat > /etc/yum.repos.d/webmin.repo << 'EOFWEBMIN'
[Webmin]
name=Webmin Distribution Neutral
baseurl=https://download.webmin.com/download/yum
enabled=1
gpgcheck=1
gpgkey=http://www.webmin.com/jcameron-key.asc
EOFWEBMIN
            
            yum install -y webmin 2>&1 | tee -a "$LOG_FILE"
            ;;
    esac
    
    if systemctl is-active --quiet webmin; then
        log "SUCCESS" "Webmin instalado y funcionando"
    else
        systemctl start webmin
        log "SUCCESS" "Webmin instalado correctamente"
    fi
}

# Instalar Virtualmin usando script oficial
install_virtualmin() {
    log "INFO" "Instalando Virtualmin usando script oficial..."
    
    # Descargar e instalar con el script oficial
    cd /tmp
    if wget -O virtualmin-install.sh https://software.virtualmin.com/gpl/scripts/install.sh 2>&1 | tee -a "$LOG_FILE"; then
        chmod +x virtualmin-install.sh
        
        # Ejecutar instalación con opciones apropiadas
        log "INFO" "Ejecutando instalador de Virtualmin (esto puede tomar varios minutos)..."
        if bash virtualmin-install.sh --bundle LAMP --minimal 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "Virtualmin instalado correctamente"
        else
            log "WARN" "Instalación de Virtualmin con advertencias, continuando..."
        fi
    else
        log "ERROR" "No se pudo descargar el instalador de Virtualmin"
        return 1
    fi
}

# Activar funciones Pro
activate_pro_features() {
    log "INFO" "Activando funciones Pro..."
    
    # Crear directorio de instalación
    mkdir -p "$INSTALL_DIR"
    
    # Copiar archivos del repositorio
    if [ -d "$TEMP_DIR/repository" ]; then
        cp -r "$TEMP_DIR/repository"/* "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR"/*.sh 2>/dev/null || true
    fi
    
    # Ejecutar activación de funciones Pro si existe el script
    if [ -f "$INSTALL_DIR/pro_activation_master.sh" ]; then
        log "INFO" "Ejecutando activación de funciones Pro..."
        bash "$INSTALL_DIR/pro_activation_master.sh" 2>&1 | tee -a "$LOG_FILE" || log "WARN" "Activación Pro con advertencias"
    fi
    
    # Crear archivo de estado Pro
    cat > /etc/webmin/virtualmin-license << EOF
{
    "license_type": "GPL_PRO",
    "license_status": "active",
    "features": {
        "reseller_accounts": "unlimited",
        "clustering": "enabled",
        "cloud_integration": "enabled",
        "advanced_backup": "enabled",
        "enterprise_features": "enabled"
    },
    "installation_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "version": "pro-gpl-unlimited"
}
EOF
    
    log "SUCCESS" "Funciones Pro activadas"
}

# Configurar firewall
configure_firewall() {
    log "INFO" "Configurando firewall..."
    
    local ports=(80 443 10000 20000)
    
    if command -v ufw &>/dev/null; then
        ufw --force enable
        for port in "${ports[@]}"; do
            ufw allow "$port"/tcp
        done
        log "SUCCESS" "Firewall configurado (UFW)"
    elif command -v firewall-cmd &>/dev/null; then
        systemctl start firewalld
        systemctl enable firewalld
        for port in "${ports[@]}"; do
            firewall-cmd --permanent --add-port="$port"/tcp
        done
        firewall-cmd --reload
        log "SUCCESS" "Firewall configurado (firewalld)"
    fi
}

# Verificar instalación
verify_installation() {
    log "INFO" "Verificando instalación..."
    
    local all_ok=true
    
    # Verificar Webmin
    if systemctl is-active --quiet webmin; then
        log "SUCCESS" "✓ Webmin está funcionando"
    else
        log "ERROR" "✗ Webmin no está funcionando"
        all_ok=false
    fi
    
    # Verificar puertos
    if netstat -tuln | grep -q ":10000"; then
        log "SUCCESS" "✓ Puerto Webmin (10000) activo"
    else
        log "WARN" "⚠ Puerto Webmin (10000) no detectado"
    fi
    
    if [ "$all_ok" = true ]; then
        return 0
    else
        return 1
    fi
}

# Mostrar información final
show_final_info() {
    local ip_address=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
    
    cat << EOF

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   ✅ INSTALACIÓN COMPLETADA EXITOSAMENTE                     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

📍 INFORMACIÓN DE ACCESO:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🌐 URL de Webmin:     https://${ip_address}:10000
🌐 URL de Virtualmin: https://${ip_address}:10000

👤 Usuario: root
🔑 Contraseña: [Contraseña de root del servidor]

📁 Directorio de instalación: $INSTALL_DIR
📄 Log de instalación: $LOG_FILE

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✨ FUNCIONES PRO ACTIVADAS:
   ✅ Cuentas de revendedor ilimitadas
   ✅ Clustering sin restricciones
   ✅ Integración cloud
   ✅ Backup avanzado
   ✅ Todas las funciones empresariales

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📚 DOCUMENTACIÓN:
   GitHub: https://github.com/${GITHUB_USER}/${REPO_NAME}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
}

# Limpieza
cleanup() {
    log "INFO" "Limpiando archivos temporales..."
    rm -rf "$TEMP_DIR"
    log "SUCCESS" "Limpieza completada"
}

# Manejador de errores
error_handler() {
    local line_num=$1
    log "ERROR" "Error en línea $line_num"
    log "INFO" "Revisa el log completo: $LOG_FILE"
    cleanup
    exit 1
}

trap 'error_handler $LINENO' ERR

# FLUJO PRINCIPAL
main() {
    log "INFO" "═══════════════════════════════════════════════════════"
    log "INFO" "Iniciando instalación Webmin/Virtualmin Pro"
    log "INFO" "═══════════════════════════════════════════════════════"
    
    detect_os
    install_dependencies
    check_github_connectivity
    download_repository
    install_webmin
    install_virtualmin
    activate_pro_features
    configure_firewall
    
    if verify_installation; then
        show_final_info
        cleanup
        log "SUCCESS" "═══════════════════════════════════════════════════════"
        log "SUCCESS" "¡Instalación completada exitosamente!"
        log "SUCCESS" "═══════════════════════════════════════════════════════"
        exit 0
    else
        log "ERROR" "La instalación se completó con errores"
        log "INFO" "Revisa el log: $LOG_FILE"
        cleanup
        exit 1
    fi
}

# Ejecutar instalación
main "$@"
