#!/bin/bash

# =============================================================================
# 🚀 INSTALACIÓN Y CONFIGURACIÓN DE MÚLTIPLES VERSIONES DE PHP
# =============================================================================
# Instala y configura múltiples versiones de PHP para servidores virtuales
# con configuraciones de seguridad óptimas para hosting
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="./logs/php_multi_version_install.log"
PHP_VERSIONS=("7.4" "8.0" "8.1" "8.2" "8.3")
DEFAULT_PHP_VERSION="8.1"

# Función de logging
php_log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    case "$level" in
        "INFO")     echo -e "${BLUE}[$timestamp INFO]${NC} $message" ;;
        "SUCCESS")  echo -e "${GREEN}[$timestamp SUCCESS]${NC} $message" ;;
        "WARNING")  echo -e "${YELLOW}[$timestamp WARNING]${NC} $message" ;;
        "ERROR")    echo -e "${RED}[$timestamp ERROR]${NC} $message" ;;
        "STEP")     echo -e "${PURPLE}[$timestamp STEP]${NC} $message" ;;
    esac
}

# Función para mostrar progreso
show_progress() {
    local current="$1"
    local total="$2"
    local description="$3"
    local percentage=$((current * 100 / total))
    local progress_bar=""

    for ((i=0; i<percentage/2; i++)); do
        progress_bar="${progress_bar}█"
    done
    for ((i=percentage/2; i<50; i++)); do
        progress_bar="${progress_bar}░"
    done

    echo -ne "\r${BLUE}[$current/$total]${NC} ${description} ${progress_bar} ${percentage}%"
}

# Función para verificar privilegios de root
check_root_privileges() {
    php_log "STEP" "Verificando privilegios de administrador..."

    if [[ $EUID -ne 0 ]]; then
        php_log "ERROR" "Este script debe ejecutarse como root (usa sudo)"
        php_log "INFO" "Ejemplo: sudo $0"
        exit 1
    fi

    php_log "SUCCESS" "Privilegios de root verificados"
}

# Función para detectar sistema operativo
detect_os() {
    php_log "STEP" "Detectando sistema operativo..."

    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=${NAME:-"Desconocido"}
        VER=${VERSION_ID:-""}

        php_log "INFO" "Sistema detectado: $OS $VER"

        case "$ID" in
            ubuntu|debian)
                php_log "SUCCESS" "Sistema compatible detectado: $ID"
                ;;
            *)
                php_log "ERROR" "Sistema operativo no soportado: $ID"
                php_log "INFO" "Solo se soportan Ubuntu y Debian"
                exit 1
                ;;
        esac
    else
        php_log "ERROR" "No se puede detectar el sistema operativo"
        exit 1
    fi
}

# Función para agregar repositorio de PHP
add_php_repository() {
    php_log "STEP" "Agregando repositorio de PHP (Ondřej Surý)..."

    # Verificar si el repositorio ya está agregado
    if [[ -f /etc/apt/sources.list.d/ondrej-ubuntu-php-*.list ]] || [[ -f /etc/apt/sources.list.d/ondrej-php-*.list ]]; then
        php_log "INFO" "Repositorio de PHP ya está configurado"
        return 0
    fi

    # Instalar software-properties-common si no está instalado
    if ! command -v add-apt-repository >/dev/null 2>&1; then
        apt-get update
        apt-get install -y software-properties-common
    fi

    # Agregar repositorio de Ondřej Surý
    if [[ "$ID" == "ubuntu" ]]; then
        add-apt-repository -y ppa:ondrej/php
    elif [[ "$ID" == "debian" ]]; then
        curl -sSL https://packages.sury.org/php/README.txt | bash -x
    fi

    # Actualizar lista de paquetes
    apt-get update

    php_log "SUCCESS" "Repositorio de PHP agregado correctamente"
}

# Función para instalar versión específica de PHP
install_php_version() {
    local version="$1"
    php_log "STEP" "Instalando PHP $version..."

    # Instalar PHP y módulos comunes
    local php_packages=(
        "php${version}"
        "php${version}-cli"
        "php${version}-common"
        "php${version}-curl"
        "php${version}-zip"
        "php${version}-gd"
        "php${version}-mysql"
        "php${version}-xml"
        "php${version}-mbstring"
        "php${version}-json"
        "php${version}-intl"
        "php${version}-bcmath"
        "php${version}-soap"
        "php${version}-readline"
        "php${version}-opcache"
        "php${version}-fpm"
        "php${version}-apache2"
    )

    # Instalar paquetes
    for package in "${php_packages[@]}"; do
        if apt-get install -y "$package" 2>/dev/null; then
            php_log "DEBUG" "Paquete instalado: $package"
        else
            php_log "WARNING" "No se pudo instalar: $package"
        fi
    done

    # Configurar PHP-FPM para esta versión
    configure_php_fpm "$version"

    # Configurar Apache para esta versión
    configure_apache_php "$version"

    php_log "SUCCESS" "PHP $version instalado y configurado"
}

