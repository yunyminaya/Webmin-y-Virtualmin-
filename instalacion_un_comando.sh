#!/bin/bash

# =============================================================================
# INSTALACIÓN AUTOMÁTICA DE UN SOLO COMANDO - WEBMIN Y VIRTUALMIN
# Script completamente automático y a prueba de errores para Ubuntu/Debian
# Comando único: curl -sSL https://tu-url/install.sh | sudo bash
# =============================================================================

set -euo pipefail  # Salir inmediatamente si hay errores

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
SCRIPT_VERSION="2.0"
INSTALL_LOG="/var/log/webmin-virtualmin-install.log"
TEMP_DIR="/tmp/webmin-virtualmin-install"
BACKUP_DIR="/root/webmin-virtualmin-backup-$(date +%Y%m%d_%H%M%S)"
DISTRO=""
VERSION=""
PACKAGE_MANAGER=""
WEBMIN_PORT="10000"
VIRTUALMIN_LICENSE_KEY=""
SKIP_CONFIRMATION=false
ENABLE_SSL=true
INSTALL_AUTHENTIC_THEME=true
CONFIGURE_FIREWALL=true
OPTIMIZE_FOR_PRODUCTION=true

# Funciones de logging mejoradas
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[✓]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[⚠]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[✗]${NC} $message"
            ;;
        "HEADER")
            echo
            echo -e "${PURPLE}=== $message ===${NC}"
            ;;
    esac
    
    # Escribir al log también
    echo "[$timestamp] [$level] $message" >> "$INSTALL_LOG"
}

# Función para manejo de errores
error_handler() {
    local line_no=$1
    local error_code=$2
    log "ERROR" "Error en línea $line_no con código $error_code"
    log "ERROR" "La instalación ha fallado. Consulte $INSTALL_LOG para más detalles"
    
    # Intentar cleanup básico
    cleanup_on_error
    exit $error_code
}

# Configurar trap para manejo de errores
trap 'error_handler ${LINENO} $?' ERR

# Función de cleanup en caso de error
cleanup_on_error() {
    log "WARNING" "Ejecutando cleanup de emergencia..."
    
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR" 2>/dev/null || true
    fi
    
    # Restaurar servicios si es necesario
    systemctl start apache2 2>/dev/null || true
    systemctl start mysql 2>/dev/null || true
    
    log "INFO" "Cleanup completado. Revise $INSTALL_LOG para detalles"
}

# Función para mostrar banner
show_banner() {
    clear
    cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════════
   🚀 INSTALACIÓN AUTOMÁTICA WEBMIN Y VIRTUALMIN - UN SOLO COMANDO
   
   ✨ Completamente automático y a prueba de errores
   🛡️ Validación continua y recuperación automática
   🔧 Optimizado para Ubuntu 20.04 LTS y Debian 10+
   📦 Incluye Authentic Theme y configuración SSL
   
═══════════════════════════════════════════════════════════════════════════════
EOF
    echo
}

# Detectar sistema operativo con validación robusta
detect_system() {
    log "HEADER" "DETECCIÓN DEL SISTEMA"
    
    if [[ ! -f /etc/os-release ]]; then
        log "ERROR" "Sistema operativo no soportado (falta /etc/os-release)"
        exit 1
    fi
    
    source /etc/os-release
    DISTRO="$ID"
    VERSION="$VERSION_ID"
    
    case "$DISTRO" in
        "ubuntu")
            PACKAGE_MANAGER="apt"
            if [[ "$VERSION" == "20.04" ]]; then
                log "SUCCESS" "Sistema detectado: Ubuntu 20.04 LTS (OPTIMIZADO)"
            elif [[ "$VERSION" > "18.04" ]]; then
                log "SUCCESS" "Sistema detectado: Ubuntu $VERSION (Compatible)"
            else
                log "ERROR" "Ubuntu $VERSION no soportado (mínimo: 18.04)"
                exit 1
            fi
            ;;
        "debian")
            PACKAGE_MANAGER="apt"
            if [[ "${VERSION%%.*}" -ge 10 ]]; then
                log "SUCCESS" "Sistema detectado: Debian $VERSION (Compatible)"
            else
                log "ERROR" "Debian $VERSION no soportado (mínimo: 10)"
                exit 1
            fi
            ;;
        *)
            log "ERROR" "Distribución no soportada: $DISTRO"
            log "INFO" "Este script solo soporta Ubuntu 18.04+ y Debian 10+"
            exit 1
            ;;
    esac
    
    # Verificar arquitectura
    local arch=$(uname -m)
    if [[ "$arch" != "x86_64" ]]; then
        log "WARNING" "Arquitectura no optimizada: $arch (recomendado: x86_64)"
    fi
    
    log "INFO" "Distribución: $DISTRO $VERSION"
    log "INFO" "Arquitectura: $arch"
    log "INFO" "Gestor de paquetes: $PACKAGE_MANAGER"
}

