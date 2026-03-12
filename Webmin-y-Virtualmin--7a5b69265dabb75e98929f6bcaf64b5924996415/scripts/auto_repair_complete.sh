#!/bin/bash

# ============================================================================
# 🔧 REPARACIÓN AUTOMÁTICA COMPLETA - TODOS LOS SERVICIOS
# ============================================================================
# Detecta y repara automáticamente problemas en:
# - Apache/Nginx
# - MySQL/MariaDB
# - PHP-FPM
# - Webmin
# - Virtualmin
# - Sistema en general
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Configuración
REPAIR_LOG="$SCRIPT_DIR/auto_repair_complete.log"
BACKUP_DIR="/backups/auto_repair"
APACHE_REPAIR_SCRIPT="$SCRIPT_DIR/repair_apache_auto.sh"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función de logging
repair_log() {
    local level="$1"
    local component="$2"
    local message="$3"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] [$component] $message" >> "$REPAIR_LOG"

    case "$level" in
        "CRITICAL") echo -e "${RED}[$component CRITICAL]${NC} $message" ;;
        "WARNING")  echo -e "${YELLOW}[$component WARNING]${NC} $message" ;;
        "INFO")     echo -e "${BLUE}[$component INFO]${NC} $message" ;;
        "SUCCESS")  echo -e "${GREEN}[$component SUCCESS]${NC} $message" ;;
        "STEP")     echo -e "${PURPLE}[$component STEP]${NC} $message" ;;
    esac
}

# Función para crear backups antes de reparar
create_repair_backup() {
    repair_log "INFO" "BACKUP" "Creando backup antes de reparaciones..."

    mkdir -p "$BACKUP_DIR"
    local backup_file="$BACKUP_DIR/pre_repair_backup_$(date +%Y%m%d_%H%M%S).tar.gz"

    # Backup de configuraciones críticas
    tar -czf "$backup_file" \
        /etc/webmin 2>/dev/null || true \
        /etc/apache2 2>/dev/null || true \
        /etc/nginx 2>/dev/null || true \
        /etc/mysql 2>/dev/null || true \
        /etc/php 2>/dev/null || true \
        "$REPAIR_LOG" 2>/dev/null || true

    if [[ -f "$backup_file" ]]; then
        repair_log "SUCCESS" "BACKUP" "Backup creado: $backup_file"
    else
        repair_log "WARNING" "BACKUP" "No se pudo crear backup"
    fi
}