# Función para configurar PHP-FPM
configure_php_fpm() {
    local version="$1"
    local fpm_config="/etc/php/${version}/fpm/php-fpm.conf"
    local pool_config="/etc/php/${version}/fpm/pool.d/www.conf"

    php_log "INFO" "Configurando PHP-FPM $version..."

    # Backup de configuraciones originales
    cp "$fpm_config" "${fpm_config}.backup" 2>/dev/null || true
    cp "$pool_config" "${pool_config}.backup" 2>/dev/null || true

    # Configuración segura de PHP-FPM
    cat >> "$fpm_config" << EOF

; CONFIGURACIÓN DE SEGURIDAD PARA SERVIDORES VIRTUALES
emergency_restart_threshold = 10
emergency_restart_interval = 1m
process_control_timeout = 10s
EOF

    # Configuración del pool www
    cat > "$pool_config" << EOF
[www]

user = www-data
group = www-data

listen = /run/php/php${version}-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.process_idle_timeout = 10s

security.limit_extensions = .php .php3 .php4 .php5 .php7

php_admin_value[disable_functions] = exec,system,shell_exec,passthru,proc_open,proc_close,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source
php_admin_value[expose_php] = Off
php_admin_value[allow_url_fopen] = Off
php_admin_value[allow_url_include] = Off
php_admin_value[memory_limit] = 256M
php_admin_value[max_execution_time] = 30
php_admin_value[upload_max_filesize] = 50M
php_admin_value[post_max_size] = 50M
php_admin_value[max_input_vars] = 1000
php_admin_value[session.save_path] = /var/lib/php/sessions
EOF

    # Crear directorio de sesiones si no existe
    mkdir -p /var/lib/php/sessions
    chown www-data:www-data /var/lib/php/sessions
    chmod 1733 /var/lib/php/sessions

    php_log "SUCCESS" "PHP-FPM $version configurado con seguridad"
}

# Función para configurar Apache con PHP
configure_apache_php() {
    local version="$1"

    php_log "INFO" "Configurando Apache para PHP $version..."

    # Deshabilitar módulos PHP existentes
    a2dismod php* 2>/dev/null || true

    # Habilitar módulo PHP para esta versión
    a2enmod "php${version}" 2>/dev/null || true

    # Configurar sitio por defecto para usar esta versión
    local apache_config="/etc/apache2/sites-available/000-default.conf"

    if [[ -f "$apache_config" ]]; then
        # Agregar configuración PHP si no existe
        if ! grep -q "SetHandler" "$apache_config"; then
            sed -i '/<\/VirtualHost>/i \
    <FilesMatch \.php$>\
        SetHandler application/x-httpd-php\
    </FilesMatch>' "$apache_config"
        fi
    fi

    php_log "SUCCESS" "Apache configurado para PHP $version"
}

# Función para configurar PHP.INI seguro
configure_php_ini() {
    local version="$1"
    local php_ini="/etc/php/${version}/apache2/php.ini"
    local php_cli_ini="/etc/php/${version}/cli/php.ini"

    php_log "INFO" "Configurando php.ini para PHP $version..."

    # Configuración segura para Apache
    if [[ -f "$php_ini" ]]; then
        # Backup
        cp "$php_ini" "${php_ini}.backup"

        # Configuraciones de seguridad
        sed -i 's/^disable_functions =/disable_functions = exec,system,shell_exec,passthru,proc_open,proc_close,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source,eval,assert,preg_replace/' "$php_ini"
        sed -i 's/^expose_php = On/expose_php = Off/' "$php_ini"
        sed -i 's/^allow_url_fopen = On/allow_url_fopen = Off/' "$php_ini"
        sed -i 's/^allow_url_include = On/allow_url_include = Off/' "$php_ini"
        sed -i 's/^display_errors = On/display_errors = Off/' "$php_ini"
        sed -i 's/^log_errors = Off/log_errors = On/' "$php_ini"
        sed -i 's|^error_log =.*|error_log = /var/log/php/php'"${version}"'_error.log|' "$php_ini"

        # Configuraciones de rendimiento y límites
        sed -i 's/^memory_limit = .*/memory_limit = 256M/' "$php_ini"
        sed -i 's/^max_execution_time = .*/max_execution_time = 30/' "$php_ini"
        sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 50M/' "$php_ini"
        sed -i 's/^post_max_size = .*/post_max_size = 50M/' "$php_ini"
        sed -i 's/^max_input_vars = .*/max_input_vars = 1000/' "$php_ini"
    fi

    # Configuración CLI (menos restrictiva)
    if [[ -f "$php_cli_ini" ]]; then
        cp "$php_cli_ini" "${php_cli_ini}.backup"
        sed -i 's/^memory_limit = .*/memory_limit = 512M/' "$php_cli_ini"
        sed -i 's/^max_execution_time = .*/max_execution_time = 0/' "$php_cli_ini"
    fi

    # Crear directorio de logs
    mkdir -p "/var/log/php"
    chown www-data:www-data "/var/log/php"

    php_log "SUCCESS" "php.ini configurado con seguridad para PHP $version"
}

