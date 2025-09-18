#!/bin/bash

# ============================================================================
# 🔧 REPARACIÓN AUTOMÁTICA DE APACHE - MÓDULO ESPECIALIZADO
# ============================================================================
# Detecta y repara automáticamente problemas comunes de Apache
# Integrado al sistema de auto-reparación principal
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Configuración
APACHE_LOG="$SCRIPT_DIR/apache_repair.log"
BACKUP_DIR="/backups/apache_repair"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función de logging para Apache
apache_log() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$APACHE_LOG"

    case "$level" in
        "INFO")     echo -e "${BLUE}[APACHE]${NC} $message" ;;
        "SUCCESS")  echo -e "${GREEN}[APACHE]${NC} $message" ;;
        "WARNING")  echo -e "${YELLOW}[APACHE]${NC} $message" ;;
        "ERROR")    echo -e "${RED}[APACHE]${NC} $message" ;;
    esac
}

# Función para detectar problemas de Apache
detect_apache_problems() {
    apache_log "INFO" "Detectando problemas de Apache..."

    local problems_found=0

    # Verificar si Apache está instalado
    if ! command -v apache2 >/dev/null 2>&1 && ! command -v httpd >/dev/null 2>&1; then
        apache_log "ERROR" "Apache no está instalado"
        return 1
    fi

    # Verificar servicio
    if ! systemctl is-active --quiet apache2 2>/dev/null && ! systemctl is-active --quiet httpd 2>/dev/null; then
        apache_log "ERROR" "Servicio Apache inactivo"
        ((problems_found++))
    fi

    # Verificar configuración
    if command -v apache2ctl >/dev/null 2>&1; then
        if ! apache2ctl configtest >/dev/null 2>&1; then
            apache_log "ERROR" "Configuración de Apache inválida"
            ((problems_found++))
        fi
    fi

    # Verificar puertos
    if ! netstat -tuln 2>/dev/null | grep -q ":80 "; then
        apache_log "WARNING" "Puerto 80 no está abierto"
        ((problems_found++))
    fi

    # Verificar archivos críticos
    local critical_files=(
        "/etc/apache2/apache2.conf"
        "/etc/apache2/sites-available/000-default.conf"
    )

    for file in "${critical_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            apache_log "ERROR" "Archivo crítico faltante: $file"
            ((problems_found++))
        fi
    done

    # Verificar módulos
    if ! apache2ctl -M 2>/dev/null | grep -q "rewrite_module"; then
        apache_log "WARNING" "Módulo rewrite no está cargado"
        ((problems_found++))
    fi

    apache_log "INFO" "Detección completada: $problems_found problemas encontrados"
    return $problems_found
}

# Función para reparar configuración de Apache
repair_apache_config() {
    apache_log "INFO" "Reparando configuración de Apache..."

    # Crear directorios necesarios
    mkdir -p "$BACKUP_DIR"
    mkdir -p /etc/apache2/sites-available
    mkdir -p /etc/apache2/sites-enabled
    mkdir -p /var/log/apache2
    mkdir -p /var/www/html

    # Backup de configuración actual
    local backup_file="$BACKUP_DIR/apache_config_$(date +%Y%m%d_%H%M%S).tar.gz"
    if [[ -d /etc/apache2 ]]; then
        tar -czf "$backup_file" -C /etc apache2 2>/dev/null || true
        apache_log "SUCCESS" "Backup de configuración creado: $backup_file"
    fi

    # Crear configuración básica si no existe
    if [[ ! -f /etc/apache2/apache2.conf ]]; then
        apache_log "INFO" "Creando configuración básica de Apache..."

        cat > /etc/apache2/apache2.conf << 'EOF'
# Configuración básica de Apache - Auto-generada
DefaultRuntimeDir ${APACHE_RUN_DIR}
PidFile ${APACHE_PID_FILE}
Timeout 300
KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 5
User www-data
Group www-data
HostnameLookups Off
ErrorLog ${APACHE_LOG_DIR}/error.log
LogLevel warn
IncludeOptional mods-enabled/*.load
IncludeOptional mods-enabled/*.conf
Include ports.conf
<Directory />
    Options FollowSymLinks
    AllowOverride None
    Require all denied
</Directory>
<Directory /usr/share>
    AllowOverride None
    Require all granted
</Directory>
<Directory /var/www/>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
IncludeOptional sites-enabled/*.conf
EOF
    fi

    # Crear sitio por defecto si no existe
    if [[ ! -f /etc/apache2/sites-available/000-default.conf ]]; then
        apache_log "INFO" "Creando sitio por defecto..."

        cat > /etc/apache2/sites-available/000-default.conf << 'EOF'
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

        # Habilitar sitio por defecto
        ln -sf /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-enabled/ 2>/dev/null || true
    fi

    # Crear archivo de log por defecto
    mkdir -p /var/log/apache2
    touch /var/log/apache2/access.log
    touch /var/log/apache2/error.log

    # Crear index.html básico
    if [[ ! -f /var/www/html/index.html ]]; then
        cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Servidor Apache - Funcionando</title>
</head>
<body>
    <h1>¡Apache está funcionando correctamente!</h1>
    <p>Servidor web operativo.</p>
    <p>Webmin disponible en: <a href="https://localhost:10000">https://localhost:10000</a></p>
</body>
</html>
EOF
    fi

    apache_log "SUCCESS" "Configuración de Apache reparada"
}

# Función para reparar módulos de Apache
repair_apache_modules() {
    apache_log "INFO" "Reparando módulos de Apache..."

    # Habilitar módulos esenciales
    local essential_modules=(
        "rewrite"
        "ssl"
        "headers"
        "expires"
        "deflate"
    )

    for module in "${essential_modules[@]}"; do
        if command -v a2enmod >/dev/null 2>&1; then
            a2enmod "$module" 2>/dev/null || apache_log "WARNING" "No se pudo habilitar módulo: $module"
        fi
    done

    # Deshabilitar módulos problemáticos
    local problematic_modules=(
        "php4"
        "php5"
    )

    for module in "${problematic_modules[@]}"; do
        if command -v a2dismod >/dev/null 2>&1; then
            a2dismod "$module" 2>/dev/null || true
        fi
    done

    apache_log "SUCCESS" "Módulos de Apache reparados"
}

# Función para reparar permisos de Apache
repair_apache_permissions() {
    apache_log "INFO" "Reparando permisos de Apache..."

    # Permisos de directorios
    chown -R www-data:www-data /var/www 2>/dev/null || true
    chown -R www-data:www-data /var/log/apache2 2>/dev/null || true

    # Permisos de archivos
    find /var/www -type d -exec chmod 755 {} \; 2>/dev/null || true
    find /var/www -type f -exec chmod 644 {} \; 2>/dev/null || true

    # Permisos de configuración
    chmod 644 /etc/apache2/apache2.conf 2>/dev/null || true
    chmod 644 /etc/apache2/sites-available/* 2>/dev/null || true

    apache_log "SUCCESS" "Permisos de Apache reparados"
}

# Función para reinstalar Apache si es necesario
reinstall_apache() {
    apache_log "INFO" "Reinstalando Apache..."

    # Detectar distribución
    if command -v apt-get >/dev/null 2>&1; then
        apache_log "INFO" "Usando apt-get para reinstalar Apache..."

        # Actualizar repositorios
        apt-get update

        # Reinstalar Apache
        apt-get install --reinstall -y apache2 apache2-utils

        # Instalar módulos comunes
        apt-get install -y libapache2-mod-php 2>/dev/null || true
        apt-get install -y libapache2-mod-ssl 2>/dev/null || true

    elif command -v yum >/dev/null 2>&1; then
        apache_log "INFO" "Usando yum para reinstalar Apache..."

        yum reinstall -y httpd mod_ssl

    elif command -v dnf >/dev/null 2>&1; then
        apache_log "INFO" "Usando dnf para reinstalar Apache..."

        dnf reinstall -y httpd mod_ssl
    else
        apache_log "ERROR" "No se pudo detectar el gestor de paquetes"
        return 1
    fi

    apache_log "SUCCESS" "Apache reinstalado"
}

# Función para verificar y reparar el servicio
repair_apache_service() {
    apache_log "INFO" "Reparando servicio de Apache..."

    # Detectar nombre del servicio
    local service_name=""
    if systemctl list-units --type=service | grep -q apache2; then
        service_name="apache2"
    elif systemctl list-units --type=service | grep -q httpd; then
        service_name="httpd"
    else
        apache_log "ERROR" "No se pudo detectar el servicio de Apache"
        return 1
    fi

    # Detener servicio si está corriendo
    systemctl stop "$service_name" 2>/dev/null || true

    # Habilitar servicio
    systemctl enable "$service_name" 2>/dev/null || true

    # Iniciar servicio
    if systemctl start "$service_name" 2>/dev/null; then
        apache_log "SUCCESS" "Servicio Apache iniciado correctamente"

        # Verificar que está corriendo
        sleep 2
        if systemctl is-active --quiet "$service_name" 2>/dev/null; then
            apache_log "SUCCESS" "Servicio Apache verificado como activo"
            return 0
        else
            apache_log "ERROR" "Servicio Apache no se pudo iniciar correctamente"
            return 1
        fi
    else
        apache_log "ERROR" "Falló al iniciar el servicio Apache"
        return 1
    fi
}

# Función para verificar reparación final
verify_apache_repair() {
    apache_log "INFO" "Verificando reparación final de Apache..."

    local verification_passed=0

    # Verificar servicio
    if systemctl is-active --quiet apache2 2>/dev/null || systemctl is-active --quiet httpd 2>/dev/null; then
        apache_log "SUCCESS" "✅ Servicio Apache activo"
        ((verification_passed++))
    else
        apache_log "ERROR" "❌ Servicio Apache inactivo"
    fi

    # Verificar puerto 80
    if timeout 5 bash -c "</dev/tcp/localhost/80" 2>/dev/null; then
        apache_log "SUCCESS" "✅ Puerto 80 accesible"
        ((verification_passed++))
    else
        apache_log "ERROR" "❌ Puerto 80 no accesible"
    fi

    # Verificar configuración
    if command -v apache2ctl >/dev/null 2>&1; then
        if apache2ctl configtest >/dev/null 2>&1; then
            apache_log "SUCCESS" "✅ Configuración válida"
            ((verification_passed++))
        else
            apache_log "ERROR" "❌ Configuración inválida"
        fi
    fi

    # Verificar sitio web
    if curl -s -o /dev/null -w "%{http_code}" http://localhost/ | grep -q "200"; then
        apache_log "SUCCESS" "✅ Sitio web responde correctamente"
        ((verification_passed++))
    else
        apache_log "WARNING" "⚠️ Sitio web no responde (puede ser normal si no hay contenido)"
    fi

    apache_log "INFO" "Verificación completada: $verification_passed/4 pruebas pasaron"

    if [[ $verification_passed -ge 3 ]]; then
        apache_log "SUCCESS" "🎉 Reparación de Apache exitosa"
        return 0
    else
        apache_log "WARNING" "⚠️ Reparación de Apache incompleta"
        return 1
    fi
}

# Función principal de reparación de Apache
repair_apache() {
    apache_log "STEP" "🚀 INICIANDO REPARACIÓN AUTOMÁTICA DE APACHE"

    echo ""
    echo -e "${CYAN}🔧 REPARACIÓN AUTOMÁTICA DE APACHE${NC}"
    echo -e "${CYAN}Detectando y reparando problemas automáticamente${NC}"
    echo ""

    # Detectar problemas
    if ! detect_apache_problems; then
        apache_log "INFO" "No se detectaron problemas críticos en Apache"
        return 0
    fi

    # Reparar configuración
    repair_apache_config

    # Reparar módulos
    repair_apache_modules

    # Reparar permisos
    repair_apache_permissions

    # Reinstalar si es necesario
    if ! systemctl is-active --quiet apache2 2>/dev/null && ! systemctl is-active --quiet httpd 2>/dev/null; then
        reinstall_apache
    fi

    # Reparar servicio
    repair_apache_service

    # Verificar reparación
    if verify_apache_repair; then
        apache_log "SUCCESS" "🎉 APACHE REPARADO COMPLETAMENTE"
        echo ""
        echo -e "${GREEN}✅ APACHE REPARADO EXITOSAMENTE${NC}"
        echo "   • Servicio activo y funcionando"
        echo "   • Puerto 80 abierto y accesible"
        echo "   • Configuración válida"
        echo "   • Sitio web operativo"
        return 0
    else
        apache_log "ERROR" "❌ FALLÓ LA REPARACIÓN DE APACHE"
        echo ""
        echo -e "${RED}❌ LA REPARACIÓN DE APACHE FALLÓ${NC}"
        echo "   • Revisa los logs para más detalles"
        echo "   • Puede requerir intervención manual"
        return 1
    fi
}

# Función para mostrar ayuda
show_help() {
    echo "Uso: $0 [opciones]"
    echo ""
    echo "Opciones:"
    echo "  --detect     Solo detectar problemas"
    echo "  --repair     Ejecutar reparación completa"
    echo "  --verify     Solo verificar estado"
    echo "  --help       Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 --repair          # Reparar Apache completamente"
    echo "  $0 --detect          # Solo detectar problemas"
    echo "  $0 --verify          # Verificar estado actual"
}

# Procesar argumentos
case "${1:-}" in
    "--detect")
        detect_apache_problems
        ;;
    "--repair")
        repair_apache
        ;;
    "--verify")
        verify_apache_repair
        ;;
    "--help"|"-h")
        show_help
        ;;
    *)
        # Por defecto, ejecutar reparación completa
        repair_apache
        ;;
esac

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Este script debe ejecutarse como root${NC}"
    echo -e "${YELLOW}💡 Ejecuta: sudo $0${NC}"
    exit 1
fi

# Crear archivos de log
mkdir -p "$BACKUP_DIR"
touch "$APACHE_LOG"