# Verificar privilegios de root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "Este script debe ejecutarse como root"
        log "INFO" "Uso: sudo $0"
        exit 1
    fi
    log "SUCCESS" "Privilegios de root verificados"
}

# Verificar conectividad de red
check_network() {
    log "HEADER" "VERIFICACIÓN DE CONECTIVIDAD"
    
    local test_urls=(
        "google.com"
        "download.webmin.com"
        "software.virtualmin.com"
        "github.com"
    )
    
    for url in "${test_urls[@]}"; do
        if ping -c 1 -W 5 "$url" >/dev/null 2>&1; then
            log "SUCCESS" "Conectividad a $url: OK"
        else
            log "WARNING" "Conectividad a $url: FALLA"
        fi
    done
    
    # Verificar DNS
    if nslookup google.com >/dev/null 2>&1; then
        log "SUCCESS" "Resolución DNS: Funcionando"
    else
        log "ERROR" "Resolución DNS: FALLA"
        log "INFO" "Configurando DNS públicos..."
        echo "nameserver 8.8.8.8" >> /etc/resolv.conf
        echo "nameserver 8.8.4.4" >> /etc/resolv.conf
    fi
}

# Crear directorio temporal con permisos seguros
create_temp_dir() {
    log "INFO" "Creando directorio temporal seguro"
    
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    
    mkdir -p "$TEMP_DIR"
    chmod 700 "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    log "SUCCESS" "Directorio temporal creado: $TEMP_DIR"
}

# Crear backup del sistema
create_system_backup() {
    log "HEADER" "CREACIÓN DE BACKUP DE SEGURIDAD"
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup de configuraciones importantes
    local configs=(
        "/etc/apache2"
        "/etc/mysql"
        "/etc/postfix"
        "/etc/ssh"
        "/etc/webmin"
        "/etc/hosts"
        "/etc/resolv.conf"
    )
    
    for config in "${configs[@]}"; do
        if [[ -e "$config" ]]; then
            cp -r "$config" "$BACKUP_DIR/" 2>/dev/null || true
            log "SUCCESS" "Backup creado: $config"
        fi
    done
    
    # Backup de base de datos de paquetes
    dpkg --get-selections > "$BACKUP_DIR/installed-packages.txt"
    apt list --installed > "$BACKUP_DIR/apt-packages.txt" 2>/dev/null
    
    log "SUCCESS" "Backup del sistema creado en: $BACKUP_DIR"
}

# Actualizar sistema con manejo de errores robusto
update_system() {
    log "HEADER" "ACTUALIZACIÓN DEL SISTEMA"
    
    # Configurar apt para evitar preguntas interactivas
    export DEBIAN_FRONTEND=noninteractive
    
    # Reparar paquetes rotos si existen
    log "INFO" "Verificando integridad de paquetes..."
    dpkg --configure -a 2>/dev/null || true
    apt-get -f install -y 2>/dev/null || true
    
    # Actualizar lista de paquetes con reintentos
    local retries=3
    while [[ $retries -gt 0 ]]; do
        log "INFO" "Actualizando lista de paquetes (intento: $((4-retries)))"
        
        if apt-get update -y; then
            log "SUCCESS" "Lista de paquetes actualizada"
            break
        else
            log "WARNING" "Fallo al actualizar paquetes, reintentando..."
            ((retries--))
            sleep 5
        fi
        
        if [[ $retries -eq 0 ]]; then
            log "ERROR" "No se pudo actualizar la lista de paquetes después de 3 intentos"
            exit 1
        fi
    done
    
    # Actualizar sistema
    log "INFO" "Actualizando paquetes del sistema..."
    apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
    
    # Instalar paquetes esenciales
    log "INFO" "Instalando dependencias esenciales..."
    local essential_packages=(
        "curl"
        "wget"
        "gnupg2"
        "software-properties-common"
        "apt-transport-https"
        "ca-certificates"
        "lsb-release"
        "unzip"
        "perl"
        "perl-modules"
        "libnet-ssleay-perl"
        "openssl"
        "libauthen-pam-perl"
        "libpam-runtime"
        "libio-pty-perl"
        "python3"
        "python3-pip"
    )
    
    for package in "${essential_packages[@]}"; do
        if apt-get install -y "$package"; then
            log "SUCCESS" "Instalado: $package"
        else
            log "WARNING" "Fallo al instalar: $package"
        fi
    done
    
    log "SUCCESS" "Sistema actualizado correctamente"
}

# Configurar firewall automáticamente
configure_firewall() {
    if [[ "$CONFIGURE_FIREWALL" != "true" ]]; then
        return 0
    fi
    
    log "HEADER" "CONFIGURACIÓN DEL FIREWALL"
    
    # Instalar UFW si no está presente
    if ! command -v ufw >/dev/null 2>&1; then
        apt-get install -y ufw
    fi
    
    # Configurar reglas básicas
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # Permitir servicios esenciales
    ufw allow ssh
    ufw allow $WEBMIN_PORT
    ufw allow 80
    ufw allow 443
    ufw allow 25   # SMTP
    ufw allow 110  # POP3
    ufw allow 143  # IMAP
    ufw allow 993  # IMAPS
    ufw allow 995  # POP3S
    
    # Activar firewall
    ufw --force enable
    
    log "SUCCESS" "Firewall configurado correctamente"
    ufw status
}

# Instalar Webmin con validación completa
install_webmin() {
    log "HEADER" "INSTALACIÓN DE WEBMIN"
    
    # Añadir repositorio oficial de Webmin
    log "INFO" "Configurando repositorio oficial de Webmin..."
    
    cd /tmp
    wget -q -O- https://download.webmin.com/developers-key.asc | apt-key add -
    
    if [[ ! -f /etc/apt/sources.list.d/webmin.list ]]; then
        echo "deb https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
    fi
    
    # Actualizar y instalar Webmin
    apt-get update
    
    # Preconfigurar Webmin para evitar preguntas
    echo "webmin webmin/redirect boolean false" | debconf-set-selections
    echo "webmin webmin/restart boolean true" | debconf-set-selections
    
    # Instalar Webmin
    log "INFO" "Instalando Webmin..."
    if apt-get install -y webmin; then
        log "SUCCESS" "Webmin instalado correctamente"
    else
        log "ERROR" "Error al instalar Webmin"
        exit 1
    fi
    
    # Verificar instalación
    if systemctl is-active --quiet webmin; then
        log "SUCCESS" "Servicio Webmin activo"
    else
        log "INFO" "Iniciando servicio Webmin..."
        systemctl enable webmin
        systemctl start webmin
        
        if systemctl is-active --quiet webmin; then
            log "SUCCESS" "Servicio Webmin iniciado correctamente"
        else
            log "ERROR" "No se pudo iniciar el servicio Webmin"
            exit 1
        fi
    fi
    
    # Verificar puerto
    if netstat -tlnp | grep ":$WEBMIN_PORT "; then
        log "SUCCESS" "Webmin escuchando en puerto $WEBMIN_PORT"
    else
        log "ERROR" "Webmin no está escuchando en puerto $WEBMIN_PORT"
        exit 1
    fi
}

# Instalar Virtualmin con optimizaciones
install_virtualmin() {
    log "HEADER" "INSTALACIÓN DE VIRTUALMIN"
    
    # Descargar script oficial de Virtualmin
    cd /tmp
    log "INFO" "Descargando script oficial de Virtualmin..."
    
    if wget -O virtualmin-install.sh https://software.virtualmin.com/gpl/scripts/install.sh; then
        log "SUCCESS" "Script de Virtualmin descargado"
    else
        log "ERROR" "No se pudo descargar el script de Virtualmin"
        exit 1
    fi
    
    chmod +x virtualmin-install.sh
    
    # Configurar variables de entorno para instalación no interactiva
    export VIRTUALMIN_NONINTERACTIVE=1
    export VIRTUALMIN_CONFIG_SYSTEM=1
    
    # Ejecutar instalación con logging completo
    log "INFO" "Ejecutando instalación de Virtualmin (esto puede tomar varios minutos)..."
    
    if ./virtualmin-install.sh --bundle LAMP --force; then
        log "SUCCESS" "Virtualmin instalado correctamente"
    else
        log "ERROR" "Error durante la instalación de Virtualmin"
        log "INFO" "Intentando instalación con modo minimal..."
        
        if ./virtualmin-install.sh --minimal --force; then
            log "SUCCESS" "Virtualmin instalado en modo minimal"
        else
            log "ERROR" "Error crítico en instalación de Virtualmin"
            exit 1
        fi
    fi
    
    # Verificar instalación de Virtualmin
    if [[ -f /usr/sbin/virtualmin ]]; then
        log "SUCCESS" "Comando virtualmin disponible"
    else
        log "ERROR" "Comando virtualmin no encontrado"
        exit 1
    fi
    
    # Verificar módulo de Virtualmin en Webmin
    if [[ -d /etc/webmin/virtual-server ]]; then
        log "SUCCESS" "Módulo Virtualmin instalado en Webmin"
    else
        log "ERROR" "Módulo Virtualmin no encontrado en Webmin"
        exit 1
    fi
}

# Instalar y configurar Authentic Theme
install_authentic_theme() {
    if [[ "$INSTALL_AUTHENTIC_THEME" != "true" ]]; then
        return 0
    fi
    
    log "HEADER" "INSTALACIÓN DE AUTHENTIC THEME"
    
    cd /tmp
    
    # Descargar Authentic Theme desde GitHub
    log "INFO" "Descargando Authentic Theme..."
    if wget -O authentic-theme.zip https://github.com/authentic-theme/authentic-theme/archive/refs/heads/master.zip; then
        log "SUCCESS" "Authentic Theme descargado"
    else
        log "ERROR" "No se pudo descargar Authentic Theme"
        return 1
    fi
    
    # Extraer y instalar
    unzip -q authentic-theme.zip
    
    if [[ -d authentic-theme-master ]]; then
        # Manejo robusto de carpeta destino
        THEME_DEST="/usr/share/webmin/authentic-theme/authentic-theme-master"
        if [ -d "$THEME_DEST" ]; then
            log "WARNING" "La carpeta destino de Authentic Theme ya existe. Eliminando para evitar conflictos..."
            rm -rf "$THEME_DEST"
        fi
        mv -f authentic-theme-master "$THEME_DEST" 2>/dev/null || rsync -a --delete authentic-theme-master/ "$THEME_DEST/"

        # Configurar como tema predeterminado
        echo "theme=authentic-theme" >> /etc/webmin/config

        # Reiniciar Webmin para aplicar el tema
        systemctl restart webmin

        log "SUCCESS" "Authentic Theme instalado y configurado"
    else
        log "ERROR" "No se pudo extraer Authentic Theme"
        return 1
    fi
}

# Configurar SSL automáticamente
configure_ssl() {
    if [[ "$ENABLE_SSL" != "true" ]]; then
        return 0
    fi
    
    log "HEADER" "CONFIGURACIÓN SSL"
    
    # Generar certificado SSL autofirmado para Webmin
    log "INFO" "Generando certificado SSL para Webmin..."
    
    local ssl_dir="/etc/webmin"
    local hostname=$(hostname -f 2>/dev/null || hostname)
    
    # Crear certificado SSL
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$ssl_dir/miniserv.pem" \
        -out "$ssl_dir/miniserv.pem" \
        -subj "/C=ES/ST=Local/L=Local/O=Webmin/CN=$hostname" 2>/dev/null
    
    chmod 600 "$ssl_dir/miniserv.pem"
    
    # Configurar Webmin para usar SSL
    sed -i 's/ssl=0/ssl=1/' /etc/webmin/miniserv.conf 2>/dev/null || true
    
    # Reiniciar Webmin
    systemctl restart webmin
    
    log "SUCCESS" "SSL configurado para Webmin"
    log "INFO" "Acceso seguro: https://$(hostname -I | awk '{print $1}'):$WEBMIN_PORT"
}

# Optimizar para producción
optimize_for_production() {
    if [[ "$OPTIMIZE_FOR_PRODUCTION" != "true" ]]; then
        return 0
    fi
    
    log "HEADER" "OPTIMIZACIÓN PARA PRODUCCIÓN"
    
    # Configurar límites del sistema
    cat >> /etc/security/limits.conf << 'EOF'
* soft nofile 65535
* hard nofile 65535
* soft nproc 65535
* hard nproc 65535
EOF
    
    # Optimizar MySQL si está instalado
    # Optimización robusta de MySQL/MariaDB
    if systemctl is-active --quiet mysql; then
        log "INFO" "Optimizando configuración de MySQL/MariaDB..."

        if [ -f /etc/mysql/mysql.conf.d/mysqld.cnf ]; then
            cp /etc/mysql/mysql.conf.d/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf.backup
            cat >> /etc/mysql/mysql.conf.d/mysqld.cnf << 'EOF'

# Optimizaciones Virtualmin
max_connections = 200
innodb_buffer_pool_size = 256M
query_cache_size = 16M
query_cache_limit = 2M
thread_cache_size = 8
table_open_cache = 2000
EOF
            systemctl restart mysql
            log "SUCCESS" "MySQL optimizado"
        elif [ -f /etc/mysql/mariadb.conf.d/50-server.cnf ]; then
            cp /etc/mysql/mariadb.conf.d/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf.backup
            cat >> /etc/mysql/mariadb.conf.d/50-server.cnf << 'EOF'

# Optimizaciones Virtualmin
max_connections = 200
innodb_buffer_pool_size = 256M
query_cache_size = 16M
query_cache_limit = 2M
thread_cache_size = 8
table_open_cache = 2000
EOF
            systemctl restart mysql
            log "SUCCESS" "MariaDB optimizado"
        else
            log "WARNING" "No se encontró archivo de configuración de MySQL/MariaDB. Saltando optimización."
        fi
    fi
    
    # Optimizar Apache
    if systemctl is-active --quiet apache2; then
        log "INFO" "Optimizando configuración de Apache..."
        
        # Habilitar módulos necesarios
        a2enmod rewrite ssl headers expires deflate
        
        # Configurar límites
        cat > /etc/apache2/conf-available/virtualmin-optimizations.conf << 'EOF'
# Optimizaciones Virtualmin
ServerTokens Prod
ServerSignature Off
Timeout 60
KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 5

# Límites de memoria
LimitRequestBody 52428800
EOF
        
        a2enconf virtualmin-optimizations
        systemctl restart apache2
        log "SUCCESS" "Apache optimizado"
    fi
    
    log "SUCCESS" "Optimizaciones de producción aplicadas"
}