# Función para instalar y configurar múltiples versiones de PHP
install_multiple_php_versions() {
    php_log "STEP" "Instalando múltiples versiones de PHP..."

    local total_versions=${#PHP_VERSIONS[@]}
    local current_version=0

    for version in "${PHP_VERSIONS[@]}"; do
        ((current_version++))
        show_progress "$current_version" "$total_versions" "Instalando PHP $version..."

        # Instalar versión
        install_php_version "$version"

        # Configurar php.ini
        configure_php_ini "$version"

        echo # Nueva línea para progreso
    done

    # Establecer versión por defecto
    update_alternatives_php "$DEFAULT_PHP_VERSION"

    php_log "SUCCESS" "Todas las versiones de PHP instaladas y configuradas"
}

# Función para configurar alternativas de PHP
update_alternatives_php() {
    local default_version="$1"

    php_log "INFO" "Estableciendo PHP $default_version como versión por defecto..."

    # Configurar alternativas para CLI
    update-alternatives --set php "/usr/bin/php${default_version}" 2>/dev/null || true

    # Configurar Apache para usar la versión por defecto
    a2dismod php* 2>/dev/null || true
    a2enmod "php${default_version}" 2>/dev/null || true

    php_log "SUCCESS" "PHP $default_version establecido como versión por defecto"
}

# Función para crear script de cambio de versión PHP
create_php_switcher() {
    php_log "STEP" "Creando script para cambiar versiones de PHP..."

    cat > /usr/local/bin/switch_php_version << 'EOF'
#!/bin/bash

# Script para cambiar la versión de PHP por defecto
# Uso: switch_php_version 8.1

if [[ $EUID -ne 0 ]]; then
    echo "Este script debe ejecutarse como root"
    exit 1
fi

VERSION="$1"

if [[ -z "$VERSION" ]]; then
    echo "Uso: $0 <version>"
    echo "Versiones disponibles:"
    ls /etc/php/ | grep -E '^[0-9]+\.[0-9]+$'
    exit 1
fi

if [[ ! -d "/etc/php/${VERSION}" ]]; then
    echo "Versión PHP ${VERSION} no está instalada"
    exit 1
fi

# Cambiar alternativa CLI
update-alternatives --set php "/usr/bin/php${VERSION}"

# Cambiar módulo Apache
a2dismod php* 2>/dev/null || true
a2enmod "php${VERSION}"

# Reiniciar servicios
systemctl restart apache2
systemctl restart php${VERSION}-fpm

echo "PHP ${VERSION} establecido como versión por defecto"
EOF

    chmod +x /usr/local/bin/switch_php_version

    php_log "SUCCESS" "Script switch_php_version creado"
}

# Función para configurar Virtualmin para múltiples versiones PHP
configure_virtualmin_php() {
    php_log "STEP" "Configurando Virtualmin para múltiples versiones PHP..."

    # Verificar si Virtualmin está instalado
    if [[ ! -d "/etc/virtualmin" ]]; then
        php_log "WARNING" "Virtualmin no está instalado, omitiendo configuración específica"
        return 0
    fi

    # Configurar versiones PHP disponibles en Virtualmin
    local virtualmin_config="/etc/virtualmin/config"

    if [[ -f "$virtualmin_config" ]]; then
        # Agregar configuración de PHP múltiple
        cat >> "$virtualmin_config" << EOF

# CONFIGURACIÓN DE MÚLTIPLES VERSIONES PHP
available_php_versions=7.4,8.0,8.1,8.2,8.3
default_php_version=$DEFAULT_PHP_VERSION
php_fpm_socket_prefix=/run/php/php
EOF

        php_log "SUCCESS" "Virtualmin configurado para múltiples versiones PHP"
    fi
}

# Función para instalar herramientas adicionales para PHP
install_php_tools() {
    php_log "STEP" "Instalando herramientas adicionales para PHP..."

    # Instalar Composer
    if ! command -v composer >/dev/null 2>&1; then
        curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
        php_log "SUCCESS" "Composer instalado"
    fi

    # Instalar WP-CLI
    if ! command -v wp >/dev/null 2>&1; then
        curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        chmod +x wp-cli.phar
        mv wp-cli.phar /usr/local/bin/wp
        php_log "SUCCESS" "WP-CLI instalado"
    fi

    # Instalar Drush (para Drupal)
    if ! command -v drush >/dev/null 2>&1; then
        wget -O drush.phar https://github.com/drush-ops/drush-launcher/releases/latest/download/drush.phar
        chmod +x drush.phar
        mv drush.phar /usr/local/bin/drush
        php_log "SUCCESS" "Drush instalado"
    fi
}

# Función para mostrar información final
show_final_info() {
    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                     🎉 PHP MULTI-VERSIÓN INSTALADO                          ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo

    echo -e "${GREEN}✅ VERSIONES DE PHP INSTALADAS:${NC}"
    for version in "${PHP_VERSIONS[@]}"; do
        if [[ -d "/etc/php/${version}" ]]; then
            echo -e "   ✅ PHP ${version} - $(php${version} --version | head -1 | cut -d' ' -f2)"
        fi
    done
    echo

    echo -e "${GREEN}✅ CONFIGURACIÓN DE SEGURIDAD:${NC}"
    echo "   🔒 Funciones peligrosas deshabilitadas"
    echo "   🚫 Exposición de PHP deshabilitada"
    echo "   🛡️ Configuración segura de límites"
    echo "   📊 Logs de errores habilitados"
    echo

    echo -e "${BLUE}🔧 HERRAMIENTAS INSTALADAS:${NC}"
    echo "   📦 Composer - Gestor de dependencias PHP"
    echo "   🐘 WP-CLI - Herramientas para WordPress"
    echo "   🦫 Drush - Herramientas para Drupal"
    echo

    echo -e "${PURPLE}📋 COMANDOS ÚTILES:${NC}"
    echo "   🔄 Cambiar versión PHP: switch_php_version <version>"
    echo "   📊 Ver versiones: ls /etc/php/"
    echo "   🔍 Ver configuración: php -i"
    echo

    echo -e "${YELLOW}🌐 CONFIGURACIÓN PARA SERVIDORES VIRTUALES:${NC}"
    echo "   ✅ PHP-FPM configurado para cada versión"
    echo "   ✅ Pools seguros con límites apropiados"
    echo "   ✅ Virtualmin configurado para múltiples PHP"
    echo "   ✅ Apache configurado para compatibilidad"
    echo

    echo -e "${GREEN}🎊 ¡PHP MULTI-VERSIÓN LISTO PARA SERVIDORES VIRTUALES!${NC}"
    echo
}

# Función principal
main() {
    echo
    echo -e "${CYAN}🚀 INSTALACIÓN DE MÚLTIPLES VERSIONES DE PHP${NC}"
    echo -e "${CYAN}PARA SERVIDORES VIRTUALES CON SEGURIDAD AVANZADA${NC}"
    echo

    # Crear directorio de logs
    mkdir -p "$(dirname "$LOG_FILE")"

    local total_steps=8
    local current_step=0

    # Ejecutar instalación paso a paso
    ((current_step++))
    show_progress "$current_step" "$total_steps" "Verificando privilegios..."
    check_root_privileges

    ((current_step++))
    show_progress "$current_step" "$total_steps" "Detectando SO..."
    detect_os

    ((current_step++))
    show_progress "$current_step" "$total_steps" "Agregando repositorio..."
    add_php_repository

    ((current_step++))
    show_progress "$current_step" "$total_steps" "Instalando versiones PHP..."
    install_multiple_php_versions

    ((current_step++))
    show_progress "$current_step" "$total_steps" "Creando switcher..."
    create_php_switcher

    ((current_step++))
    show_progress "$current_step" "$total_steps" "Configurando Virtualmin..."
    configure_virtualmin_php

    ((current_step++))
    show_progress "$current_step" "$total_steps" "Instalando herramientas..."
    install_php_tools

    ((current_step++))
    show_progress "$current_step" "$total_steps" "Reiniciando servicios..."
    systemctl restart apache2 2>/dev/null || true
    for version in "${PHP_VERSIONS[@]}"; do
        systemctl restart "php${version}-fpm" 2>/dev/null || true
    done

    echo # Nueva línea final
    show_final_info

    php_log "SUCCESS" "Instalación completa de PHP multi-versión finalizada"
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi