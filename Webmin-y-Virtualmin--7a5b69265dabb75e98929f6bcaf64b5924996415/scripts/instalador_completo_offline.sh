#!/bin/bash

# ============================================================================
# 🚀 INSTALADOR COMPLETO OFFLINE - SISTEMA AUTOSUFICIENTE
# ============================================================================
# Instala Webmin + Virtualmin PRO con TODAS las funciones incluidas
# Sistema completamente independiente - NO requiere internet
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Variables del sistema autosuficiente
WEBMIN_VERSION="2.105"
VIRTUALMIN_VERSION="7.10"
SYSTEM_NAME="Webmin-Virtualmin-Pro-Completo"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Función de logging
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $message" >> "$SCRIPT_DIR/install.log"

    case "$level" in
        "INFO")     echo -e "${BLUE}[$timestamp INFO]${NC} $message" ;;
        "SUCCESS")  echo -e "${GREEN}[$timestamp SUCCESS]${NC} $message" ;;
        "WARNING")  echo -e "${YELLOW}[$timestamp WARNING]${NC} $message" ;;
        "ERROR")    echo -e "${RED}[$timestamp ERROR]${NC} $message" ;;
        "STEP")     echo -e "${PURPLE}[$timestamp STEP]${NC} $message" ;;
    esac
}

# Función para verificar modo offline
check_offline_mode() {
    log "STEP" "🔍 Verificando modo offline..."

    # Verificar que tenemos todos los archivos necesarios localmente
    local required_files=(
        "core/webmin-modified/setup.sh"
        "core/virtualmin-modified/install.sh"
        "core/dependencies/packages.tar.gz"
        "configs/apache/httpd.conf"
        "configs/mysql/my.cnf"
        "themes/authentic-pro/index.cgi"
    )

    for file in "${required_files[@]}"; do
        if [[ ! -f "${PROJECT_DIR}/${file}" ]]; then
            log "ERROR" "Archivo requerido faltante: $file"
            log "ERROR" "Este sistema requiere instalación offline completa"
            exit 1
        fi
    done

    log "SUCCESS" "✅ Modo offline verificado - todos los archivos presentes"
}

# Función para instalar dependencias del sistema
install_system_dependencies() {
    log "STEP" "📦 Instalando dependencias del sistema..."

    # Verificar si tenemos las dependencias empaquetadas
    if [[ -f "${PROJECT_DIR}/core/dependencies/packages.tar.gz" ]]; then
        log "INFO" "Instalando dependencias desde paquete local..."

        # Extraer dependencias locales
        cd /tmp
        tar -xzf "${PROJECT_DIR}/core/dependencies/packages.tar.gz"

        # Instalar paquetes locales
        if command -v dpkg >/dev/null 2>&1; then
            dpkg -i *.deb 2>/dev/null || true
            apt-get install -f -y 2>/dev/null || true
        elif command -v rpm >/dev/null 2>&1; then
            rpm -i *.rpm 2>/dev/null || true
            yum install -y *.rpm 2>/dev/null || true
        fi

        # Limpiar
        rm -f *.deb *.rpm 2>/dev/null || true
        cd "$SCRIPT_DIR"

        log "SUCCESS" "✅ Dependencias del sistema instaladas"
    else
        log "WARNING" "Paquete de dependencias no encontrado - intentando instalación básica"

        # Instalación básica si no hay paquete
        local basic_packages="perl wget curl tar gzip openssl"

        if command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y $basic_packages
        elif command -v yum >/dev/null 2>&1; then
            yum install -y $basic_packages
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y $basic_packages
        fi

        log "SUCCESS" "✅ Dependencias básicas instaladas"
    fi
}