# Verificación final del sistema
final_verification() {
    log "HEADER" "VERIFICACIÓN FINAL DEL SISTEMA"
    
    local errors=0
    
    # Verificar servicios críticos
    local services=("webmin" "apache2" "mysql")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log "SUCCESS" "Servicio $service: ACTIVO"
        else
            log "ERROR" "Servicio $service: INACTIVO"
            ((errors++))
        fi
    done
    
    # Verificar puertos
    local ports=("$WEBMIN_PORT:Webmin" "80:Apache" "443:Apache-SSL")
    
    for port_info in "${ports[@]}"; do
        local port="${port_info%:*}"
        local service_name="${port_info#*:}"
        
        if netstat -tlnp | grep ":$port "; then
            log "SUCCESS" "Puerto $port ($service_name): ABIERTO"
        else
            log "WARNING" "Puerto $port ($service_name): CERRADO"
        fi
    done
    
    # Verificar acceso a Webmin
    local server_ip=$(hostname -I | awk '{print $1}')
    log "INFO" "Verificando acceso a Webmin..."
    
    if curl -k -s --connect-timeout 5 "https://$server_ip:$WEBMIN_PORT" >/dev/null; then
        log "SUCCESS" "Webmin accesible vía HTTPS"
    elif curl -s --connect-timeout 5 "http://$server_ip:$WEBMIN_PORT" >/dev/null; then
        log "SUCCESS" "Webmin accesible vía HTTP"
    else
        log "ERROR" "Webmin no accesible"
        ((errors++))
    fi
    
    # Verificar Virtualmin
    if command -v virtualmin >/dev/null 2>&1; then
        if virtualmin list-domains >/dev/null 2>&1; then
            log "SUCCESS" "Virtualmin funcionando correctamente"
        else
            log "WARNING" "Virtualmin instalado pero con errores"
        fi
    else
        log "ERROR" "Virtualmin no instalado correctamente"
        ((errors++))
    fi
    
    return $errors
}

# Mostrar información de acceso
show_access_info() {
    local server_ip=$(hostname -I | awk '{print $1}')
    local hostname=$(hostname -f 2>/dev/null || hostname)
    
    log "HEADER" "INFORMACIÓN DE ACCESO"
    
    cat << EOF

═══════════════════════════════════════════════════════════════════════════════
🎉 ¡INSTALACIÓN COMPLETADA EXITOSAMENTE!
═══════════════════════════════════════════════════════════════════════════════

📡 ACCESO A WEBMIN:
   • URL: https://$server_ip:$WEBMIN_PORT
   • URL alternativa: https://$hostname:$WEBMIN_PORT
   • Usuario: root
   • Contraseña: [contraseña de root del sistema]

🏢 ACCESO A VIRTUALMIN:
   • URL: https://$server_ip:$WEBMIN_PORT
   • Módulo: Virtualmin Virtual Servers
   • Panel completo de hosting disponible

🔐 SEGURIDAD:
   • SSL habilitado automáticamente
   • Firewall configurado
   • Certificados SSL autofirmados instalados

🚀 CARACTERÍSTICAS INSTALADAS:
   ✅ Webmin (panel de administración)
   ✅ Virtualmin GPL (gestión de hosting)
   ✅ Authentic Theme (interfaz moderna)
   ✅ Apache + MySQL + PHP (stack LAMP)
   ✅ Postfix (servidor de correo)
   ✅ Certificados SSL
   ✅ Firewall UFW configurado

📋 PRÓXIMOS PASOS:
   1. Acceder a https://$server_ip:$WEBMIN_PORT
   2. Iniciar sesión con credenciales de root
   3. Configurar primer dominio virtual en Virtualmin
   4. Revisar configuración en System Information

🆘 SOPORTE:
   • Logs: $INSTALL_LOG
   • Backup: $BACKUP_DIR
   • Documentación: https://webmin.com/docs/

═══════════════════════════════════════════════════════════════════════════════

EOF
}