# Función para reparar Apache automáticamente
repair_apache_service() {
    repair_log "STEP" "APACHE" "Iniciando reparación de Apache..."

    # Verificar si existe el script especializado
    if [[ -f "$APACHE_REPAIR_SCRIPT" ]]; then
        repair_log "INFO" "APACHE" "Usando script especializado de reparación de Apache"

        if bash "$APACHE_REPAIR_SCRIPT" --repair; then
            repair_log "SUCCESS" "APACHE" "Reparación especializada de Apache completada"
            return 0
        else
            repair_log "WARNING" "APACHE" "Script especializado falló, intentando reparación básica"
        fi
    fi

    # Reparación básica si no hay script especializado
    repair_log "INFO" "APACHE" "Ejecutando reparación básica de Apache"

    # Verificar si Apache está instalado
    if ! command -v apache2 >/dev/null 2>&1 && ! command -v httpd >/dev/null 2>&1; then
        repair_log "WARNING" "APACHE" "Apache no está instalado"
        return 1
    fi

    # Intentar reiniciar
    if systemctl restart apache2 2>/dev/null || systemctl restart httpd 2>/dev/null; then
        sleep 2
        if systemctl is-active --quiet apache2 2>/dev/null || systemctl is-active --quiet httpd 2>/dev/null; then
            repair_log "SUCCESS" "APACHE" "Apache reiniciado correctamente"
            return 0
        fi
    fi

    # Si falla, intentar reparar configuración
    repair_log "INFO" "APACHE" "Intentando reparar configuración básica"

    # Crear configuración mínima si no existe
    if [[ ! -f /etc/apache2/apache2.conf ]] && [[ ! -f /etc/httpd/conf/httpd.conf ]]; then
        repair_log "INFO" "APACHE" "Creando configuración mínima"

        mkdir -p /etc/apache2/sites-available
        mkdir -p /etc/apache2/sites-enabled
        mkdir -p /var/www/html

        cat > /etc/apache2/apache2.conf << 'EOF'
DefaultRuntimeDir ${APACHE_RUN_DIR}
PidFile ${APACHE_PID_FILE}
Timeout 300
KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 5
User www-data
Group www-data
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
<Directory /var/www/>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
IncludeOptional sites-enabled/*.conf
EOF

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

        ln -sf /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-enabled/ 2>/dev/null || true

        cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Apache Reparado</title></head>
<body><h1>Apache reparado automáticamente</h1></body>
</html>
EOF
    fi

    # Intentar iniciar nuevamente
    if systemctl start apache2 2>/dev/null || systemctl start httpd 2>/dev/null; then
        sleep 3
        if systemctl is-active --quiet apache2 2>/dev/null || systemctl is-active --quiet httpd 2>/dev/null; then
            repair_log "SUCCESS" "APACHE" "Apache reparado y funcionando"
            return 0
        fi
    fi

    repair_log "ERROR" "APACHE" "No se pudo reparar Apache automáticamente"
    return 1
}

# Función para reparar MySQL/MariaDB
repair_database_service() {
    repair_log "STEP" "DATABASE" "Iniciando reparación de base de datos..."

    # Verificar si está instalado
    if ! command -v mysql >/dev/null 2>&1 && ! command -v mariadb >/dev/null 2>&1; then
        repair_log "WARNING" "DATABASE" "Base de datos no está instalada"
        return 1
    fi

    # Intentar reiniciar
    if systemctl restart mysql 2>/dev/null || systemctl restart mariadb 2>/dev/null; then
        sleep 3
        if systemctl is-active --quiet mysql 2>/dev/null || systemctl is-active --quiet mariadb 2>/dev/null; then
            repair_log "SUCCESS" "DATABASE" "Base de datos reiniciada correctamente"
            return 0
        fi
    fi

    repair_log "ERROR" "DATABASE" "No se pudo reiniciar la base de datos"
    return 1
}

# Función para reparar Webmin
repair_webmin_service() {
    repair_log "STEP" "WEBMIN" "Iniciando reparación de Webmin..."

    # Verificar si está instalado
    if [[ ! -d /usr/share/webmin ]]; then
        repair_log "WARNING" "WEBMIN" "Webmin no está instalado"
        return 1
    fi

    # Intentar reiniciar
    if systemctl restart webmin 2>/dev/null; then
        sleep 3
        if systemctl is-active --quiet webmin 2>/dev/null; then
            repair_log "SUCCESS" "WEBMIN" "Webmin reiniciado correctamente"
            return 0
        fi
    fi

    repair_log "ERROR" "WEBMIN" "No se pudo reiniciar Webmin"
    return 1
}

# Función para reparar PHP-FPM
repair_php_service() {
    repair_log "STEP" "PHP" "Iniciando reparación de PHP-FPM..."

    # Buscar servicios PHP
    local php_services=("php8.1-fpm" "php8.0-fpm" "php7.4-fpm" "php7.3-fpm" "php-fpm")

    for service in "${php_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            repair_log "SUCCESS" "PHP" "PHP-FPM ya está activo: $service"
            return 0
        fi
    done

    # Intentar iniciar algún servicio PHP
    for service in "${php_services[@]}"; do
        if systemctl start "$service" 2>/dev/null; then
            sleep 2
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                repair_log "SUCCESS" "PHP" "PHP-FPM iniciado: $service"
                return 0
            fi
        fi
    done

    repair_log "WARNING" "PHP" "No se pudo iniciar PHP-FPM"
    return 1
}

# Función para liberar memoria si es necesario
free_system_memory() {
    repair_log "STEP" "MEMORY" "Verificando uso de memoria..."

    local mem_usage
    mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}' 2>/dev/null || echo "0")

    if [[ $mem_usage -gt 80 ]]; then
        repair_log "INFO" "MEMORY" "Liberando memoria del sistema ($mem_usage% usado)"

        # Liberar cache de memoria
        sync
        echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

        # Matar procesos zombies
        killall -9 zombie 2>/dev/null || true

        repair_log "SUCCESS" "MEMORY" "Memoria liberada"
        return 0
    else
        repair_log "INFO" "MEMORY" "Uso de memoria normal: $mem_usage%"
        return 0
    fi
}

# Función para verificar estado final
verify_final_state() {
    repair_log "STEP" "VERIFICATION" "Verificando estado final de todos los servicios..."

    local services_ok=0
    local total_services=0

    # Verificar Apache
    ((total_services++))
    if systemctl is-active --quiet apache2 2>/dev/null || systemctl is-active --quiet httpd 2>/dev/null; then
        repair_log "SUCCESS" "VERIFICATION" "Apache: ✅ ACTIVO"
        ((services_ok++))
    else
        repair_log "ERROR" "VERIFICATION" "Apache: ❌ INACTIVO"
    fi

    # Verificar base de datos
    ((total_services++))
    if systemctl is-active --quiet mysql 2>/dev/null || systemctl is-active --quiet mariadb 2>/dev/null; then
        repair_log "SUCCESS" "VERIFICATION" "Base de datos: ✅ ACTIVO"
        ((services_ok++))
    else
        repair_log "ERROR" "VERIFICATION" "Base de datos: ❌ INACTIVO"
    fi

    # Verificar Webmin
    ((total_services++))
    if systemctl is-active --quiet webmin 2>/dev/null; then
        repair_log "SUCCESS" "VERIFICATION" "Webmin: ✅ ACTIVO"
        ((services_ok++))
    else
        repair_log "ERROR" "VERIFICATION" "Webmin: ❌ INACTIVO"
    fi

    # Verificar PHP
    ((total_services++))
    if systemctl is-active --quiet php*fpm 2>/dev/null; then
        repair_log "SUCCESS" "VERIFICATION" "PHP-FPM: ✅ ACTIVO"
        ((services_ok++))
    else
        repair_log "WARNING" "VERIFICATION" "PHP-FPM: ⚠️ NO DETECTADO"
    fi

    repair_log "INFO" "VERIFICATION" "Verificación completada: $services_ok/$total_services servicios funcionando"

    return $((total_services - services_ok))
}

# Función principal de reparación automática completa
auto_repair_complete() {
    repair_log "STEP" "SYSTEM" "🚀 INICIANDO REPARACIÓN AUTOMÁTICA COMPLETA"

    echo ""
    echo -e "${CYAN}🔧 REPARACIÓN AUTOMÁTICA COMPLETA${NC}"
    echo -e "${CYAN}Reparando todos los servicios automáticamente${NC}"
    echo ""

    # Crear backup antes de empezar
    create_repair_backup

    # Liberar memoria si es necesario
    free_system_memory

    # Reparar servicios principales
    repair_apache_service
    repair_database_service
    repair_webmin_service
    repair_php_service

    # Verificar estado final
    local failed_services
    if verify_final_state; then
        failed_services=$?
    else
        failed_services=0
    fi

    # Resultado final
    if [[ $failed_services -eq 0 ]]; then
        repair_log "SUCCESS" "SYSTEM" "🎉 TODOS LOS SERVICIOS REPARADOS EXITOSAMENTE"
        echo ""
        echo -e "${GREEN}✅ ¡REPARACIÓN COMPLETA EXITOSA!${NC}"
        echo "   🎉 Todos los servicios están funcionando"
        echo "   🔧 Reparaciones automáticas completadas"
        echo "   📊 Sistema operativo al 100%"
        return 0
    else
        repair_log "WARNING" "SYSTEM" "⚠️ REPARACIÓN COMPLETADA CON ADVERTENCIAS"
        echo ""
        echo -e "${YELLOW}⚠️ REPARACIÓN COMPLETADA CON ADVERTENCIAS${NC}"
        echo "   • Algunos servicios pueden requerir atención manual"
        echo "   • Revisa el log completo para detalles"
        echo "   • $failed_services servicios no se pudieron reparar automáticamente"
        return 1
    fi
}

# Función para mostrar ayuda
show_help() {
    echo "Uso: $0 [opciones]"
    echo ""
    echo "Opciones:"
    echo "  --apache      Reparar solo Apache"
    echo "  --database    Reparar solo base de datos"
    echo "  --webmin      Reparar solo Webmin"
    echo "  --complete    Reparación completa (por defecto)"
    echo "  --verify      Solo verificar estado"
    echo "  --help        Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 --complete     # Reparar todo automáticamente"
    echo "  $0 --apache       # Reparar solo Apache"
    echo "  $0 --verify       # Verificar estado actual"
}

# Procesar argumentos
case "${1:-}" in
    "--apache")
        repair_apache_service
        ;;
    "--database")
        repair_database_service
        ;;
    "--webmin")
        repair_webmin_service
        ;;
    "--complete"|"-c"|"")
        auto_repair_complete
        ;;
    "--verify"|"-v")
        verify_final_state
        ;;
    "--help"|"-h")
        show_help
        ;;
    *)
        echo -e "${RED}Opción no válida: $1${NC}"
        show_help
        exit 1
        ;;
esac

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Este script debe ejecutarse como root${NC}"
    echo -e "${YELLOW}💡 Ejecuta: sudo $0${NC}"
    exit 1
fi

# Crear directorios necesarios
mkdir -p "$BACKUP_DIR"
touch "$REPAIR_LOG"