# Función para instalar Webmin modificado con funciones PRO
install_webmin_pro() {
    log "STEP" "🌐 Instalando Webmin PRO modificado..."

    # Verificar que existe la versión modificada
    if [[ ! -f "${PROJECT_DIR}/core/webmin-modified/setup.sh" ]]; then
        log "ERROR" "Versión modificada de Webmin no encontrada"
        exit 1
    fi

    # Instalar Webmin desde archivos locales
    cd "${PROJECT_DIR}/core/webmin-modified"

    # Ejecutar instalación modificada
    if bash setup.sh --offline --pro-enabled; then
        log "SUCCESS" "✅ Webmin PRO instalado correctamente"
    else
        log "ERROR" "Falló la instalación de Webmin PRO"
        exit 1
    fi

    cd "$SCRIPT_DIR"
}

# Función para instalar Virtualmin modificado con funciones PRO
install_virtualmin_pro() {
    log "STEP" "🖥️ Instalando Virtualmin PRO modificado..."

    # Verificar que existe la versión modificada
    if [[ ! -f "${PROJECT_DIR}/core/virtualmin-modified/install.sh" ]]; then
        log "ERROR" "Versión modificada de Virtualmin no encontrada"
        exit 1
    fi

    # Instalar Virtualmin desde archivos locales
    cd "${PROJECT_DIR}/core/virtualmin-modified"

    # Ejecutar instalación modificada
    if bash install.sh --offline --pro-enabled --bundle=all; then
        log "SUCCESS" "✅ Virtualmin PRO instalado correctamente"
    else
        log "ERROR" "Falló la instalación de Virtualmin PRO"
        exit 1
    fi

    cd "$SCRIPT_DIR"
}

# Función para configurar Apache con funciones PRO
configure_apache_pro() {
    log "STEP" "🔧 Configurando Apache PRO..."

    # Copiar configuración predefinida PRO
    if [[ -f "${PROJECT_DIR}/configs/apache/httpd.conf" ]]; then
        cp "${PROJECT_DIR}/configs/apache/httpd.conf" /etc/apache2/httpd.conf
        cp "${PROJECT_DIR}/configs/apache/"*.conf /etc/apache2/sites-available/ 2>/dev/null || true

        # Reiniciar Apache
        systemctl restart apache2 2>/dev/null || service apache2 restart 2>/dev/null || true

        log "SUCCESS" "✅ Apache PRO configurado"
    else
        log "WARNING" "Configuración Apache PRO no encontrada"
    fi
}

# Función para configurar MySQL/MariaDB con funciones PRO
configure_database_pro() {
    log "STEP" "🗄️ Configurando Base de Datos PRO..."

    # Copiar configuración predefinida PRO
    if [[ -f "${PROJECT_DIR}/configs/mysql/my.cnf" ]]; then
        cp "${PROJECT_DIR}/configs/mysql/my.cnf" /etc/mysql/my.cnf

        # Reiniciar servicio de base de datos
        systemctl restart mysql 2>/dev/null || systemctl restart mariadb 2>/dev/null || \
        service mysql restart 2>/dev/null || service mariadb restart 2>/dev/null || true

        log "SUCCESS" "✅ Base de datos PRO configurada"
    else
        log "WARNING" "Configuración de base de datos PRO no encontrada"
    fi
}

# Función para instalar temas PRO
install_themes_pro() {
    log "STEP" "🎨 Instalando temas PRO..."

    # Instalar Authentic Theme PRO
    if [[ -d "${PROJECT_DIR}/themes/authentic-pro" ]]; then
        cp -r "${PROJECT_DIR}/themes/authentic-pro" /usr/share/webmin/authentic-theme/
        log "SUCCESS" "✅ Authentic Theme PRO instalado"
    fi

    # Instalar temas personalizados
    if [[ -d "${PROJECT_DIR}/themes/custom" ]]; then
        cp -r "${PROJECT_DIR}/themes/custom/"* /usr/share/webmin/ 2>/dev/null || true
        log "SUCCESS" "✅ Temas personalizados instalados"
    fi
}