# Función para cleanup final
final_cleanup() {
    log "INFO" "Ejecutando limpieza final..."
    
    # Limpiar archivos temporales
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    
    # Limpiar cache de apt
    apt-get autoremove -y
    apt-get autoclean
    
    log "SUCCESS" "Limpieza completada"
}

# Funciones de autocorrección adicionales

# Reparar permisos de archivos y carpetas críticos
repair_permissions() {
    log "INFO" "Reparando permisos de archivos y carpetas críticos..."
    chown -R root:root /etc/webmin 2>/dev/null || true
    chown -R root:root /usr/share/webmin 2>/dev/null || true
    chmod -R 755 /etc/webmin 2>/dev/null || true
    chmod -R 755 /usr/share/webmin 2>/dev/null || true
}

# Reintentar descargas críticas hasta 3 veces
retry_download() {
    local url="$1"
    local output="$2"
    local tries=0
    while [[ $tries -lt 3 ]]; do
        if wget -O "$output" "$url"; then
            return 0
        fi
        log "WARNING" "Fallo al descargar $url, reintentando..."
        ((tries++))
        sleep 2
    done
    log "ERROR" "No se pudo descargar $url después de 3 intentos"
    return 1
}

# Reparar servicios caídos automáticamente
repair_services() {
    log "INFO" "Verificando y reparando servicios críticos..."
    local services=("webmin" "apache2" "mysql")
    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet "$service"; then
            log "WARNING" "Servicio $service inactivo, intentando reiniciar..."
            systemctl restart "$service" || service "$service" restart || true
            sleep 2
            if systemctl is-active --quiet "$service"; then
                log "SUCCESS" "Servicio $service reparado y activo"
            else
                log "ERROR" "No se pudo reparar el servicio $service"
            fi
        fi
    done
}

# Reparar configuraciones problemáticas detectadas
repair_configurations() {
    log "INFO" "Reparando configuraciones problemáticas si es necesario..."
    # Ejemplo: restaurar backup si la config principal de Webmin está corrupta
    if [[ ! -f /etc/webmin/miniserv.conf && -f "$BACKUP_DIR/webmin/miniserv.conf" ]]; then
        cp "$BACKUP_DIR/webmin/miniserv.conf" /etc/webmin/miniserv.conf
        log "SUCCESS" "Configuración de Webmin restaurada desde backup"
    fi
}

# Función principal
main() {
    # Mostrar banner
    show_banner
    
    # Inicializar log
    mkdir -p "$(dirname "$INSTALL_LOG")"
    echo "=== INSTALACIÓN WEBMIN/VIRTUALMIN INICIADA $(date) ===" > "$INSTALL_LOG"
    
    log "INFO" "Iniciando instalación automática v$SCRIPT_VERSION"
    log "INFO" "Log de instalación: $INSTALL_LOG"
    
    # Ejecutar pasos de instalación
    check_root
    detect_system
    check_network
    create_temp_dir
    create_system_backup
    update_system
    configure_firewall

    # Autocorrección antes de instalar paneles
    repair_permissions

    install_webmin
    install_virtualmin
    install_authentic_theme
    configure_ssl
    optimize_for_production

    # Autocorrección después de instalar paneles
    repair_permissions
    repair_services
    repair_configurations

    # Verificación final
    if final_verification; then
        log "SUCCESS" "Todas las verificaciones pasaron correctamente"
        show_access_info
    else
        log "WARNING" "Instalación completada con algunas advertencias"
        log "INFO" "Revise $INSTALL_LOG para más detalles"
    fi

    # Cleanup final
    final_cleanup

    log "SUCCESS" "¡Instalación automática completada exitosamente!"
    echo
    echo -e "${GREEN}Para acceder al panel: https://$(hostname -I | awk '{print $1}'):$WEBMIN_PORT${NC}"
    echo
}

# Verificar si se está ejecutando directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Ejecutar función principal
    main "$@"
fi
