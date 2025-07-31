#!/bin/bash

# =============================================================================
# INSTALACIÓN COMPLETA AUTOMÁTICA DE WEBMIN Y VIRTUALMIN
# Script unificado para instalar todo el panel completo automáticamente
# Compatible con macOS, Ubuntu, CentOS, Debian
# =============================================================================

set -e  # Salir si hay errores

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables globales
LOG_FILE="/tmp/instalacion_webmin_$(date +%Y%m%d_%H%M%S).log"
WEBMIN_VERSION="2.111"
WEBMIN_PORT="10000"
WEBMIN_USER="admin"
WEBMIN_PASS="admin123"
INSTALL_DIR="/opt/webmin"
TEMP_DIR="/tmp/webmin_install"

# Función para logging
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR $(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING $(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO $(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

# Función para detectar el sistema operativo
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        DISTRO="macos"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS="linux"
        DISTRO="$ID"
    elif [[ -f /etc/redhat-release ]]; then
        OS="linux"
        DISTRO="centos"
    else
        log_error "Sistema operativo no soportado"
        exit 1
    fi
    
    log_info "Sistema detectado: $OS - $DISTRO"
}

# Función para verificar permisos de administrador
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_info "Ejecutándose como root"
        return 0
    fi
    
    if command -v sudo >/dev/null 2>&1; then
        log_info "Usando sudo para permisos administrativos"
        SUDO="sudo"
        return 0
    fi
    
    log_error "Se requieren permisos de administrador. Ejecute como root o instale sudo."
    exit 1
}

# Función para instalar dependencias según el OS
install_dependencies() {
    log "Instalando dependencias del sistema..."
    
    case "$DISTRO" in
        "macos")
            # Verificar e instalar Homebrew
            if ! command -v brew >/dev/null 2>&1; then
                log "Instalando Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            
            # Instalar dependencias con Homebrew
            brew update
            brew install perl openssl wget curl mysql apache2 php
            
            # Iniciar servicios
            brew services start mysql
            brew services start httpd
            ;;
        "ubuntu"|"debian")
            $SUDO apt-get update
            $SUDO apt-get install -y perl libnet-ssleay-perl openssl libauthen-pam-perl \
                libpam-runtime libio-pty-perl apt-show-versions python3 wget curl \
                mysql-server apache2 php libapache2-mod-php php-mysql
            
            # Iniciar servicios
            $SUDO systemctl enable mysql apache2
            $SUDO systemctl start mysql apache2
            ;;
        "centos"|"rhel"|"fedora")
            if command -v dnf >/dev/null 2>&1; then
                PKG_MGR="dnf"
            else
                PKG_MGR="yum"
            fi
            
            $SUDO $PKG_MGR update -y
            $SUDO $PKG_MGR install -y perl perl-Net-SSLeay openssl perl-IO-Pty \
                perl-Encode-Detect wget curl mysql-server httpd php php-mysql
            
            # Iniciar servicios
            $SUDO systemctl enable mysqld httpd
            $SUDO systemctl start mysqld httpd
            ;;
        *)
            log_error "Distribución no soportada: $DISTRO"
            exit 1
            ;;
    esac
    
    log "Dependencias instaladas correctamente"
}

# Función para configurar MySQL
configure_mysql() {
    log "Configurando MySQL..."
    
    case "$DISTRO" in
        "macos")
            # En macOS con Homebrew, MySQL ya está configurado básicamente
            if brew services list | grep mysql | grep started >/dev/null; then
                log "MySQL ya está ejecutándose"
            else
                brew services start mysql
            fi
            ;;
        "ubuntu"|"debian")
            # Configurar MySQL en Ubuntu/Debian
            if ! $SUDO systemctl is-active --quiet mysql; then
                $SUDO systemctl start mysql
            fi
            
            # Configuración básica de seguridad
            $SUDO mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'rootpass123';"
            $SUDO mysql -e "DELETE FROM mysql.user WHERE User='';"
            $SUDO mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
            $SUDO mysql -e "DROP DATABASE IF EXISTS test;"
            $SUDO mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';"
            $SUDO mysql -e "FLUSH PRIVILEGES;"
            ;;
        "centos"|"rhel"|"fedora")
            # Configurar MySQL en CentOS/RHEL
            if ! $SUDO systemctl is-active --quiet mysqld; then
                $SUDO systemctl start mysqld
            fi
            
            # Obtener contraseña temporal si existe
            if [[ -f /var/log/mysqld.log ]]; then
                TEMP_PASS=$(grep 'temporary password' /var/log/mysqld.log | tail -1 | awk '{print $NF}')
                if [[ -n "$TEMP_PASS" ]]; then
                    mysql -uroot -p"$TEMP_PASS" --connect-expired-password -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'RootPass123!';"
                fi
            fi
            ;;
    esac
    
    log "MySQL configurado correctamente"
}

# Función para descargar e instalar Webmin
install_webmin() {
    log "Descargando e instalando Webmin $WEBMIN_VERSION..."
    
    # Crear directorio temporal
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Descargar Webmin
    WEBMIN_URL="https://github.com/webmin/webmin/archive/refs/tags/$WEBMIN_VERSION.tar.gz"
    wget -O "webmin-$WEBMIN_VERSION.tar.gz" "$WEBMIN_URL"
    
    # Extraer
    tar -xzf "webmin-$WEBMIN_VERSION.tar.gz"
    cd "webmin-$WEBMIN_VERSION"
    
    # Configurar instalación
    case "$DISTRO" in
        "macos")
            # Instalación en macOS
            $SUDO mkdir -p "$INSTALL_DIR"
            $SUDO cp -r * "$INSTALL_DIR/"
            cd "$INSTALL_DIR"
            
            # Configurar Webmin
            $SUDO ./setup.sh <<EOF
$INSTALL_DIR
/var/log/webmin
$WEBMIN_PORT
$WEBMIN_USER
$WEBMIN_PASS
$WEBMIN_PASS
Y
Y
Y
Y
EOF
            ;;
        *)
            # Instalación en Linux
            $SUDO ./setup.sh <<EOF
$INSTALL_DIR
/var/log/webmin
$WEBMIN_PORT
$WEBMIN_USER
$WEBMIN_PASS
$WEBMIN_PASS
Y
Y
Y
Y
EOF
            ;;
    esac
    
    log "Webmin instalado correctamente"
}

# Función para instalar Virtualmin
install_virtualmin() {
    log "Instalando Virtualmin..."
    
    # Descargar script de instalación de Virtualmin
    cd "$TEMP_DIR"
    wget -O virtualmin-install.sh https://software.virtualmin.com/gpl/scripts/install.sh
    chmod +x virtualmin-install.sh
    
    # Ejecutar instalación
    case "$DISTRO" in
        "macos")
            log_warning "Virtualmin no tiene soporte oficial para macOS. Instalando módulos manualmente..."
            # Copiar módulos de Virtualmin desde el directorio actual
            if [[ -d "../virtualmin-gpl-master" ]]; then
                $SUDO cp -r ../virtualmin-gpl-master/* "$INSTALL_DIR/virtualmin/"
            fi
            ;;
        *)
            # Instalación estándar en Linux
            $SUDO ./virtualmin-install.sh --force --hostname $(hostname -f)
            ;;
    esac
    
    log "Virtualmin instalado correctamente"
}

# Función para configurar servicios del sistema
configure_system_services() {
    log "Configurando servicios del sistema..."
    
    case "$DISTRO" in
        "macos")
            # Crear LaunchDaemon para Webmin en macOS
            cat > /tmp/com.webmin.webmin.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.webmin.webmin</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/miniserv.pl</string>
        <string>$INSTALL_DIR/miniserv.conf</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/webmin/miniserv.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/webmin/miniserv.error</string>
</dict>
</plist>
EOF
            
            $SUDO mv /tmp/com.webmin.webmin.plist /Library/LaunchDaemons/
            $SUDO chown root:wheel /Library/LaunchDaemons/com.webmin.webmin.plist
            $SUDO launchctl load /Library/LaunchDaemons/com.webmin.webmin.plist
            ;;
        *)
            # Configurar systemd en Linux
            $SUDO systemctl enable webmin
            $SUDO systemctl start webmin
            ;;
    esac
    
    log "Servicios configurados correctamente"
}

# Función para configurar firewall
configure_firewall() {
    log "Configurando firewall..."
    
    case "$DISTRO" in
        "macos")
            log_info "En macOS, configure manualmente el firewall si es necesario"
            ;;
        "ubuntu"|"debian")
            if command -v ufw >/dev/null 2>&1; then
                $SUDO ufw allow $WEBMIN_PORT/tcp
                $SUDO ufw allow 80/tcp
                $SUDO ufw allow 443/tcp
            fi
            ;;
        "centos"|"rhel"|"fedora")
            if command -v firewall-cmd >/dev/null 2>&1; then
                $SUDO firewall-cmd --permanent --add-port=$WEBMIN_PORT/tcp
                $SUDO firewall-cmd --permanent --add-port=80/tcp
                $SUDO firewall-cmd --permanent --add-port=443/tcp
                $SUDO firewall-cmd --reload
            fi
            ;;
    esac
    
    log "Firewall configurado correctamente"
}

# Función para verificar la instalación
verify_installation() {
    log "Verificando instalación..."
    
    # Verificar que Webmin esté ejecutándose
    sleep 5
    if curl -k -s "https://localhost:$WEBMIN_PORT" >/dev/null; then
        log "✅ Webmin está ejecutándose correctamente en puerto $WEBMIN_PORT"
    else
        log_warning "⚠️  Webmin puede no estar ejecutándose correctamente"
    fi
    
    # Verificar servicios
    case "$DISTRO" in
        "macos")
            if brew services list | grep mysql | grep started >/dev/null; then
                log "✅ MySQL está ejecutándose"
            else
                log_warning "⚠️  MySQL no está ejecutándose"
            fi
            
            if brew services list | grep httpd | grep started >/dev/null; then
                log "✅ Apache está ejecutándose"
            else
                log_warning "⚠️  Apache no está ejecutándose"
            fi
            ;;
        *)
            if systemctl is-active --quiet mysql || systemctl is-active --quiet mysqld; then
                log "✅ MySQL está ejecutándose"
            else
                log_warning "⚠️  MySQL no está ejecutándose"
            fi
            
            if systemctl is-active --quiet apache2 || systemctl is-active --quiet httpd; then
                log "✅ Apache está ejecutándose"
            else
                log_warning "⚠️  Apache no está ejecutándose"
            fi
            ;;
    esac
    
    log "Verificación completada"
}

# Función para limpiar archivos temporales
cleanup() {
    log "Limpiando archivos temporales..."
    rm -rf "$TEMP_DIR"
    log "Limpieza completada"
}

# Función para mostrar información final
show_final_info() {
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${GREEN}🎉 INSTALACIÓN COMPLETADA EXITOSAMENTE${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    echo -e "${BLUE}📋 INFORMACIÓN DE ACCESO:${NC}"
    echo "   • URL de Webmin: https://localhost:$WEBMIN_PORT"
    echo "   • Usuario: $WEBMIN_USER"
    echo "   • Contraseña: $WEBMIN_PASS"
    echo
    echo -e "${BLUE}🔧 SERVICIOS INSTALADOS:${NC}"
    echo "   • Webmin $WEBMIN_VERSION"
    echo "   • Virtualmin (módulo GPL)"
    echo "   • MySQL/MariaDB"
    echo "   • Apache HTTP Server"
    echo "   • PHP"
    echo
    echo -e "${BLUE}📁 UBICACIONES IMPORTANTES:${NC}"
    echo "   • Directorio de Webmin: $INSTALL_DIR"
    echo "   • Logs de instalación: $LOG_FILE"
    echo "   • Logs de Webmin: /var/log/webmin/"
    echo
    echo -e "${BLUE}🚀 PRÓXIMOS PASOS:${NC}"
    echo "   1. Abra su navegador web"
    echo "   2. Vaya a: https://localhost:$WEBMIN_PORT"
    echo "   3. Acepte el certificado SSL autofirmado"
    echo "   4. Inicie sesión con las credenciales mostradas arriba"
    echo "   5. Complete el asistente de post-instalación de Virtualmin"
    echo
    echo -e "${YELLOW}⚠️  NOTAS IMPORTANTES:${NC}"
    echo "   • Cambie la contraseña por defecto después del primer acceso"
    echo "   • Configure SSL con certificados válidos para producción"
    echo "   • Revise la configuración de firewall según sus necesidades"
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
}

# Función principal
main() {
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${GREEN}🚀 INSTALACIÓN AUTOMÁTICA DE WEBMIN Y VIRTUALMIN${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    
    # Detectar sistema operativo
    detect_os
    
    # Verificar permisos
    check_root
    
    # Crear directorio de logs
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log "Iniciando instalación automática..."
    log "Sistema: $OS - $DISTRO"
    log "Log file: $LOG_FILE"
    
    # Ejecutar pasos de instalación
    install_dependencies
    configure_mysql
    install_webmin
    install_virtualmin
    configure_system_services
    configure_firewall
    verify_installation
    cleanup
    
    # Mostrar información final
    show_final_info
    
    log "🎉 Instalación completada exitosamente"
}

# Manejo de errores
trap 'log_error "Error en línea $LINENO. Código de salida: $?"; cleanup; exit 1' ERR

# Ejecutar función principal
main "$@"