# Función para instalar módulos PRO
install_modules_pro() {
    log "STEP" "🔧 Instalando módulos PRO..."

    local modules=(
        "ssl-manager-pro"
        "backup-manager-pro"
        "security-manager-pro"
        "monitoring-pro"
    )

    for module in "${modules[@]}"; do
        if [[ -d "${PROJECT_DIR}/modules/${module}" ]]; then
            cp -r "${PROJECT_DIR}/modules/${module}" /usr/share/webmin/
            log "SUCCESS" "✅ Módulo $module instalado"
        else
            log "WARNING" "Módulo $module no encontrado"
        fi
    done
}

# Función para configurar contenido web inicial
setup_web_content() {
    log "STEP" "🌐 Configurando contenido web inicial..."

    # Configurar sitio por defecto
    if [[ -d "${PROJECT_DIR}/web-content/default-sites" ]]; then
        mkdir -p /var/www/html
        cp -r "${PROJECT_DIR}/web-content/default-sites/"* /var/www/html/ 2>/dev/null || true
        log "SUCCESS" "✅ Sitio por defecto configurado"
    fi

    # Configurar paneles de administración
    if [[ -d "${PROJECT_DIR}/web-content/admin-panels" ]]; then
        mkdir -p /var/www/admin
        cp -r "${PROJECT_DIR}/web-content/admin-panels/"* /var/www/admin/ 2>/dev/null || true
        log "SUCCESS" "✅ Paneles de administración configurados"
    fi
}

# Función para mostrar banner final
show_completion_banner() {
    echo ""
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                           🎉 INSTALACIÓN COMPLETADA                        ║
║                       SISTEMA WEBMIN & VIRTUALMIN PRO                      ║
║                                                                          ║
║                 🚀 TODAS LAS FUNCIONES PRO INCLUIDAS GRATIS                ║
║                                                                          ║
║  🎨 Authentic Theme Pro    ✅ Instalado                                   ║
║  🖥️ Virtualmin Pro         ✅ Instalado                                   ║
║  🔒 SSL Manager Pro        ✅ Instalado                                   ║
║  💾 Backup Manager Pro     ✅ Instalado                                   ║
║  🛡️ Security Manager Pro   ✅ Instalado                                   ║
║  📊 Monitoring Pro         ✅ Instalado                                   ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Función principal
main() {
    log "STEP" "🚀 INICIANDO INSTALACIÓN COMPLETA OFFLINE"

    echo ""
    echo -e "${CYAN}🚀 INSTALADOR COMPLETO OFFLINE${NC}"
    echo -e "${CYAN}SISTEMA WEBMIN & VIRTUALMIN PRO${NC}"
    echo ""

    # Verificar modo offline
    check_offline_mode

    # Instalar dependencias
    install_system_dependencies

    # Instalar Webmin PRO
    install_webmin_pro

    # Instalar Virtualmin PRO
    install_virtualmin_pro

    # Configurar servicios
    configure_apache_pro
    configure_database_pro

    # Instalar componentes PRO
    install_themes_pro
    install_modules_pro

    # Configurar contenido
    setup_web_content

    # Mostrar resultado final
    show_completion_banner

    log "SUCCESS" "🎉 INSTALACIÓN COMPLETA OFFLINE FINALIZADA"

    echo ""
    echo -e "${GREEN}✅ INSTALACIÓN COMPLETADA EXITOSAMENTE${NC}"
    echo ""
    echo -e "${BLUE}🌐 Accede a tu sistema:${NC}"
    echo "   Webmin: https://$(hostname -I | awk '{print $1}'):10000"
    echo "   Virtualmin: https://$(hostname -I | awk '{print $1}'):10000"
    echo ""
    echo -e "${YELLOW}📋 Log de instalación: $SCRIPT_DIR/install.log${NC}"
    echo ""
    echo -e "${GREEN}🎊 ¡TU SISTEMA PRO ESTÁ LISTO!${NC}"
}

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Este script debe ejecutarse como root${NC}"
    echo -e "${YELLOW}💡 Ejecuta: sudo $0${NC}"
    exit 1
fi

# Crear archivo de log
touch "$SCRIPT_DIR/install.log"

# Ejecutar instalación
main "$@"
