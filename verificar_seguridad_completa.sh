#!/bin/bash

# Script de verificación de seguridad completa para Webmin y Virtualmin
# Este script realiza una verificación exhaustiva de la seguridad del sistema

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -euo pipefail
IFS=$'\n\t'
trap 'echo "[ERROR] verificar_seguridad_completa.sh fallo en línea $LINENO"; exit 1' ERR

# Colores para output
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

# Variables
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="seguridad_webmin_virtualmin_${TIMESTAMP}.log"
REPORT_FILE="reporte_seguridad_${TIMESTAMP}.md"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="${BASE_DIR}/reportes"
OS_TYPE=""
TOTAL_CHECKS=0
PASSED_CHECKS=0
WARNING_CHECKS=0
FAILED_CHECKS=0

# Función para mostrar banner
show_banner() {
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${WHITE}                VERIFICACIÓN DE SEGURIDAD COMPLETA                          ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${WHITE}                    Webmin y Virtualmin                                    ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# Función para registrar en el log
# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
    
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Fin de función duplicada

# Función para detectar el sistema operativo
detect_os() {
    log "INFO" "Detectando sistema operativo..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_TYPE="$ID"
        log "INFO" "Sistema operativo detectado: $OS_TYPE $VERSION_ID"
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS_TYPE="$DISTRIB_ID"
        log "INFO" "Sistema operativo detectado: $OS_TYPE $DISTRIB_RELEASE"
    elif [ -f /etc/debian_version ]; then
        OS_TYPE="debian"
        log "INFO" "Sistema operativo detectado: Debian"
    elif [ -f /etc/redhat-release ]; then
        OS_TYPE="rhel"
        log "INFO" "Sistema operativo detectado: Red Hat / CentOS"
    elif [[ "$(uname)" == "Darwin" ]]; then
        OS_TYPE="macos"
        log "INFO" "Sistema operativo detectado: macOS"
    else
        OS_TYPE="unknown"
        log "WARNING" "No se pudo detectar el sistema operativo"
    fi
    
    # Añadir al reporte
    echo "## Sistema Operativo" >> "$REPORT_FILE"
    echo "- **Tipo**: $OS_TYPE" >> "$REPORT_FILE"
    echo "- **Fecha de verificación**: $(date)" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
}

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función para verificar si un servicio está activo
service_is_active() {
    local service=$1
    
    if command_exists systemctl; then
        systemctl is-active --quiet "$service" 2>/dev/null
        return $?
    elif command_exists service; then
        service "$service" status >/dev/null 2>&1
        return $?
    else
        # En macOS o sistemas sin systemd/service
        if [ "$OS_TYPE" = "macos" ]; then
            # Verificar si el proceso está en ejecución
            pgrep -f "$service" >/dev/null 2>&1
            return $?
        else
            return 1
        fi
    fi
}

# Función para verificar puertos abiertos
check_open_ports() {
    log "INFO" "Verificando puertos abiertos..."
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo "## Puertos Abiertos" >> "$REPORT_FILE"
    
    if command_exists netstat; then
        log "INFO" "Usando netstat para verificar puertos"
        LISTENING_PORTS=$(netstat -tuln 2>/dev/null | grep LISTEN)
    elif command_exists ss; then
        log "INFO" "Usando ss para verificar puertos"
        LISTENING_PORTS=$(ss -tuln 2>/dev/null | grep LISTEN)
    elif command_exists lsof && [ "$OS_TYPE" = "macos" ]; then
        log "INFO" "Usando lsof para verificar puertos (macOS)"
        LISTENING_PORTS=$(lsof -i -P | grep LISTEN)
    else
        log "ERROR" "No se encontraron herramientas para verificar puertos"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        echo "- ❌ No se pudieron verificar los puertos abiertos" >> "$REPORT_FILE"
        return 1
    fi
    
    # Verificar puertos críticos
    WEBMIN_PORT=$(echo "$LISTENING_PORTS" | grep -E ':10000 ')
    SSH_PORT=$(echo "$LISTENING_PORTS" | grep -E ':(22|2222) ')
    HTTP_PORT=$(echo "$LISTENING_PORTS" | grep -E ':80 ')
    HTTPS_PORT=$(echo "$LISTENING_PORTS" | grep -E ':443 ')
    MYSQL_PORT=$(echo "$LISTENING_PORTS" | grep -E ':3306 ')
    
    echo "### Puertos críticos detectados:" >> "$REPORT_FILE"
    
    if [ -n "$WEBMIN_PORT" ]; then
        log "SUCCESS" "Puerto Webmin (10000) está abierto"
        echo "- ✅ Puerto Webmin (10000) está abierto" >> "$REPORT_FILE"
    else
        log "WARNING" "Puerto Webmin (10000) no está abierto"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
        echo "- ⚠️ Puerto Webmin (10000) no está abierto" >> "$REPORT_FILE"
    fi
    
    if [ -n "$SSH_PORT" ]; then
        log "SUCCESS" "Puerto SSH (22/2222) está abierto"
        echo "- ✅ Puerto SSH (22/2222) está abierto" >> "$REPORT_FILE"
    else
        log "WARNING" "Puerto SSH (22/2222) no está abierto"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
        echo "- ⚠️ Puerto SSH (22/2222) no está abierto" >> "$REPORT_FILE"
    fi
    
    if [ -n "$HTTP_PORT" ]; then
        log "SUCCESS" "Puerto HTTP (80) está abierto"
        echo "- ✅ Puerto HTTP (80) está abierto" >> "$REPORT_FILE"
    else
        log "INFO" "Puerto HTTP (80) no está abierto"
        echo "- ℹ️ Puerto HTTP (80) no está abierto" >> "$REPORT_FILE"
    fi
    
    if [ -n "$HTTPS_PORT" ]; then
        log "SUCCESS" "Puerto HTTPS (443) está abierto"
        echo "- ✅ Puerto HTTPS (443) está abierto" >> "$REPORT_FILE"
    else
        log "INFO" "Puerto HTTPS (443) no está abierto"
        echo "- ℹ️ Puerto HTTPS (443) no está abierto" >> "$REPORT_FILE"
    fi
    
    if [ -n "$MYSQL_PORT" ]; then
        log "SUCCESS" "Puerto MySQL (3306) está abierto"
        echo "- ✅ Puerto MySQL (3306) está abierto" >> "$REPORT_FILE"
    else
        log "INFO" "Puerto MySQL (3306) no está abierto"
        echo "- ℹ️ Puerto MySQL (3306) no está abierto" >> "$REPORT_FILE"
    fi
    
    # Verificar puertos no estándar o potencialmente peligrosos
    UNUSUAL_PORTS=$(echo "$LISTENING_PORTS" | grep -vE ':(22|80|443|10000|3306|53|25|587|993|995|143|110|8080|8443) ')
    
    if [ -n "$UNUSUAL_PORTS" ]; then
        log "WARNING" "Se detectaron puertos no estándar abiertos"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
        
        echo "### Puertos no estándar detectados:" >> "$REPORT_FILE"
        echo '```' >> "$REPORT_FILE"
        echo "$UNUSUAL_PORTS" >> "$REPORT_FILE"
        echo '```' >> "$REPORT_FILE"
    else
        log "SUCCESS" "No se detectaron puertos no estándar abiertos"
        echo "### Puertos no estándar:" >> "$REPORT_FILE"
        echo "- ✅ No se detectaron puertos no estándar abiertos" >> "$REPORT_FILE"
    fi
    
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo "" >> "$REPORT_FILE"
    return 0
}

# Función para verificar la configuración de Webmin
check_webmin_config() {
    log "INFO" "Verificando configuración de seguridad de Webmin..."
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo "## Configuración de Seguridad de Webmin" >> "$REPORT_FILE"
    
    # Verificar si Webmin está instalado
    if ! command_exists webmin; then
        if [ -d /usr/libexec/webmin ] || [ -d /usr/local/webmin ] || [ -d /opt/webmin ]; then
            log "INFO" "Webmin está instalado pero no en PATH"
        else
            log "WARNING" "Webmin no parece estar instalado"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            echo "- ⚠️ Webmin no parece estar instalado" >> "$REPORT_FILE"
            return 1
        fi
    fi
    
    # Buscar archivos de configuración de Webmin
    WEBMIN_CONFIG_DIRS=("/etc/webmin" "/usr/local/etc/webmin" "/opt/webmin/etc")
    WEBMIN_CONFIG_DIR=""
    
    for dir in "${WEBMIN_CONFIG_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            WEBMIN_CONFIG_DIR="$dir"
            break
        fi
    done
    
    if [ -z "$WEBMIN_CONFIG_DIR" ]; then
        log "WARNING" "No se pudo encontrar el directorio de configuración de Webmin"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
        echo "- ⚠️ No se pudo encontrar el directorio de configuración de Webmin" >> "$REPORT_FILE"
        return 1
    fi
    
    log "INFO" "Directorio de configuración de Webmin: $WEBMIN_CONFIG_DIR"
    
    # Verificar archivo miniserv.conf
    if [ -f "$WEBMIN_CONFIG_DIR/miniserv.conf" ]; then
        log "SUCCESS" "Archivo miniserv.conf encontrado"
        echo "- ✅ Archivo miniserv.conf encontrado" >> "$REPORT_FILE"
        
        # Verificar SSL
        if grep -q "^ssl=1" "$WEBMIN_CONFIG_DIR/miniserv.conf"; then
            log "SUCCESS" "SSL está habilitado en Webmin"
            echo "- ✅ SSL está habilitado en Webmin" >> "$REPORT_FILE"
        else
            log "ERROR" "SSL no está habilitado en Webmin"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            echo "- ❌ SSL no está habilitado en Webmin" >> "$REPORT_FILE"
        fi
        
        # Verificar fuerza de cifrado
        if grep -q "^cipher_list_def=1" "$WEBMIN_CONFIG_DIR/miniserv.conf" || \
           grep -q "^cipher_list=.*HIGH" "$WEBMIN_CONFIG_DIR/miniserv.conf"; then
            log "SUCCESS" "Cifrados fuertes configurados en Webmin"
            echo "- ✅ Cifrados fuertes configurados en Webmin" >> "$REPORT_FILE"
        else
            log "WARNING" "No se detectaron cifrados fuertes en Webmin"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            echo "- ⚠️ No se detectaron cifrados fuertes en Webmin" >> "$REPORT_FILE"
        fi
        
        # Verificar bloqueo de IP
        if grep -q "^blockhost_failures" "$WEBMIN_CONFIG_DIR/miniserv.conf"; then
            log "SUCCESS" "Bloqueo de IP por intentos fallidos configurado"
            echo "- ✅ Bloqueo de IP por intentos fallidos configurado" >> "$REPORT_FILE"
        else
            log "WARNING" "No se detectó bloqueo de IP por intentos fallidos"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            echo "- ⚠️ No se detectó bloqueo de IP por intentos fallidos" >> "$REPORT_FILE"
        fi
        
        # Verificar autenticación de dos factores
        if grep -q "^twofactor_provider" "$WEBMIN_CONFIG_DIR/miniserv.conf"; then
            log "SUCCESS" "Autenticación de dos factores configurada"
            echo "- ✅ Autenticación de dos factores configurada" >> "$REPORT_FILE"
        else
            log "WARNING" "Autenticación de dos factores no configurada"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            echo "- ⚠️ Autenticación de dos factores no configurada" >> "$REPORT_FILE"
        fi
    else
        log "ERROR" "No se encontró el archivo miniserv.conf"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        echo "- ❌ No se encontró el archivo miniserv.conf" >> "$REPORT_FILE"
    fi
    
    # Verificar permisos de archivos de configuración
    if [ -d "$WEBMIN_CONFIG_DIR" ]; then
        CONFIG_PERMS=$(ls -ld "$WEBMIN_CONFIG_DIR" | awk '{print $1}')
        if [[ "$CONFIG_PERMS" == *"r-x"* && "$CONFIG_PERMS" != *"w-"* ]]; then
            log "SUCCESS" "Permisos correctos en directorio de configuración"
            echo "- ✅ Permisos correctos en directorio de configuración" >> "$REPORT_FILE"
        else
            log "WARNING" "Permisos incorrectos en directorio de configuración: $CONFIG_PERMS"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            echo "- ⚠️ Permisos incorrectos en directorio de configuración: $CONFIG_PERMS" >> "$REPORT_FILE"
        fi
    fi
    
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo "" >> "$REPORT_FILE"
    return 0
}

# Función para verificar la configuración de Virtualmin
check_virtualmin_config() {
    log "INFO" "Verificando configuración de seguridad de Virtualmin..."
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo "## Configuración de Seguridad de Virtualmin" >> "$REPORT_FILE"
    
    # Verificar si Virtualmin está instalado
    if command_exists virtualmin; then
        log "SUCCESS" "Virtualmin está instalado"
        echo "- ✅ Virtualmin está instalado" >> "$REPORT_FILE"
        
        # Verificar versión de Virtualmin
        VIRTUALMIN_VERSION=$(virtualmin info | grep -i version | head -1)
        if [ -n "$VIRTUALMIN_VERSION" ]; then
            log "INFO" "Versión de Virtualmin: $VIRTUALMIN_VERSION"
            echo "- ℹ️ $VIRTUALMIN_VERSION" >> "$REPORT_FILE"
        fi
    else
        # Verificar si existe el directorio de Virtualmin
        if [ -d /usr/libexec/webmin/virtual-server ] || [ -d /usr/local/webmin/virtual-server ] || [ -d /opt/webmin/virtual-server ]; then
            log "INFO" "Virtualmin está instalado pero no en PATH"
            echo "- ✅ Virtualmin está instalado pero no en PATH" >> "$REPORT_FILE"
        else
            log "WARNING" "Virtualmin no parece estar instalado"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            echo "- ⚠️ Virtualmin no parece estar instalado" >> "$REPORT_FILE"
            return 1
        fi
    fi
    
    # Buscar archivos de configuración de Virtualmin
    VIRTUALMIN_CONFIG_DIRS=("/etc/webmin/virtual-server" "/usr/local/etc/webmin/virtual-server" "/opt/webmin/etc/virtual-server")
    VIRTUALMIN_CONFIG_DIR=""
    
    for dir in "${VIRTUALMIN_CONFIG_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            VIRTUALMIN_CONFIG_DIR="$dir"
            break
        fi
    done
    
    if [ -z "$VIRTUALMIN_CONFIG_DIR" ]; then
        log "WARNING" "No se pudo encontrar el directorio de configuración de Virtualmin"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
        echo "- ⚠️ No se pudo encontrar el directorio de configuración de Virtualmin" >> "$REPORT_FILE"
        return 1
    fi
    
    log "INFO" "Directorio de configuración de Virtualmin: $VIRTUALMIN_CONFIG_DIR"
    
    # Verificar archivo config
    if [ -f "$VIRTUALMIN_CONFIG_DIR/config" ]; then
        log "SUCCESS" "Archivo de configuración de Virtualmin encontrado"
        echo "- ✅ Archivo de configuración de Virtualmin encontrado" >> "$REPORT_FILE"
        
        # Verificar DKIM
        if grep -q "^domains_dkim=1" "$VIRTUALMIN_CONFIG_DIR/config"; then
            log "SUCCESS" "DKIM está habilitado en Virtualmin"
            echo "- ✅ DKIM está habilitado en Virtualmin" >> "$REPORT_FILE"
        else
            log "WARNING" "DKIM no está habilitado en Virtualmin"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            echo "- ⚠️ DKIM no está habilitado en Virtualmin" >> "$REPORT_FILE"
        fi
        
        # Verificar SPF
        if grep -q "^spf_record=1" "$VIRTUALMIN_CONFIG_DIR/config"; then
            log "SUCCESS" "SPF está habilitado en Virtualmin"
            echo "- ✅ SPF está habilitado en Virtualmin" >> "$REPORT_FILE"
        else
            log "WARNING" "SPF no está habilitado en Virtualmin"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            echo "- ⚠️ SPF no está habilitado en Virtualmin" >> "$REPORT_FILE"
        fi
        
        # Verificar SSL por defecto
        if grep -q "^ssl=1" "$VIRTUALMIN_CONFIG_DIR/config"; then
            log "SUCCESS" "SSL está habilitado por defecto en Virtualmin"
            echo "- ✅ SSL está habilitado por defecto en Virtualmin" >> "$REPORT_FILE"
        else
            log "WARNING" "SSL no está habilitado por defecto en Virtualmin"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            echo "- ⚠️ SSL no está habilitado por defecto en Virtualmin" >> "$REPORT_FILE"
        fi
    else
        log "WARNING" "No se encontró el archivo de configuración de Virtualmin"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
        echo "- ⚠️ No se encontró el archivo de configuración de Virtualmin" >> "$REPORT_FILE"
    fi
    
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo "" >> "$REPORT_FILE"
    return 0
}

# Función para verificar la configuración de Apache/Nginx
check_web_server_config() {
    log "INFO" "Verificando configuración del servidor web..."
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo "## Configuración del Servidor Web" >> "$REPORT_FILE"
    
    # Verificar si Apache está instalado
    APACHE_INSTALLED=false
    NGINX_INSTALLED=false
    
    if command_exists apache2 || command_exists httpd; then
        APACHE_INSTALLED=true
        log "INFO" "Apache está instalado"
        echo "- ✅ Apache está instalado" >> "$REPORT_FILE"
    fi
    
    if command_exists nginx; then
        NGINX_INSTALLED=true
        log "INFO" "Nginx está instalado"
        echo "- ✅ Nginx está instalado" >> "$REPORT_FILE"
    fi
    
    if [ "$APACHE_INSTALLED" = false ] && [ "$NGINX_INSTALLED" = false ]; then
        log "WARNING" "No se detectó Apache ni Nginx"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
        echo "- ⚠️ No se detectó Apache ni Nginx" >> "$REPORT_FILE"
        return 1
    fi
    
    # Verificar configuración de Apache
    if [ "$APACHE_INSTALLED" = true ]; then
        # Determinar ubicación de configuración de Apache
        APACHE_CONF_DIRS=("/etc/apache2" "/etc/httpd" "/usr/local/etc/apache2" "/usr/local/etc/httpd")
        APACHE_CONF_DIR=""
        
        for dir in "${APACHE_CONF_DIRS[@]}"; do
            if [ -d "$dir" ]; then
                APACHE_CONF_DIR="$dir"
                break
            fi
        done
        
        if [ -n "$APACHE_CONF_DIR" ]; then
            log "INFO" "Directorio de configuración de Apache: $APACHE_CONF_DIR"
            
            # Verificar módulos de seguridad
            SECURITY_MODULES=("mod_ssl" "mod_security" "mod_evasive")
            echo "### Módulos de seguridad de Apache:" >> "$REPORT_FILE"
            
            for module in "${SECURITY_MODULES[@]}"; do
                if [ -f "$APACHE_CONF_DIR/mods-enabled/${module}.load" ] || \
                   [ -f "$APACHE_CONF_DIR/modules.d/*_${module}.conf" ] || \
                   grep -q "LoadModule.*${module}" "$APACHE_CONF_DIR/httpd.conf" 2>/dev/null; then
                    log "SUCCESS" "Módulo $module está habilitado"
                    echo "- ✅ Módulo $module está habilitado" >> "$REPORT_FILE"
                else
                    log "WARNING" "Módulo $module no está habilitado"
                    WARNING_CHECKS=$((WARNING_CHECKS + 1))
                    echo "- ⚠️ Módulo $module no está habilitado" >> "$REPORT_FILE"
                fi
            done
            
            # Verificar configuración de SSL
            SSL_CONFIG_FILES=("$APACHE_CONF_DIR/sites-enabled/default-ssl.conf" \
                             "$APACHE_CONF_DIR/sites-enabled/ssl.conf" \
                             "$APACHE_CONF_DIR/conf.d/ssl.conf" \
                             "$APACHE_CONF_DIR/httpd-ssl.conf")
            
            SSL_CONFIG_FOUND=false
            for config in "${SSL_CONFIG_FILES[@]}"; do
                if [ -f "$config" ]; then
                    SSL_CONFIG_FOUND=true
                    log "SUCCESS" "Configuración SSL encontrada: $config"
                    echo "- ✅ Configuración SSL encontrada: $config" >> "$REPORT_FILE"
                    
                    # Verificar protocolos SSL
                    if grep -q "SSLProtocol.*TLSv1\.2" "$config" || \
                       grep -q "SSLProtocol.*TLSv1\.3" "$config"; then
                        log "SUCCESS" "Protocolos SSL seguros configurados"
                        echo "- ✅ Protocolos SSL seguros configurados" >> "$REPORT_FILE"
                    else
                        log "WARNING" "No se detectaron protocolos SSL seguros"
                        WARNING_CHECKS=$((WARNING_CHECKS + 1))
                        echo "- ⚠️ No se detectaron protocolos SSL seguros" >> "$REPORT_FILE"
                    fi
                    
                    # Verificar cifrados SSL
                    if grep -q "SSLCipherSuite.*HIGH" "$config" || \
                       grep -q "SSLCipherSuite.*!aNULL" "$config"; then
                        log "SUCCESS" "Cifrados SSL seguros configurados"
                        echo "- ✅ Cifrados SSL seguros configurados" >> "$REPORT_FILE"
                    else
                        log "WARNING" "No se detectaron cifrados SSL seguros"
                        WARNING_CHECKS=$((WARNING_CHECKS + 1))
                        echo "- ⚠️ No se detectaron cifrados SSL seguros" >> "$REPORT_FILE"
                    fi
                    
                    break
                fi
            done
            
            if [ "$SSL_CONFIG_FOUND" = false ]; then
                log "WARNING" "No se encontró configuración SSL para Apache"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
                echo "- ⚠️ No se encontró configuración SSL para Apache" >> "$REPORT_FILE"
            fi
            
            # Verificar cabeceras de seguridad
            SECURITY_HEADERS_FOUND=false
            for config in $(find "$APACHE_CONF_DIR" -type f -name "*.conf" 2>/dev/null); do
                if grep -q "Header set X-Content-Type-Options" "$config" || \
                   grep -q "Header set X-Frame-Options" "$config" || \
                   grep -q "Header set X-XSS-Protection" "$config" || \
                   grep -q "Header set Content-Security-Policy" "$config"; then
                    SECURITY_HEADERS_FOUND=true
                    log "SUCCESS" "Cabeceras de seguridad configuradas"
                    echo "- ✅ Cabeceras de seguridad configuradas" >> "$REPORT_FILE"
                    break
                fi
            done
            
            if [ "$SECURITY_HEADERS_FOUND" = false ]; then
                log "WARNING" "No se detectaron cabeceras de seguridad"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
                echo "- ⚠️ No se detectaron cabeceras de seguridad" >> "$REPORT_FILE"
            fi
        else
            log "WARNING" "No se pudo encontrar el directorio de configuración de Apache"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            echo "- ⚠️ No se pudo encontrar el directorio de configuración de Apache" >> "$REPORT_FILE"
        fi
    fi
    
    # Verificar configuración de Nginx
    if [ "$NGINX_INSTALLED" = true ]; then
        # Determinar ubicación de configuración de Nginx
        NGINX_CONF_DIRS=("/etc/nginx" "/usr/local/etc/nginx" "/opt/nginx/conf")
        NGINX_CONF_DIR=""
        
        for dir in "${NGINX_CONF_DIRS[@]}"; do
            if [ -d "$dir" ]; then
                NGINX_CONF_DIR="$dir"
                break
            fi
        done
        
        if [ -n "$NGINX_CONF_DIR" ]; then
            log "INFO" "Directorio de configuración de Nginx: $NGINX_CONF_DIR"
            
            # Verificar configuración SSL
            SSL_CONFIG_FOUND=false
            for config in $(find "$NGINX_CONF_DIR" -type f -name "*.conf" 2>/dev/null); do
                if grep -q "ssl_protocols" "$config"; then
                    SSL_CONFIG_FOUND=true
                    log "SUCCESS" "Configuración SSL encontrada en Nginx"
                    echo "- ✅ Configuración SSL encontrada en Nginx" >> "$REPORT_FILE"
                    
                    # Verificar protocolos SSL
                    if grep -q "ssl_protocols.*TLSv1\.2" "$config" || \
                       grep -q "ssl_protocols.*TLSv1\.3" "$config"; then
                        log "SUCCESS" "Protocolos SSL seguros configurados en Nginx"
                        echo "- ✅ Protocolos SSL seguros configurados en Nginx" >> "$REPORT_FILE"
                    else
                        log "WARNING" "No se detectaron protocolos SSL seguros en Nginx"
                        WARNING_CHECKS=$((WARNING_CHECKS + 1))
                        echo "- ⚠️ No se detectaron protocolos SSL seguros en Nginx" >> "$REPORT_FILE"
                    fi
                    
                    # Verificar cifrados SSL
                    if grep -q "ssl_ciphers.*HIGH" "$config" || \
                       grep -q "ssl_ciphers.*!aNULL" "$config"; then
                        log "SUCCESS" "Cifrados SSL seguros configurados en Nginx"
                        echo "- ✅ Cifrados SSL seguros configurados en Nginx" >> "$REPORT_FILE"
                    else
                        log "WARNING" "No se detectaron cifrados SSL seguros en Nginx"
                        WARNING_CHECKS=$((WARNING_CHECKS + 1))
                        echo "- ⚠️ No se detectaron cifrados SSL seguros en Nginx" >> "$REPORT_FILE"
                    fi
                    
                    break
                fi
            done
            
            if [ "$SSL_CONFIG_FOUND" = false ]; then
                log "WARNING" "No se encontró configuración SSL para Nginx"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
                echo "- ⚠️ No se encontró configuración SSL para Nginx" >> "$REPORT_FILE"
            fi
            
            # Verificar cabeceras de seguridad
            SECURITY_HEADERS_FOUND=false
            for config in $(find "$NGINX_CONF_DIR" -type f -name "*.conf" 2>/dev/null); do
                if grep -q "add_header X-Content-Type-Options" "$config" || \
                   grep -q "add_header X-Frame-Options" "$config" || \
                   grep -q "add_header X-XSS-Protection" "$config" || \
                   grep -q "add_header Content-Security-Policy" "$config"; then
                    SECURITY_HEADERS_FOUND=true
                    log "SUCCESS" "Cabeceras de seguridad configuradas en Nginx"
                    echo "- ✅ Cabeceras de seguridad configuradas en Nginx" >> "$REPORT_FILE"
                    break
                fi
            done
            
            if [ "$SECURITY_HEADERS_FOUND" = false ]; then
                log "WARNING" "No se detectaron cabeceras de seguridad en Nginx"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
                echo "- ⚠️ No se detectaron cabeceras de seguridad en Nginx" >> "$REPORT_FILE"
            fi
        else
            log "WARNING" "No se pudo encontrar el directorio de configuración de Nginx"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            echo "- ⚠️ No se pudo encontrar el directorio de configuración de Nginx" >> "$REPORT_FILE"
        fi
    fi
    
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo "" >> "$REPORT_FILE"
    return 0
}

# Función para verificar la configuración de MySQL/MariaDB
check_database_config() {
    log "INFO" "Verificando configuración de seguridad de la base de datos..."
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo "## Configuración de Seguridad de Base de Datos" >> "$REPORT_FILE"
    
    # Verificar si MySQL/MariaDB está instalado
    if command_exists mysql; then
        log "SUCCESS" "MySQL/MariaDB está instalado"
        echo "- ✅ MySQL/MariaDB está instalado" >> "$REPORT_FILE"
        
        # Verificar versión
        DB_VERSION=$(mysql --version 2>/dev/null)
        if [ -n "$DB_VERSION" ]; then
            log "INFO" "Versión de base de datos: $DB_VERSION"
            echo "- ℹ️ $DB_VERSION" >> "$REPORT_FILE"
        fi
        
        # Determinar ubicación de configuración
        MYSQL_CONF_FILES=("/etc/mysql/my.cnf" "/etc/my.cnf" "/usr/local/etc/my.cnf")
        MYSQL_CONF_FILE=""
        
        for file in "${MYSQL_CONF_FILES[@]}"; do
            if [ -f "$file" ]; then
                MYSQL_CONF_FILE="$file"
                break
            fi
        done
        
        if [ -n "$MYSQL_CONF_FILE" ]; then
            log "INFO" "Archivo de configuración de MySQL: $MYSQL_CONF_FILE"
            
            # Verificar bind-address
            if grep -q "^bind-address.*127\.0\.0\.1" "$MYSQL_CONF_FILE" || \
               grep -q "^bind-address.*localhost" "$MYSQL_CONF_FILE"; then
                log "SUCCESS" "MySQL está configurado para escuchar solo en localhost"
                echo "- ✅ MySQL está configurado para escuchar solo en localhost" >> "$REPORT_FILE"
            else
                log "WARNING" "MySQL podría estar escuchando en todas las interfaces"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
                echo "- ⚠️ MySQL podría estar escuchando en todas las interfaces" >> "$REPORT_FILE"
            fi
            
            # Verificar local-infile
            if grep -q "^local-infile.*=.*0" "$MYSQL_CONF_FILE"; then
                log "SUCCESS" "local-infile está deshabilitado"
                echo "- ✅ local-infile está deshabilitado" >> "$REPORT_FILE"
            else
                log "WARNING" "local-infile podría estar habilitado"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
                echo "- ⚠️ local-infile podría estar habilitado" >> "$REPORT_FILE"
            fi
            
            # Verificar symbolic-links
            if grep -q "^symbolic-links.*=.*0" "$MYSQL_CONF_FILE"; then
                log "SUCCESS" "symbolic-links está deshabilitado"
                echo "- ✅ symbolic-links está deshabilitado" >> "$REPORT_FILE"
            else
                log "WARNING" "symbolic-links podría estar habilitado"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
                echo "- ⚠️ symbolic-links podría estar habilitado" >> "$REPORT_FILE"
            fi
        else
            log "WARNING" "No se pudo encontrar el archivo de configuración de MySQL"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            echo "- ⚠️ No se pudo encontrar el archivo de configuración de MySQL" >> "$REPORT_FILE"
        fi
    else
        log "INFO" "MySQL/MariaDB no está instalado"
        echo "- ℹ️ MySQL/MariaDB no está instalado" >> "$REPORT_FILE"
    fi
    
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo "" >> "$REPORT_FILE"
    return 0
}

# Función para verificar la configuración de firewall
check_firewall_config() {
    log "INFO" "Verificando configuración de firewall..."
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo "## Configuración de Firewall" >> "$REPORT_FILE"
    
    FIREWALL_DETECTED=false
    
    # Verificar UFW
    if command_exists ufw; then
        FIREWALL_DETECTED=true
        log "INFO" "UFW está instalado"
        echo "- ✅ UFW está instalado" >> "$REPORT_FILE"
        
        UFW_STATUS=$(ufw status 2>/dev/null)
        if echo "$UFW_STATUS" | grep -q "Status: active"; then
            log "SUCCESS" "UFW está activo"
            echo "- ✅ UFW está activo" >> "$REPORT_FILE"
            echo "- ℹ️ Reglas UFW:" >> "$REPORT_FILE"
            echo '```' >> "$REPORT_FILE"
            echo "$UFW_STATUS" >> "$REPORT_FILE"
            echo '```' >> "$REPORT_FILE"
        else
            log "WARNING" "UFW está instalado pero no activo"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            echo "- ⚠️ UFW está instalado pero no activo" >> "$REPORT_FILE"
        fi
    fi
    
    # Verificar firewalld
    if command_exists firewall-cmd; then
        FIREWALL_DETECTED=true
        log "INFO" "firewalld está instalado"
        echo "- ✅ firewalld está instalado" >> "$REPORT_FILE"
        
        if firewall-cmd --state 2>/dev/null | grep -q "running"; then
            log "SUCCESS" "firewalld está activo"
            echo "- ✅ firewalld está activo" >> "$REPORT_FILE"
            
            # Listar zonas y servicios
            FIREWALLD_ZONES=$(firewall-cmd --list-all-zones 2>/dev/null)
            echo "- ℹ️ Zonas firewalld:" >> "$REPORT_FILE"
            echo '```' >> "$REPORT_FILE"
            echo "$FIREWALLD_ZONES" | head -20 >> "$REPORT_FILE"
            echo '```' >> "$REPORT_FILE"
        else
            log "WARNING" "firewalld está instalado pero no activo"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            echo "- ⚠️ firewalld está instalado pero no activo" >> "$REPORT_FILE"
        fi
    fi
    
    # Verificar iptables
    if command_exists iptables; then
        FIREWALL_DETECTED=true
        log "INFO" "iptables está disponible"
        echo "- ✅ iptables está disponible" >> "$REPORT_FILE"
        
        IPTABLES_RULES=$(iptables -L -n 2>/dev/null)
        if [ -n "$IPTABLES_RULES" ] && ! echo "$IPTABLES_RULES" | grep -q "Chain .* \(policy ACCEPT\)"; then
            log "SUCCESS" "iptables tiene reglas configuradas"
            echo "- ✅ iptables tiene reglas configuradas" >> "$REPORT_FILE"
            echo "- ℹ️ Reglas iptables:" >> "$REPORT_FILE"
            echo '```' >> "$REPORT_FILE"
            echo "$IPTABLES_RULES" | head -20 >> "$REPORT_FILE"
            echo '```' >> "$REPORT_FILE"
        else
            log "WARNING" "iptables no tiene reglas restrictivas configuradas"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            echo "- ⚠️ iptables no tiene reglas restrictivas configuradas" >> "$REPORT_FILE"
        fi
    fi
    
    # Verificar pf (macOS/FreeBSD)
    if [ "$OS_TYPE" = "macos" ] || [ "$OS_TYPE" = "freebsd" ]; then
        if command_exists pfctl; then
            FIREWALL_DETECTED=true
            log "INFO" "pf está disponible"
            echo "- ✅ pf está disponible" >> "$REPORT_FILE"
            
            PF_STATUS=$(pfctl -s info 2>/dev/null)
            if echo "$PF_STATUS" | grep -q "Status: Enabled"; then
                log "SUCCESS" "pf está activo"
                echo "- ✅ pf está activo" >> "$REPORT_FILE"
            else
                log "WARNING" "pf está disponible pero no activo"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
                echo "- ⚠️ pf está disponible pero no activo" >> "$REPORT_FILE"
            fi
        fi
    fi
    
    if [ "$FIREWALL_DETECTED" = false ]; then
        log "ERROR" "No se detectó ningún firewall"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        echo "- ❌ No se detectó ningún firewall" >> "$REPORT_FILE"
    fi
    
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo "" >> "$REPORT_FILE"
    return 0
}

# Función para verificar la configuración de SSH
check_ssh_config() {
    log "INFO" "Verificando configuración de seguridad de SSH..."
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo "## Configuración de Seguridad de SSH" >> "$REPORT_FILE"
    
    # Verificar si SSH está instalado
    if ! command_exists ssh || ! command_exists sshd; then
        log "INFO" "SSH no parece estar instalado"
        echo "- ℹ️ SSH no parece estar instalado" >> "$REPORT_FILE"
        return 0
    fi
    
    # Determinar ubicación de configuración
    SSH_CONF_FILES=("/etc/ssh/sshd_config" "/usr/local/etc/ssh/sshd_config")
    SSH_CONF_FILE=""
    
    for file in "${SSH_CONF_FILES[@]}"; do
        if [ -f "$file" ]; then
            SSH_CONF_FILE="$file"
            break
        fi
    done
    
    if [ -z "$SSH_CONF_FILE" ]; then
        log "WARNING" "No se pudo encontrar el archivo de configuración de SSH"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
        echo "- ⚠️ No se pudo encontrar el archivo de configuración de SSH" >> "$REPORT_FILE"
        return 1
    fi
    
    log "INFO" "Archivo de configuración de SSH: $SSH_CONF_FILE"
    echo "- ✅ Archivo de configuración de SSH encontrado: $SSH_CONF_FILE" >> "$REPORT_FILE"
    
    # Verificar PermitRootLogin
    if grep -q "^PermitRootLogin no" "$SSH_CONF_FILE"; then
        log "SUCCESS" "PermitRootLogin está deshabilitado"
        echo "- ✅ PermitRootLogin está deshabilitado" >> "$REPORT_FILE"
    else
        log "WARNING" "PermitRootLogin podría estar habilitado"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
        echo "- ⚠️ PermitRootLogin podría estar habilitado" >> "$REPORT_FILE"
    fi
    
    # Verificar PasswordAuthentication
    if grep -q "^PasswordAuthentication no" "$SSH_CONF_FILE"; then
        log "SUCCESS" "PasswordAuthentication está deshabilitado (usando claves)"
        echo "- ✅ PasswordAuthentication está deshabilitado (usando claves)" >> "$REPORT_FILE"
    else
        log "WARNING" "PasswordAuthentication podría estar habilitado"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
        echo "- ⚠️ PasswordAuthentication podría estar habilitado" >> "$REPORT_FILE"
    fi
    
    # Verificar Protocol
    if grep -q "^Protocol 2" "$SSH_CONF_FILE"; then
        log "SUCCESS" "SSH está usando solo el protocolo 2"
        echo "- ✅ SSH está usando solo el protocolo 2" >> "$REPORT_FILE"
    else
        log "WARNING" "SSH podría estar usando protocolos inseguros"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
        echo "- ⚠️ SSH podría estar usando protocolos inseguros" >> "$REPORT_FILE"
    fi
    
    # Verificar X11Forwarding
    if grep -q "^X11Forwarding no" "$SSH_CONF_FILE"; then
        log "SUCCESS" "X11Forwarding está deshabilitado"
        echo "- ✅ X11Forwarding está deshabilitado" >> "$REPORT_FILE"
    else
        log "WARNING" "X11Forwarding podría estar habilitado"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
        echo "- ⚠️ X11Forwarding podría estar habilitado" >> "$REPORT_FILE"
    fi
    
    # Verificar MaxAuthTries
    if grep -q "^MaxAuthTries [1-5]" "$SSH_CONF_FILE"; then
        log "SUCCESS" "MaxAuthTries está configurado con un valor bajo"
        echo "- ✅ MaxAuthTries está configurado con un valor bajo" >> "$REPORT_FILE"
    else
        log "WARNING" "MaxAuthTries no está configurado con un valor bajo"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
        echo "- ⚠️ MaxAuthTries no está configurado con un valor bajo" >> "$REPORT_FILE"
    fi
    
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo "" >> "$REPORT_FILE"
    return 0
}

# Función para verificar permisos de archivos críticos
check_file_permissions() {
    log "INFO" "Verificando permisos de archivos críticos..."
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo "## Permisos de Archivos Críticos" >> "$REPORT_FILE"
    
    # Lista de directorios críticos a verificar
    CRITICAL_DIRS=("/etc/webmin" "/etc/virtualmin" "/etc/apache2" "/etc/httpd" "/etc/nginx" "/etc/mysql" "/etc/ssh")
    
    PERMISSIONS_OK=true
    
    for dir in "${CRITICAL_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            log "INFO" "Verificando permisos en $dir"
            
            # Verificar permisos del directorio
            DIR_PERMS=$(ls -ld "$dir" | awk '{print $1}')
            DIR_OWNER=$(ls -ld "$dir" | awk '{print $3}')
            
            echo "### $dir" >> "$REPORT_FILE"
            echo "- Permisos: $DIR_PERMS" >> "$REPORT_FILE"
            echo "- Propietario: $DIR_OWNER" >> "$REPORT_FILE"
            
            # Verificar si los permisos son demasiado permisivos
            if [[ "$DIR_PERMS" == *"w-w"* ]]; then
                log "ERROR" "$dir tiene permisos de escritura para grupo/otros"
                FAILED_CHECKS=$((FAILED_CHECKS + 1))
                PERMISSIONS_OK=false
                echo "- ❌ Tiene permisos de escritura para grupo/otros" >> "$REPORT_FILE"
            else
                log "SUCCESS" "$dir tiene permisos correctos"
                echo "- ✅ Permisos correctos" >> "$REPORT_FILE"
            fi
            
            # Verificar archivos de configuración críticos
            if [ -f "$dir/config" ] || [ -f "$dir/miniserv.conf" ] || [ -f "$dir/my.cnf" ] || [ -f "$dir/sshd_config" ]; then
                log "INFO" "Verificando archivos de configuración en $dir"
                
                for config in "$dir"/*.conf "$dir"/config "$dir"/my.cnf "$dir"/sshd_config; do
                    if [ -f "$config" ]; then
                        CONFIG_PERMS=$(ls -l "$config" | awk '{print $1}')
                        CONFIG_OWNER=$(ls -l "$config" | awk '{print $3}')
                        
                        echo "- Archivo: $(basename "$config")" >> "$REPORT_FILE"
                        echo "  - Permisos: $CONFIG_PERMS" >> "$REPORT_FILE"
                        echo "  - Propietario: $CONFIG_OWNER" >> "$REPORT_FILE"
                        
                        # Verificar si los permisos son demasiado permisivos
                        if [[ "$CONFIG_PERMS" == *"rw-"* && "$CONFIG_PERMS" != *"rw-r--"* ]]; then
                            log "ERROR" "$config tiene permisos incorrectos: $CONFIG_PERMS"
                            FAILED_CHECKS=$((FAILED_CHECKS + 1))
                            PERMISSIONS_OK=false
                            echo "  - ❌ Permisos incorrectos" >> "$REPORT_FILE"
                        else
                            log "SUCCESS" "$config tiene permisos correctos"
                            echo "  - ✅ Permisos correctos" >> "$REPORT_FILE"
                        fi
                    fi
                done
            fi
            
            echo "" >> "$REPORT_FILE"
        fi
    done
    
    if [ "$PERMISSIONS_OK" = true ]; then
        log "SUCCESS" "Todos los archivos críticos tienen permisos correctos"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log "WARNING" "Algunos archivos críticos tienen permisos incorrectos"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
    fi
    
    echo "" >> "$REPORT_FILE"
    return 0
}

# Función para verificar actualizaciones pendientes
check_pending_updates() {
    log "INFO" "Verificando actualizaciones pendientes..."
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo "## Actualizaciones Pendientes" >> "$REPORT_FILE"
    
    # Verificar según el sistema operativo
    case "$OS_TYPE" in
        "ubuntu"|"debian")
            if command_exists apt; then
                log "INFO" "Verificando actualizaciones con apt"
                
                # Actualizar lista de paquetes
                apt-get update -qq 2>/dev/null
                
                # Contar actualizaciones pendientes
                UPDATES=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." | wc -l)
                SECURITY_UPDATES=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)
                
                log "INFO" "Actualizaciones pendientes: $UPDATES (Seguridad: $SECURITY_UPDATES)"
                echo "- Actualizaciones pendientes: $UPDATES" >> "$REPORT_FILE"
                echo "- Actualizaciones de seguridad: $SECURITY_UPDATES" >> "$REPORT_FILE"
                
                if [ "$SECURITY_UPDATES" -gt 0 ]; then
                    log "WARNING" "Hay actualizaciones de seguridad pendientes"
                    WARNING_CHECKS=$((WARNING_CHECKS + 1))
                    echo "- ⚠️ Hay actualizaciones de seguridad pendientes" >> "$REPORT_FILE"
                else
                    log "SUCCESS" "No hay actualizaciones de seguridad pendientes"
                    echo "- ✅ No hay actualizaciones de seguridad pendientes" >> "$REPORT_FILE"
                fi
            fi
            ;;
        "rhel"|"centos"|"fedora")
            if command_exists yum; then
                log "INFO" "Verificando actualizaciones con yum"
                
                # Contar actualizaciones pendientes
                UPDATES=$(yum check-update -q 2>/dev/null | grep -v "^$" | wc -l)
                SECURITY_UPDATES=$(yum check-update --security -q 2>/dev/null | grep -v "^$" | wc -l)
                
                log "INFO" "Actualizaciones pendientes: $UPDATES (Seguridad: $SECURITY_UPDATES)"
                echo "- Actualizaciones pendientes: $UPDATES" >> "$REPORT_FILE"
                echo "- Actualizaciones de seguridad: $SECURITY_UPDATES" >> "$REPORT_FILE"
                
                if [ "$SECURITY_UPDATES" -gt 0 ]; then
                    log "WARNING" "Hay actualizaciones de seguridad pendientes"
                    WARNING_CHECKS=$((WARNING_CHECKS + 1))
                    echo "- ⚠️ Hay actualizaciones de seguridad pendientes" >> "$REPORT_FILE"
                else
                    log "SUCCESS" "No hay actualizaciones de seguridad pendientes"
                    echo "- ✅ No hay actualizaciones de seguridad pendientes" >> "$REPORT_FILE"
                fi
            fi
            ;;
        "macos")
            log "INFO" "Verificación de actualizaciones no disponible en macOS"
            echo "- ℹ️ Verificación de actualizaciones no disponible en macOS" >> "$REPORT_FILE"
            ;;
        *)
            log "WARNING" "No se pudo verificar actualizaciones en este sistema"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            echo "- ⚠️ No se pudo verificar actualizaciones en este sistema" >> "$REPORT_FILE"
            ;;
    esac
    
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo "" >> "$REPORT_FILE"
    return 0
}

# Función para verificar servicios críticos
check_critical_services() {
    log "INFO" "Verificando servicios críticos..."
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo "## Servicios Críticos" >> "$REPORT_FILE"
    
    # Lista de servicios críticos a verificar
    CRITICAL_SERVICES=("webmin" "apache2" "httpd" "nginx" "mysql" "mariadb" "sshd" "postfix")
    
    SERVICES_OK=true
    
    for service in "${CRITICAL_SERVICES[@]}"; do
        if service_is_active "$service"; then
            log "SUCCESS" "Servicio $service está activo"
            echo "- ✅ Servicio $service está activo" >> "$REPORT_FILE"
        else
            # Verificar si el servicio debería estar instalado
            case "$service" in
                "webmin")
                    log "ERROR" "Servicio webmin no está activo"
                    FAILED_CHECKS=$((FAILED_CHECKS + 1))
                    SERVICES_OK=false
                    echo "- ❌ Servicio webmin no está activo" >> "$REPORT_FILE"
                    ;;
                "apache2"|"httpd"|"nginx")
                    # Solo necesitamos uno de estos servidores web
                    if ! service_is_active "apache2" && ! service_is_active "httpd" && ! service_is_active "nginx"; then
                        log "WARNING" "Ningún servidor web está activo"
                        WARNING_CHECKS=$((WARNING_CHECKS + 1))
                        SERVICES_OK=false
                        echo "- ⚠️ Ningún servidor web está activo" >> "$REPORT_FILE"
                    fi
                    ;;
                "mysql"|"mariadb")
                    # Solo necesitamos uno de estos servidores de base de datos
                    if ! service_is_active "mysql" && ! service_is_active "mariadb"; then
                        log "WARNING" "Ningún servidor de base de datos está activo"
                        WARNING_CHECKS=$((WARNING_CHECKS + 1))
                        SERVICES_OK=false
                        echo "- ⚠️ Ningún servidor de base de datos está activo" >> "$REPORT_FILE"
                    fi
                    ;;
                "sshd")
                    log "WARNING" "Servicio SSH no está activo"
                    WARNING_CHECKS=$((WARNING_CHECKS + 1))
                    echo "- ⚠️ Servicio SSH no está activo" >> "$REPORT_FILE"
                    ;;
                "postfix")
                    log "INFO" "Servicio postfix no está activo"
                    echo "- ℹ️ Servicio postfix no está activo" >> "$REPORT_FILE"
                    ;;
            esac
        fi
    done
    
    if [ "$SERVICES_OK" = true ]; then
        log "SUCCESS" "Todos los servicios críticos están activos"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log "WARNING" "Algunos servicios críticos no están activos"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
    fi
    
    echo "" >> "$REPORT_FILE"
    return 0
}

# Función para verificar logs de seguridad
check_security_logs() {
    log "INFO" "Verificando logs de seguridad..."
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo "## Logs de Seguridad" >> "$REPORT_FILE"
    
    # Lista de archivos de log a verificar
    LOG_FILES=("/var/log/auth.log" "/var/log/secure" "/var/log/webmin/miniserv.log" "/var/log/apache2/error.log" "/var/log/httpd/error_log" "/var/log/nginx/error.log")
    
    LOGS_OK=true
    LOGS_FOUND=false
    
    for log_file in "${LOG_FILES[@]}"; do
        if [ -f "$log_file" ]; then
            LOGS_FOUND=true
            log "INFO" "Verificando $log_file"
            
            # Verificar permisos del archivo de log
            LOG_PERMS=$(ls -l "$log_file" | awk '{print $1}')
            LOG_OWNER=$(ls -l "$log_file" | awk '{print $3}')
            
            echo "### $(basename "$log_file")" >> "$REPORT_FILE"
            echo "- Permisos: $LOG_PERMS" >> "$REPORT_FILE"
            echo "- Propietario: $LOG_OWNER" >> "$REPORT_FILE"
            
            # Verificar si los permisos son demasiado permisivos
            if [[ "$LOG_PERMS" == *"rw-r--"* || "$LOG_PERMS" == *"rw-------"* ]]; then
                log "SUCCESS" "$log_file tiene permisos correctos"
                echo "- ✅ Permisos correctos" >> "$REPORT_FILE"
            else
                log "WARNING" "$log_file tiene permisos incorrectos: $LOG_PERMS"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
                LOGS_OK=false
                echo "- ⚠️ Permisos incorrectos" >> "$REPORT_FILE"
            fi
            
            # Buscar intentos de acceso fallidos (últimas 100 líneas)
            if [ "$log_file" = "/var/log/auth.log" ] || [ "$log_file" = "/var/log/secure" ]; then
                FAILED_ATTEMPTS=$(tail -n 100 "$log_file" 2>/dev/null | grep -i "failed\|failure\|invalid" | wc -l)
                
                if [ "$FAILED_ATTEMPTS" -gt 10 ]; then
                    log "WARNING" "Se detectaron $FAILED_ATTEMPTS intentos de acceso fallidos recientes"
                    WARNING_CHECKS=$((WARNING_CHECKS + 1))
                    echo "- ⚠️ Se detectaron $FAILED_ATTEMPTS intentos de acceso fallidos recientes" >> "$REPORT_FILE"
                else
                    log "SUCCESS" "No se detectaron muchos intentos de acceso fallidos recientes"
                    echo "- ✅ No se detectaron muchos intentos de acceso fallidos recientes" >> "$REPORT_FILE"
                fi
            fi
            
            # Buscar errores en logs de Webmin/Apache/Nginx (últimas 100 líneas)
            if [[ "$log_file" == *"webmin"* || "$log_file" == *"apache"* || "$log_file" == *"httpd"* || "$log_file" == *"nginx"* ]]; then
                ERROR_COUNT=$(tail -n 100 "$log_file" 2>/dev/null | grep -i "error\|critical\|alert\|emergency" | wc -l)
                
                if [ "$ERROR_COUNT" -gt 10 ]; then
                    log "WARNING" "Se detectaron $ERROR_COUNT errores recientes"
                    WARNING_CHECKS=$((WARNING_CHECKS + 1))
                    echo "- ⚠️ Se detectaron $ERROR_COUNT errores recientes" >> "$REPORT_FILE"
                else
                    log "SUCCESS" "No se detectaron muchos errores recientes"
                    echo "- ✅ No se detectaron muchos errores recientes" >> "$REPORT_FILE"
                fi
            fi
            
            echo "" >> "$REPORT_FILE"
        fi
    done
    
    if [ "$LOGS_FOUND" = false ]; then
        log "WARNING" "No se encontraron archivos de log"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
        echo "- ⚠️ No se encontraron archivos de log" >> "$REPORT_FILE"
    elif [ "$LOGS_OK" = true ]; then
        log "SUCCESS" "Todos los logs tienen permisos correctos"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log "WARNING" "Algunos logs tienen permisos incorrectos"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
    fi
    
    echo "" >> "$REPORT_FILE"
    return 0
}

# Función para verificar la configuración de Webmin/Virtualmin
check_webmin_config() {
    log "INFO" "Verificando configuración de Webmin/Virtualmin..."
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo "## Configuración de Webmin/Virtualmin" >> "$REPORT_FILE"
    
    # Verificar si Webmin está instalado
    if ! command -v wbm_version &> /dev/null && ! [ -f "/etc/webmin/miniserv.conf" ]; then
        log "ERROR" "Webmin no está instalado"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        echo "- ❌ Webmin no está instalado" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
        return 1
    fi
    
    # Verificar versión de Webmin
    WEBMIN_VERSION=""
    if command -v wbm_version &> /dev/null; then
        WEBMIN_VERSION=$(wbm_version 2>/dev/null)
    elif [ -f "/etc/webmin/version" ]; then
        WEBMIN_VERSION=$(cat /etc/webmin/version 2>/dev/null)
    fi
    
    if [ -n "$WEBMIN_VERSION" ]; then
        log "INFO" "Versión de Webmin: $WEBMIN_VERSION"
        echo "- ℹ️ Versión de Webmin: $WEBMIN_VERSION" >> "$REPORT_FILE"
    else
        log "WARNING" "No se pudo determinar la versión de Webmin"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
        echo "- ⚠️ No se pudo determinar la versión de Webmin" >> "$REPORT_FILE"
    fi
    
    # Verificar si Virtualmin está instalado
    VIRTUALMIN_INSTALLED=false
    if [ -d "/etc/webmin/virtual-server" ]; then
        VIRTUALMIN_INSTALLED=true
        log "INFO" "Virtualmin está instalado"
        echo "- ✅ Virtualmin está instalado" >> "$REPORT_FILE"
        
        # Verificar versión de Virtualmin
        if [ -f "/etc/webmin/virtual-server/version" ]; then
            VIRTUALMIN_VERSION=$(cat /etc/webmin/virtual-server/version 2>/dev/null)
            log "INFO" "Versión de Virtualmin: $VIRTUALMIN_VERSION"
            echo "- ℹ️ Versión de Virtualmin: $VIRTUALMIN_VERSION" >> "$REPORT_FILE"
        else
            log "WARNING" "No se pudo determinar la versión de Virtualmin"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            echo "- ⚠️ No se pudo determinar la versión de Virtualmin" >> "$REPORT_FILE"
        fi
        
        # Verificar si es Virtualmin Pro
        if [ -f "/etc/webmin/virtual-server/pro" ]; then
            log "SUCCESS" "Virtualmin Pro está instalado"
            echo "- ✅ Virtualmin Pro está instalado" >> "$REPORT_FILE"
        else
            log "INFO" "Virtualmin GPL está instalado"
            echo "- ℹ️ Virtualmin GPL está instalado" >> "$REPORT_FILE"
        fi
    else
        log "INFO" "Virtualmin no está instalado"
        echo "- ℹ️ Virtualmin no está instalado" >> "$REPORT_FILE"
    fi
    
    # Verificar configuración de seguridad de Webmin
    if [ -f "/etc/webmin/miniserv.conf" ]; then
        # Verificar si SSL está habilitado
        if grep -q "^ssl=1" "/etc/webmin/miniserv.conf"; then
            log "SUCCESS" "SSL está habilitado en Webmin"
            echo "- ✅ SSL está habilitado en Webmin" >> "$REPORT_FILE"
        else
            log "ERROR" "SSL no está habilitado en Webmin"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            echo "- ❌ SSL no está habilitado en Webmin" >> "$REPORT_FILE"
        fi
        
        # Verificar si se permite el acceso remoto
        if grep -q "^allow=" "/etc/webmin/miniserv.conf"; then
            ALLOW_LIST=$(grep "^allow=" "/etc/webmin/miniserv.conf" | cut -d= -f2)
            log "INFO" "Acceso a Webmin permitido desde: $ALLOW_LIST"
            echo "- ℹ️ Acceso a Webmin permitido desde: $ALLOW_LIST" >> "$REPORT_FILE"
            
            if [[ "$ALLOW_LIST" == *"*"* ]]; then
                log "WARNING" "Webmin permite acceso desde cualquier IP"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
                echo "- ⚠️ Webmin permite acceso desde cualquier IP" >> "$REPORT_FILE"
            fi
        fi
        
        # Verificar puerto de Webmin
        WEBMIN_PORT=$(grep "^port=" "/etc/webmin/miniserv.conf" | cut -d= -f2)
        if [ -n "$WEBMIN_PORT" ]; then
            log "INFO" "Puerto de Webmin: $WEBMIN_PORT"
            echo "- ℹ️ Puerto de Webmin: $WEBMIN_PORT" >> "$REPORT_FILE"
            
            if [ "$WEBMIN_PORT" = "10000" ]; then
                log "INFO" "Webmin usa el puerto predeterminado"
                echo "- ℹ️ Webmin usa el puerto predeterminado" >> "$REPORT_FILE"
            else
                log "SUCCESS" "Webmin usa un puerto no predeterminado"
                echo "- ✅ Webmin usa un puerto no predeterminado" >> "$REPORT_FILE"
            fi
        fi
        
        # Verificar bloqueo de fuerza bruta
        if grep -q "^blockhost_failures=" "/etc/webmin/miniserv.conf"; then
            BLOCK_FAILURES=$(grep "^blockhost_failures=" "/etc/webmin/miniserv.conf" | cut -d= -f2)
            BLOCK_TIME=$(grep "^blockhost_time=" "/etc/webmin/miniserv.conf" | cut -d= -f2)
            
            if [ -n "$BLOCK_FAILURES" ] && [ -n "$BLOCK_TIME" ] && [ "$BLOCK_FAILURES" -gt 0 ] && [ "$BLOCK_TIME" -gt 0 ]; then
                log "SUCCESS" "Protección contra fuerza bruta habilitada ($BLOCK_FAILURES intentos, $BLOCK_TIME segundos)"
                echo "- ✅ Protección contra fuerza bruta habilitada ($BLOCK_FAILURES intentos, $BLOCK_TIME segundos)" >> "$REPORT_FILE"
            else
                log "WARNING" "Protección contra fuerza bruta no configurada correctamente"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
                echo "- ⚠️ Protección contra fuerza bruta no configurada correctamente" >> "$REPORT_FILE"
            fi
        else
            log "WARNING" "Protección contra fuerza bruta no habilitada"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            echo "- ⚠️ Protección contra fuerza bruta no habilitada" >> "$REPORT_FILE"
        fi
    else
        log "ERROR" "No se encontró el archivo de configuración de Webmin"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        echo "- ❌ No se encontró el archivo de configuración de Webmin" >> "$REPORT_FILE"
    fi
    
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo "" >> "$REPORT_FILE"
    return 0
}

# Función para verificar la configuración de SSL
check_ssl_config() {
    log "INFO" "Verificando configuración de SSL..."
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo "## Configuración de SSL" >> "$REPORT_FILE"
    
    SSL_OK=true
    
    # Verificar certificados de Webmin
    if [ -f "/etc/webmin/miniserv.pem" ]; then
        log "INFO" "Verificando certificado SSL de Webmin"
        echo "### Certificado SSL de Webmin" >> "$REPORT_FILE"
        
        # Obtener información del certificado
        CERT_INFO=$(openssl x509 -in /etc/webmin/miniserv.pem -text -noout 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            # Verificar fecha de expiración
            CERT_EXPIRY=$(echo "$CERT_INFO" | grep "Not After" | cut -d: -f2-)
            CERT_EXPIRY_EPOCH=$(date -d "$CERT_EXPIRY" +%s 2>/dev/null)
            CURRENT_EPOCH=$(date +%s)
            
            if [ -n "$CERT_EXPIRY_EPOCH" ]; then
                DAYS_LEFT=$(( ($CERT_EXPIRY_EPOCH - $CURRENT_EPOCH) / 86400 ))
                
                echo "- Expira: $CERT_EXPIRY ($DAYS_LEFT días)" >> "$REPORT_FILE"
                
                if [ "$DAYS_LEFT" -lt 0 ]; then
                    log "ERROR" "El certificado SSL de Webmin ha expirado"
                    FAILED_CHECKS=$((FAILED_CHECKS + 1))
                    SSL_OK=false
                    echo "- ❌ El certificado SSL de Webmin ha expirado" >> "$REPORT_FILE"
                elif [ "$DAYS_LEFT" -lt 30 ]; then
                    log "WARNING" "El certificado SSL de Webmin expirará pronto ($DAYS_LEFT días)"
                    WARNING_CHECKS=$((WARNING_CHECKS + 1))
                    echo "- ⚠️ El certificado SSL de Webmin expirará pronto ($DAYS_LEFT días)" >> "$REPORT_FILE"
                else
                    log "SUCCESS" "El certificado SSL de Webmin es válido ($DAYS_LEFT días restantes)"
                    echo "- ✅ El certificado SSL de Webmin es válido ($DAYS_LEFT días restantes)" >> "$REPORT_FILE"
                fi
            else
                # Alternativa para sistemas que no soportan date -d
                echo "- Expira: $CERT_EXPIRY" >> "$REPORT_FILE"
                log "INFO" "No se pudo calcular días restantes para el certificado"
                echo "- ℹ️ No se pudo calcular días restantes para el certificado" >> "$REPORT_FILE"
            fi
            
            # Verificar algoritmo de firma
            CERT_SIGNATURE=$(echo "$CERT_INFO" | grep "Signature Algorithm" | head -1 | awk '{print $2}')
            echo "- Algoritmo de firma: $CERT_SIGNATURE" >> "$REPORT_FILE"
            
            if [[ "$CERT_SIGNATURE" == *"sha1"* || "$CERT_SIGNATURE" == *"md5"* ]]; then
                log "WARNING" "El certificado SSL de Webmin usa un algoritmo de firma débil: $CERT_SIGNATURE"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
                echo "- ⚠️ Algoritmo de firma débil: $CERT_SIGNATURE" >> "$REPORT_FILE"
            else
                log "SUCCESS" "El certificado SSL de Webmin usa un algoritmo de firma fuerte: $CERT_SIGNATURE"
                echo "- ✅ Algoritmo de firma fuerte: $CERT_SIGNATURE" >> "$REPORT_FILE"
            fi
            
            # Verificar tamaño de clave
            CERT_KEY_SIZE=$(echo "$CERT_INFO" | grep "Public-Key" | awk '{print $2}')
            echo "- Tamaño de clave: $CERT_KEY_SIZE bits" >> "$REPORT_FILE"
            
            if [ "$CERT_KEY_SIZE" -lt 2048 ]; then
                log "WARNING" "El certificado SSL de Webmin usa una clave débil: $CERT_KEY_SIZE bits"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
                echo "- ⚠️ Tamaño de clave débil: $CERT_KEY_SIZE bits" >> "$REPORT_FILE"
            else
                log "SUCCESS" "El certificado SSL de Webmin usa una clave fuerte: $CERT_KEY_SIZE bits"
                echo "- ✅ Tamaño de clave fuerte: $CERT_KEY_SIZE bits" >> "$REPORT_FILE"
            fi
        else
            log "WARNING" "No se pudo analizar el certificado SSL de Webmin"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            SSL_OK=false
            echo "- ⚠️ No se pudo analizar el certificado SSL de Webmin" >> "$REPORT_FILE"
        fi
    else
        log "WARNING" "No se encontró el certificado SSL de Webmin"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
        SSL_OK=false
        echo "- ⚠️ No se encontró el certificado SSL de Webmin" >> "$REPORT_FILE"
    fi
    
    echo "" >> "$REPORT_FILE"
    
    # Verificar configuración de SSL en servidores web
    if command -v apache2ctl &> /dev/null || command -v httpd &> /dev/null; then
        log "INFO" "Verificando configuración SSL de Apache"
        echo "### Configuración SSL de Apache" >> "$REPORT_FILE"
        
        # Verificar si SSL está habilitado en Apache
        SSL_ENABLED=false
        
        if command -v apache2ctl &> /dev/null; then
            if apache2ctl -M 2>/dev/null | grep -q ssl_module; then
                SSL_ENABLED=true
            fi
        elif command -v httpd &> /dev/null; then
            if httpd -M 2>/dev/null | grep -q ssl_module; then
                SSL_ENABLED=true
            fi
        fi
        
        if [ "$SSL_ENABLED" = true ]; then
            log "SUCCESS" "Módulo SSL habilitado en Apache"
            echo "- ✅ Módulo SSL habilitado en Apache" >> "$REPORT_FILE"
            
            # Verificar protocolos SSL
            SSL_PROTOCOLS=""
            
            if [ -f "/etc/apache2/mods-enabled/ssl.conf" ]; then
                SSL_PROTOCOLS=$(grep -E "^[[:space:]]*SSLProtocol" /etc/apache2/mods-enabled/ssl.conf | awk '{$1=""; print $0}' | xargs)
            elif [ -f "/etc/httpd/conf.d/ssl.conf" ]; then
                SSL_PROTOCOLS=$(grep -E "^[[:space:]]*SSLProtocol" /etc/httpd/conf.d/ssl.conf | awk '{$1=""; print $0}' | xargs)
            fi
            
            if [ -n "$SSL_PROTOCOLS" ]; then
                echo "- Protocolos SSL: $SSL_PROTOCOLS" >> "$REPORT_FILE"
                
                if [[ "$SSL_PROTOCOLS" == *"SSLv2"* || "$SSL_PROTOCOLS" == *"SSLv3"* || "$SSL_PROTOCOLS" == *"TLSv1 "* || "$SSL_PROTOCOLS" == *"TLSv1$"* ]]; then
                    log "WARNING" "Apache usa protocolos SSL inseguros: $SSL_PROTOCOLS"
                    WARNING_CHECKS=$((WARNING_CHECKS + 1))
                    echo "- ⚠️ Protocolos SSL inseguros: $SSL_PROTOCOLS" >> "$REPORT_FILE"
                else
                    log "SUCCESS" "Apache usa protocolos SSL seguros: $SSL_PROTOCOLS"
                    echo "- ✅ Protocolos SSL seguros: $SSL_PROTOCOLS" >> "$REPORT_FILE"
                fi
            else
                log "WARNING" "No se pudo determinar los protocolos SSL de Apache"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
                echo "- ⚠️ No se pudo determinar los protocolos SSL de Apache" >> "$REPORT_FILE"
            fi
            
            # Verificar cifrados SSL
            SSL_CIPHERS=""
            
            if [ -f "/etc/apache2/mods-enabled/ssl.conf" ]; then
                SSL_CIPHERS=$(grep -E "^[[:space:]]*SSLCipherSuite" /etc/apache2/mods-enabled/ssl.conf | awk '{$1=""; print $0}' | xargs)
            elif [ -f "/etc/httpd/conf.d/ssl.conf" ]; then
                SSL_CIPHERS=$(grep -E "^[[:space:]]*SSLCipherSuite" /etc/httpd/conf.d/ssl.conf | awk '{$1=""; print $0}' | xargs)
            fi
            
            if [ -n "$SSL_CIPHERS" ]; then
                echo "- Cifrados SSL: $SSL_CIPHERS" >> "$REPORT_FILE"
                
                if [[ "$SSL_CIPHERS" == *"NULL"* || "$SSL_CIPHERS" == *"EXPORT"* || "$SSL_CIPHERS" == *"RC4"* || "$SSL_CIPHERS" == *"DES"* ]]; then
                    log "WARNING" "Apache usa cifrados SSL débiles"
                    WARNING_CHECKS=$((WARNING_CHECKS + 1))
                    echo "- ⚠️ Cifrados SSL débiles detectados" >> "$REPORT_FILE"
                else
                    log "SUCCESS" "Apache usa cifrados SSL fuertes"
                    echo "- ✅ Cifrados SSL fuertes" >> "$REPORT_FILE"
                fi
            else
                log "WARNING" "No se pudo determinar los cifrados SSL de Apache"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
                echo "- ⚠️ No se pudo determinar los cifrados SSL de Apache" >> "$REPORT_FILE"
            fi
        else
            log "WARNING" "Módulo SSL no habilitado en Apache"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            SSL_OK=false
            echo "- ⚠️ Módulo SSL no habilitado en Apache" >> "$REPORT_FILE"
        fi
    fi
    
    if command -v nginx &> /dev/null; then
        log "INFO" "Verificando configuración SSL de Nginx"
        echo "### Configuración SSL de Nginx" >> "$REPORT_FILE"
        
        # Verificar si SSL está habilitado en Nginx
        SSL_ENABLED=false
        
        if nginx -V 2>&1 | grep -q "--with-http_ssl_module"; then
            SSL_ENABLED=true
        fi
        
        if [ "$SSL_ENABLED" = true ]; then
            log "SUCCESS" "Módulo SSL habilitado en Nginx"
            echo "- ✅ Módulo SSL habilitado en Nginx" >> "$REPORT_FILE"
            
            # Verificar protocolos SSL
            SSL_PROTOCOLS=""
            
            if [ -d "/etc/nginx/sites-enabled" ]; then
                SSL_PROTOCOLS=$(grep -r "ssl_protocols" /etc/nginx/sites-enabled/ 2>/dev/null | grep -v "#" | head -1 | awk '{$1=""; print $0}' | xargs)
            elif [ -f "/etc/nginx/nginx.conf" ]; then
                SSL_PROTOCOLS=$(grep "ssl_protocols" /etc/nginx/nginx.conf 2>/dev/null | grep -v "#" | head -1 | awk '{$1=""; print $0}' | xargs)
            fi
            
            if [ -n "$SSL_PROTOCOLS" ]; then
                echo "- Protocolos SSL: $SSL_PROTOCOLS" >> "$REPORT_FILE"
                
                if [[ "$SSL_PROTOCOLS" == *"SSLv2"* || "$SSL_PROTOCOLS" == *"SSLv3"* || "$SSL_PROTOCOLS" == *"TLSv1 "* || "$SSL_PROTOCOLS" == *"TLSv1;"* ]]; then
                    log "WARNING" "Nginx usa protocolos SSL inseguros: $SSL_PROTOCOLS"
                    WARNING_CHECKS=$((WARNING_CHECKS + 1))
                    echo "- ⚠️ Protocolos SSL inseguros: $SSL_PROTOCOLS" >> "$REPORT_FILE"
                else
                    log "SUCCESS" "Nginx usa protocolos SSL seguros: $SSL_PROTOCOLS"
                    echo "- ✅ Protocolos SSL seguros: $SSL_PROTOCOLS" >> "$REPORT_FILE"
                fi
            else
                log "WARNING" "No se pudo determinar los protocolos SSL de Nginx"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
                echo "- ⚠️ No se pudo determinar los protocolos SSL de Nginx" >> "$REPORT_FILE"
            fi
            
            # Verificar cifrados SSL
            SSL_CIPHERS=""
            
            if [ -d "/etc/nginx/sites-enabled" ]; then
                SSL_CIPHERS=$(grep -r "ssl_ciphers" /etc/nginx/sites-enabled/ 2>/dev/null | grep -v "#" | head -1 | awk '{$1=""; print $0}' | xargs)
            elif [ -f "/etc/nginx/nginx.conf" ]; then
                SSL_CIPHERS=$(grep "ssl_ciphers" /etc/nginx/nginx.conf 2>/dev/null | grep -v "#" | head -1 | awk '{$1=""; print $0}' | xargs)
            fi
            
            if [ -n "$SSL_CIPHERS" ]; then
                echo "- Cifrados SSL: $SSL_CIPHERS" >> "$REPORT_FILE"
                
                if [[ "$SSL_CIPHERS" == *"NULL"* || "$SSL_CIPHERS" == *"EXPORT"* || "$SSL_CIPHERS" == *"RC4"* || "$SSL_CIPHERS" == *"DES"* ]]; then
                    log "WARNING" "Nginx usa cifrados SSL débiles"
                    WARNING_CHECKS=$((WARNING_CHECKS + 1))
                    echo "- ⚠️ Cifrados SSL débiles detectados" >> "$REPORT_FILE"
                else
                    log "SUCCESS" "Nginx usa cifrados SSL fuertes"
                    echo "- ✅ Cifrados SSL fuertes" >> "$REPORT_FILE"
                fi
            else
                log "WARNING" "No se pudo determinar los cifrados SSL de Nginx"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
                echo "- ⚠️ No se pudo determinar los cifrados SSL de Nginx" >> "$REPORT_FILE"
            fi
        else
            log "WARNING" "Módulo SSL no habilitado en Nginx"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            SSL_OK=false
            echo "- ⚠️ Módulo SSL no habilitado en Nginx" >> "$REPORT_FILE"
        fi
    fi
    
    if [ "$SSL_OK" = true ]; then
        log "SUCCESS" "Configuración SSL correcta"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log "WARNING" "Configuración SSL con problemas"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
    fi
    
    echo "" >> "$REPORT_FILE"
    return 0
}

# Función para verificar hosts virtuales
check_virtual_hosts() {
    log "INFO" "Verificando hosts virtuales..."
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo "## Hosts Virtuales" >> "$REPORT_FILE"
    
    VHOSTS_OK=true
    VHOSTS_FOUND=false
    
    # Verificar hosts virtuales en Apache
    if command -v apache2ctl &> /dev/null; then
        VHOSTS=$(apache2ctl -S 2>/dev/null | grep -E "port [0-9]+ namevhost" | awk '{print $4}')
        
        if [ -n "$VHOSTS" ]; then
            VHOSTS_FOUND=true
            log "INFO" "Hosts virtuales encontrados en Apache"
            echo "### Hosts Virtuales Apache" >> "$REPORT_FILE"
            
            echo "$VHOSTS" | while read -r vhost; do
                echo "- $vhost" >> "$REPORT_FILE"
                
                # Verificar si el host virtual usa SSL
                SSL_ENABLED=false
                
                if [ -d "/etc/apache2/sites-enabled" ]; then
                    if grep -q "SSLEngine on" /etc/apache2/sites-enabled/* 2>/dev/null | grep -q "$vhost"; then
                        SSL_ENABLED=true
                    fi
                elif [ -d "/etc/httpd/conf.d" ]; then
                    if grep -q "SSLEngine on" /etc/httpd/conf.d/* 2>/dev/null | grep -q "$vhost"; then
                        SSL_ENABLED=true
                    fi
                fi
                
                if [ "$SSL_ENABLED" = true ]; then
                    log "SUCCESS" "Host virtual $vhost usa SSL"
                    echo "  - ✅ Usa SSL" >> "$REPORT_FILE"
                else
                    log "WARNING" "Host virtual $vhost no usa SSL"
                    WARNING_CHECKS=$((WARNING_CHECKS + 1))
                    VHOSTS_OK=false
                    echo "  - ⚠️ No usa SSL" >> "$REPORT_FILE"
                fi
            done
        fi
    elif command -v httpd &> /dev/null; then
        VHOSTS=$(httpd -S 2>/dev/null | grep -E "port [0-9]+ namevhost" | awk '{print $4}')
        
        if [ -n "$VHOSTS" ]; then
            VHOSTS_FOUND=true
            log "INFO" "Hosts virtuales encontrados en Apache"
            echo "### Hosts Virtuales Apache" >> "$REPORT_FILE"
            
            echo "$VHOSTS" | while read -r vhost; do
                echo "- $vhost" >> "$REPORT_FILE"
                
                # Verificar si el host virtual usa SSL
                SSL_ENABLED=false
                
                if grep -q "SSLEngine on" /etc/httpd/conf.d/* 2>/dev/null | grep -q "$vhost"; then
                    SSL_ENABLED=true
                fi
                
                if [ "$SSL_ENABLED" = true ]; then
                    log "SUCCESS" "Host virtual $vhost usa SSL"
                    echo "  - ✅ Usa SSL" >> "$REPORT_FILE"
                else
                    log "WARNING" "Host virtual $vhost no usa SSL"
                    WARNING_CHECKS=$((WARNING_CHECKS + 1))
                    VHOSTS_OK=false
                    echo "  - ⚠️ No usa SSL" >> "$REPORT_FILE"
                fi
            done
        fi
    fi
    
    # Verificar hosts virtuales en Nginx
    if command -v nginx &> /dev/null; then
        if [ -d "/etc/nginx/sites-enabled" ]; then
            VHOSTS=$(grep -r "server_name" /etc/nginx/sites-enabled/* 2>/dev/null | grep -v "#" | awk '{print $2}' | tr -d ';')
        elif [ -d "/etc/nginx/conf.d" ]; then
            VHOSTS=$(grep -r "server_name" /etc/nginx/conf.d/* 2>/dev/null | grep -v "#" | awk '{print $2}' | tr -d ';')
        fi
        
        if [ -n "$VHOSTS" ]; then
            VHOSTS_FOUND=true
            log "INFO" "Hosts virtuales encontrados en Nginx"
            echo "### Hosts Virtuales Nginx" >> "$REPORT_FILE"
            
            echo "$VHOSTS" | while read -r vhost; do
                echo "- $vhost" >> "$REPORT_FILE"
                
                # Verificar si el host virtual usa SSL
                SSL_ENABLED=false
                
                if [ -d "/etc/nginx/sites-enabled" ]; then
                    if grep -r "ssl_certificate" /etc/nginx/sites-enabled/* 2>/dev/null | grep -q "$vhost"; then
                        SSL_ENABLED=true
                    fi
                elif [ -d "/etc/nginx/conf.d" ]; then
                    if grep -r "ssl_certificate" /etc/nginx/conf.d/* 2>/dev/null | grep -q "$vhost"; then
                        SSL_ENABLED=true
                    fi
                fi
                
                if [ "$SSL_ENABLED" = true ]; then
                    log "SUCCESS" "Host virtual $vhost usa SSL"
                    echo "  - ✅ Usa SSL" >> "$REPORT_FILE"
                else
                    log "WARNING" "Host virtual $vhost no usa SSL"
                    WARNING_CHECKS=$((WARNING_CHECKS + 1))
                    VHOSTS_OK=false
                    echo "  - ⚠️ No usa SSL" >> "$REPORT_FILE"
                fi
            done
        fi
    fi
    
    # Verificar hosts virtuales en Virtualmin
    if [ -d "/etc/webmin/virtual-server" ] && [ -f "/etc/webmin/virtual-server/domains" ]; then
        VHOSTS_FOUND=true
        log "INFO" "Dominios encontrados en Virtualmin"
        echo "### Dominios Virtualmin" >> "$REPORT_FILE"
        
        # Contar dominios en Virtualmin
        DOMAIN_COUNT=$(wc -l < /etc/webmin/virtual-server/domains)
        log "INFO" "Número de dominios en Virtualmin: $DOMAIN_COUNT"
        echo "- Número de dominios: $DOMAIN_COUNT" >> "$REPORT_FILE"
        
        # Verificar SSL para dominios de Virtualmin
        SSL_COUNT=0
        
        if [ -d "/etc/webmin/virtual-server/domains" ]; then
            for domain_file in /etc/webmin/virtual-server/domains/*; do
                if grep -q "^ssl=1" "$domain_file" 2>/dev/null; then
                    SSL_COUNT=$((SSL_COUNT + 1))
                fi
            done
        fi
        
        log "INFO" "Dominios con SSL en Virtualmin: $SSL_COUNT"
        echo "- Dominios con SSL: $SSL_COUNT" >> "$REPORT_FILE"
        
        if [ "$SSL_COUNT" -lt "$DOMAIN_COUNT" ]; then
            log "WARNING" "No todos los dominios de Virtualmin usan SSL"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            VHOSTS_OK=false
            echo "- ⚠️ No todos los dominios usan SSL" >> "$REPORT_FILE"
        else
            log "SUCCESS" "Todos los dominios de Virtualmin usan SSL"
            echo "- ✅ Todos los dominios usan SSL" >> "$REPORT_FILE"
        fi
    fi
    
    if [ "$VHOSTS_FOUND" = false ]; then
        log "INFO" "No se encontraron hosts virtuales"
        echo "- ℹ️ No se encontraron hosts virtuales" >> "$REPORT_FILE"
    elif [ "$VHOSTS_OK" = true ]; then
        log "SUCCESS" "Todos los hosts virtuales están correctamente configurados"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log "WARNING" "Algunos hosts virtuales no están correctamente configurados"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
    fi
    
    echo "" >> "$REPORT_FILE"
    return 0
}

# Función para verificar la configuración de bases de datos
check_database_config() {
    log "INFO" "Verificando configuración de bases de datos..."
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo "## Configuración de Bases de Datos" >> "$REPORT_FILE"
    
    DB_OK=true
    DB_FOUND=false
    
    # Verificar MySQL/MariaDB
    if command -v mysql &> /dev/null; then
        DB_FOUND=true
        log "INFO" "MySQL/MariaDB está instalado"
        echo "### MySQL/MariaDB" >> "$REPORT_FILE"
        echo "- ✅ MySQL/MariaDB está instalado" >> "$REPORT_FILE"
        
        # Verificar versión
        DB_VERSION=$(mysql --version 2>/dev/null | awk '{print $3}')
        if [ -n "$DB_VERSION" ]; then
            log "INFO" "Versión de MySQL/MariaDB: $DB_VERSION"
            echo "- ℹ️ Versión: $DB_VERSION" >> "$REPORT_FILE"
            
            # Verificar si la versión es antigua
            if [[ "$DB_VERSION" == 5.* ]] || [[ "$DB_VERSION" == 10.0.* ]] || [[ "$DB_VERSION" == 10.1.* ]] || [[ "$DB_VERSION" == 10.2.* ]]; then
                log "WARNING" "Versión de MySQL/MariaDB antigua: $DB_VERSION"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
                DB_OK=false
                echo "- ⚠️ Versión antigua: $DB_VERSION" >> "$REPORT_FILE"
            fi
        fi
        
        # Verificar si el servicio está activo
        if service_is_active "mysql" || service_is_active "mariadb"; then
            log "SUCCESS" "Servicio MySQL/MariaDB está activo"
            echo "- ✅ Servicio activo" >> "$REPORT_FILE"
        else
            log "ERROR" "Servicio MySQL/MariaDB no está activo"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            DB_OK=false
            echo "- ❌ Servicio no activo" >> "$REPORT_FILE"
        fi
        
        # Verificar configuración de seguridad
        if [ -f "/etc/mysql/my.cnf" ]; then
            MYSQL_CONF="/etc/mysql/my.cnf"
        elif [ -f "/etc/my.cnf" ]; then
            MYSQL_CONF="/etc/my.cnf"
        fi
        
        if [ -n "$MYSQL_CONF" ]; then
            # Verificar bind-address
            BIND_ADDRESS=$(grep -E "^bind-address" "$MYSQL_CONF" 2>/dev/null | awk '{print $3}')
            
            if [ -n "$BIND_ADDRESS" ]; then
                log "INFO" "MySQL/MariaDB bind-address: $BIND_ADDRESS"
                echo "- ℹ️ Bind address: $BIND_ADDRESS" >> "$REPORT_FILE"
                
                if [ "$BIND_ADDRESS" = "127.0.0.1" ] || [ "$BIND_ADDRESS" = "localhost" ]; then
                    log "SUCCESS" "MySQL/MariaDB solo escucha en localhost"
                    echo "- ✅ Solo escucha en localhost" >> "$REPORT_FILE"
                else
                    log "WARNING" "MySQL/MariaDB escucha en $BIND_ADDRESS"
                    WARNING_CHECKS=$((WARNING_CHECKS + 1))
                    echo "- ⚠️ Escucha en $BIND_ADDRESS" >> "$REPORT_FILE"
                fi
            fi
            
            # Verificar skip-networking
            if grep -q "^skip-networking" "$MYSQL_CONF" 2>/dev/null; then
                log "SUCCESS" "MySQL/MariaDB tiene skip-networking habilitado"
                echo "- ✅ Skip-networking habilitado" >> "$REPORT_FILE"
            fi
            
            # Verificar local-infile
            if grep -q "^local-infile=0" "$MYSQL_CONF" 2>/dev/null; then
                log "SUCCESS" "MySQL/MariaDB tiene local-infile deshabilitado"
                echo "- ✅ Local-infile deshabilitado" >> "$REPORT_FILE"
            fi
            
            # Verificar secure-file-priv
            SECURE_FILE_PRIV=$(grep -E "^secure-file-priv" "$MYSQL_CONF" 2>/dev/null | awk '{print $3}')
            
            if [ -n "$SECURE_FILE_PRIV" ]; then
                log "SUCCESS" "MySQL/MariaDB tiene secure-file-priv configurado: $SECURE_FILE_PRIV"
                echo "- ✅ Secure-file-priv configurado: $SECURE_FILE_PRIV" >> "$REPORT_FILE"
            fi
        fi
    fi
    
    # Verificar PostgreSQL
    if command -v psql &> /dev/null; then
        DB_FOUND=true
        log "INFO" "PostgreSQL está instalado"
        echo "### PostgreSQL" >> "$REPORT_FILE"
        echo "- ✅ PostgreSQL está instalado" >> "$REPORT_FILE"
        
        # Verificar versión
        PG_VERSION=$(psql --version 2>/dev/null | awk '{print $3}')
        if [ -n "$PG_VERSION" ]; then
            log "INFO" "Versión de PostgreSQL: $PG_VERSION"
            echo "- ℹ️ Versión: $PG_VERSION" >> "$REPORT_FILE"
            
            # Verificar si la versión es antigua
            if [[ "$PG_VERSION" == 9.* ]] || [[ "$PG_VERSION" == 10.* ]] || [[ "$PG_VERSION" == 11.* ]]; then
                log "WARNING" "Versión de PostgreSQL antigua: $PG_VERSION"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
                DB_OK=false
                echo "- ⚠️ Versión antigua: $PG_VERSION" >> "$REPORT_FILE"
            fi
        fi
        
        # Verificar si el servicio está activo
        if service_is_active "postgresql"; then
            log "SUCCESS" "Servicio PostgreSQL está activo"
            echo "- ✅ Servicio activo" >> "$REPORT_FILE"
        else
            log "ERROR" "Servicio PostgreSQL no está activo"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            DB_OK=false
            echo "- ❌ Servicio no activo" >> "$REPORT_FILE"
        fi
        
        # Verificar configuración de seguridad
        PG_CONF_DIR="/etc/postgresql"
        if [ -d "$PG_CONF_DIR" ]; then
            # Buscar el archivo de configuración más reciente
            PG_CONF=$(find "$PG_CONF_DIR" -name "postgresql.conf" -type f | sort | tail -1)
            
            if [ -n "$PG_CONF" ]; then
                # Verificar listen_addresses
                LISTEN_ADDRESSES=$(grep -E "^listen_addresses" "$PG_CONF" 2>/dev/null | cut -d "'" -f2)
                
                if [ -n "$LISTEN_ADDRESSES" ]; then
                    log "INFO" "PostgreSQL listen_addresses: $LISTEN_ADDRESSES"
                    echo "- ℹ️ Listen addresses: $LISTEN_ADDRESSES" >> "$REPORT_FILE"
                    
                    if [ "$LISTEN_ADDRESSES" = "localhost" ] || [ "$LISTEN_ADDRESSES" = "127.0.0.1" ]; then
                        log "SUCCESS" "PostgreSQL solo escucha en localhost"
                        echo "- ✅ Solo escucha en localhost" >> "$REPORT_FILE"
                    else
                        log "WARNING" "PostgreSQL escucha en $LISTEN_ADDRESSES"
                        WARNING_CHECKS=$((WARNING_CHECKS + 1))
                        echo "- ⚠️ Escucha en $LISTEN_ADDRESSES" >> "$REPORT_FILE"
                    fi
                fi
                
                # Verificar ssl
                if grep -q "^ssl = on" "$PG_CONF" 2>/dev/null; then
                    log "SUCCESS" "PostgreSQL tiene SSL habilitado"
                    echo "- ✅ SSL habilitado" >> "$REPORT_FILE"
                else
                    log "WARNING" "PostgreSQL no tiene SSL habilitado"
                    WARNING_CHECKS=$((WARNING_CHECKS + 1))
                    echo "- ⚠️ SSL no habilitado" >> "$REPORT_FILE"
                fi
            fi
        fi
    fi
    
    if [ "$DB_FOUND" = false ]; then
        log "INFO" "No se encontraron bases de datos"
        echo "- ℹ️ No se encontraron bases de datos" >> "$REPORT_FILE"
    elif [ "$DB_OK" = true ]; then
        log "SUCCESS" "Configuración de bases de datos correcta"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log "WARNING" "Configuración de bases de datos con problemas"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
    fi
    
    echo "" >> "$REPORT_FILE"
    return 0
}

# Función para verificar la configuración de correo electrónico
check_email_config() {
    log "INFO" "Verificando configuración de correo electrónico..."
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo "## Configuración de Correo Electrónico" >> "$REPORT_FILE"
    
    EMAIL_OK=true
    EMAIL_FOUND=false
    
    # Verificar Postfix
    if command -v postfix &> /dev/null || [ -f "/etc/postfix/main.cf" ]; then
        EMAIL_FOUND=true
        log "INFO" "Postfix está instalado"
        echo "### Postfix" >> "$REPORT_FILE"
        echo "- ✅ Postfix está instalado" >> "$REPORT_FILE"
        
        # Verificar si el servicio está activo
        if service_is_active "postfix"; then
            log "SUCCESS" "Servicio Postfix está activo"
            echo "- ✅ Servicio activo" >> "$REPORT_FILE"
        else
            log "WARNING" "Servicio Postfix no está activo"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            EMAIL_OK=false
            echo "- ⚠️ Servicio no activo" >> "$REPORT_FILE"
        fi
        
        # Verificar configuración de seguridad
        if [ -f "/etc/postfix/main.cf" ]; then
            # Verificar smtpd_tls_security_level
            TLS_SECURITY=$(grep -E "^smtpd_tls_security_level" "/etc/postfix/main.cf" 2>/dev/null | awk '{print $3}')
            
            if [ -n "$TLS_SECURITY" ]; then
                log "INFO" "Postfix smtpd_tls_security_level: $TLS_SECURITY"
                echo "- ℹ️ TLS security level: $TLS_SECURITY" >> "$REPORT_FILE"
                
                if [ "$TLS_SECURITY" = "encrypt" ] || [ "$TLS_SECURITY" = "may" ]; then
                    log "SUCCESS" "Postfix tiene TLS habilitado"
                    echo "- ✅ TLS habilitado" >> "$REPORT_FILE"
                else
                    log "WARNING" "Postfix no tiene TLS correctamente configurado"
                    WARNING_CHECKS=$((WARNING_CHECKS + 1))
                    EMAIL_OK=false
                    echo "- ⚠️ TLS no configurado correctamente" >> "$REPORT_FILE"
                fi
            else
                log "WARNING" "Postfix no tiene TLS configurado"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
                EMAIL_OK=false
                echo "- ⚠️ TLS no configurado" >> "$REPORT_FILE"
            fi
            
            # Verificar smtpd_recipient_restrictions
            if grep -q "^smtpd_recipient_restrictions" "/etc/postfix/main.cf" 2>/dev/null; then
                log "SUCCESS" "Postfix tiene restricciones de destinatario configuradas"
                echo "- ✅ Restricciones de destinatario configuradas" >> "$REPORT_FILE"
            else
                log "WARNING" "Postfix no tiene restricciones de destinatario configuradas"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
                EMAIL_OK=false
                echo "- ⚠️ Sin restricciones de destinatario" >> "$REPORT_FILE"
            fi
            
            # Verificar disable_vrfy_command
            if grep -q "^disable_vrfy_command = yes" "/etc/postfix/main.cf" 2>/dev/null; then
                log "SUCCESS" "Postfix tiene VRFY deshabilitado"
                echo "- ✅ Comando VRFY deshabilitado" >> "$REPORT_FILE"
            else
                log "WARNING" "Postfix no tiene VRFY deshabilitado"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
                EMAIL_OK=false
                echo "- ⚠️ Comando VRFY no deshabilitado" >> "$REPORT_FILE"
            fi
        fi
    fi
    
    # Verificar Dovecot
    if command -v dovecot &> /dev/null || [ -d "/etc/dovecot" ]; then
        EMAIL_FOUND=true
        log "INFO" "Dovecot está instalado"
        echo "### Dovecot" >> "$REPORT_FILE"
        echo "- ✅ Dovecot está instalado" >> "$REPORT_FILE"
        
        # Verificar si el servicio está activo
        if service_is_active "dovecot"; then
            log "SUCCESS" "Servicio Dovecot está activo"
            echo "- ✅ Servicio activo" >> "$REPORT_FILE"
        else
            log "WARNING" "Servicio Dovecot no está activo"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            EMAIL_OK=false
            echo "- ⚠️ Servicio no activo" >> "$REPORT_FILE"
        fi
        
        # Verificar configuración de seguridad
        if [ -f "/etc/dovecot/dovecot.conf" ]; then
            # Verificar SSL
            if grep -q "^ssl = yes" "/etc/dovecot/dovecot.conf" 2>/dev/null || grep -q "^ssl = required" "/etc/dovecot/conf.d/10-ssl.conf" 2>/dev/null; then
                log "SUCCESS" "Dovecot tiene SSL habilitado"
                echo "- ✅ SSL habilitado" >> "$REPORT_FILE"
            else
                log "WARNING" "Dovecot no tiene SSL habilitado"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
                EMAIL_OK=false
                echo "- ⚠️ SSL no habilitado" >> "$REPORT_FILE"
            fi
            
            # Verificar protocolos SSL
            SSL_PROTOCOLS=""
            if [ -f "/etc/dovecot/conf.d/10-ssl.conf" ]; then
                SSL_PROTOCOLS=$(grep -E "^ssl_protocols" "/etc/dovecot/conf.d/10-ssl.conf" 2>/dev/null | cut -d "=" -f2 | xargs)
            fi
            
            if [ -n "$SSL_PROTOCOLS" ]; then
                log "INFO" "Dovecot ssl_protocols: $SSL_PROTOCOLS"
                echo "- ℹ️ Protocolos SSL: $SSL_PROTOCOLS" >> "$REPORT_FILE"
                
                if [[ "$SSL_PROTOCOLS" == *"SSLv2"* || "$SSL_PROTOCOLS" == *"SSLv3"* || "$SSL_PROTOCOLS" == *"TLSv1 "* || "$SSL_PROTOCOLS" == *"TLSv1$"* ]]; then
                    log "WARNING" "Dovecot usa protocolos SSL inseguros"
                    WARNING_CHECKS=$((WARNING_CHECKS + 1))
                    EMAIL_OK=false
                    echo "- ⚠️ Protocolos SSL inseguros" >> "$REPORT_FILE"
                else
                    log "SUCCESS" "Dovecot usa protocolos SSL seguros"
                    echo "- ✅ Protocolos SSL seguros" >> "$REPORT_FILE"
                fi
            fi
            
            # Verificar autenticación
            if grep -q "^disable_plaintext_auth = yes" "/etc/dovecot/conf.d/10-auth.conf" 2>/dev/null; then
                log "SUCCESS" "Dovecot tiene autenticación de texto plano deshabilitada"
                echo "- ✅ Autenticación de texto plano deshabilitada" >> "$REPORT_FILE"
            else
                log "WARNING" "Dovecot permite autenticación de texto plano"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
                EMAIL_OK=false
                echo "- ⚠️ Autenticación de texto plano permitida" >> "$REPORT_FILE"
            fi
        fi
    fi
    
    # Verificar SpamAssassin
    if command -v spamassassin &> /dev/null || [ -d "/etc/spamassassin" ]; then
        EMAIL_FOUND=true
        log "INFO" "SpamAssassin está instalado"
        echo "### SpamAssassin" >> "$REPORT_FILE"
        echo "- ✅ SpamAssassin está instalado" >> "$REPORT_FILE"
        
        # Verificar si el servicio está activo
        if service_is_active "spamassassin"; then
            log "SUCCESS" "Servicio SpamAssassin está activo"
            echo "- ✅ Servicio activo" >> "$REPORT_FILE"
        else
            log "WARNING" "Servicio SpamAssassin no está activo"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            echo "- ⚠️ Servicio no activo" >> "$REPORT_FILE"
        fi
        
        # Verificar configuración
        if [ -f "/etc/spamassassin/local.cf" ]; then
            # Verificar required_score
            REQUIRED_SCORE=$(grep -E "^required_score" "/etc/spamassassin/local.cf" 2>/dev/null | awk '{print $2}')
            
            if [ -n "$REQUIRED_SCORE" ]; then
                log "INFO" "SpamAssassin required_score: $REQUIRED_SCORE"
                echo "- ℹ️ Required score: $REQUIRED_SCORE" >> "$REPORT_FILE"
            fi
            
            # Verificar rewrite_header
            if grep -q "^rewrite_header" "/etc/spamassassin/local.cf" 2>/dev/null; then
                log "SUCCESS" "SpamAssassin reescribe cabeceras"
                echo "- ✅ Reescritura de cabeceras configurada" >> "$REPORT_FILE"
            fi
            
            # Verificar report_safe
            if grep -q "^report_safe" "/etc/spamassassin/local.cf" 2>/dev/null; then
                log "SUCCESS" "SpamAssassin report_safe configurado"
                echo "- ✅ Report safe configurado" >> "$REPORT_FILE"
            fi
        fi
    fi
    
    # Verificar ClamAV
    if command -v clamav &> /dev/null || command -v clamscan &> /dev/null || [ -d "/etc/clamav" ]; then
        EMAIL_FOUND=true
        log "INFO" "ClamAV está instalado"
        echo "### ClamAV" >> "$REPORT_FILE"
        echo "- ✅ ClamAV está instalado" >> "$REPORT_FILE"
        
        # Verificar si el servicio está activo
        if service_is_active "clamav" || service_is_active "clamd" || service_is_active "clamav-daemon"; then
            log "SUCCESS" "Servicio ClamAV está activo"
            echo "- ✅ Servicio activo" >> "$REPORT_FILE"
        else
            log "WARNING" "Servicio ClamAV no está activo"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            echo "- ⚠️ Servicio no activo" >> "$REPORT_FILE"
        fi
        
        # Verificar actualización de firmas
        if [ -f "/var/lib/clamav/daily.cvd" ] || [ -f "/var/lib/clamav/daily.cld" ]; then
            DAILY_DATE=$(stat -c %y "/var/lib/clamav/daily.cvd" 2>/dev/null || stat -c %y "/var/lib/clamav/daily.cld" 2>/dev/null)
            
            if [ -n "$DAILY_DATE" ]; then
                log "INFO" "ClamAV daily.cvd fecha: $DAILY_DATE"
                echo "- ℹ️ Fecha de actualización: $DAILY_DATE" >> "$REPORT_FILE"
                
                # Verificar si las firmas están actualizadas (menos de 7 días)
                DAILY_EPOCH=$(date -d "$DAILY_DATE" +%s 2>/dev/null)
                CURRENT_EPOCH=$(date +%s)
                
                if [ -n "$DAILY_EPOCH" ]; then
                    DAYS_OLD=$(( ($CURRENT_EPOCH - $DAILY_EPOCH) / 86400 ))
                    
                    if [ "$DAYS_OLD" -gt 7 ]; then
                        log "WARNING" "Firmas de ClamAV desactualizadas ($DAYS_OLD días)"
                        WARNING_CHECKS=$((WARNING_CHECKS + 1))
                        EMAIL_OK=false
                        echo "- ⚠️ Firmas desactualizadas ($DAYS_OLD días)" >> "$REPORT_FILE"
                    else
                        log "SUCCESS" "Firmas de ClamAV actualizadas"
                        echo "- ✅ Firmas actualizadas" >> "$REPORT_FILE"
                    fi
                fi
            fi
        else
            log "WARNING" "No se encontraron firmas de ClamAV"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            EMAIL_OK=false
            echo "- ⚠️ No se encontraron firmas" >> "$REPORT_FILE"
        fi
    fi
    
    if [ "$EMAIL_FOUND" = false ]; then
        log "INFO" "No se encontró configuración de correo electrónico"
        echo "- ℹ️ No se encontró configuración de correo electrónico" >> "$REPORT_FILE"
    elif [ "$EMAIL_OK" = true ]; then
        log "SUCCESS" "Configuración de correo electrónico correcta"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log "WARNING" "Configuración de correo electrónico con problemas"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
    fi
    
    echo "" >> "$REPORT_FILE"
    return 0
}

# Compatibilidad: alias de nombres llamados en main hacia las funciones existentes
check_webmin_security() { check_webmin_config; }
check_virtualmin_security() { check_virtualmin_config; }
check_web_server_security() { check_web_server_config; }
check_database_security() { check_database_config; }
check_firewall_security() { check_firewall_config; }
check_ssh_security() { check_ssh_config; }
check_updates() { check_pending_updates; }

# Función principal
main() {
    # Inicializar contadores
    TOTAL_CHECKS=0
    PASSED_CHECKS=0
    FAILED_CHECKS=0
    WARNING_CHECKS=0
    
    # Crear directorio para reportes si no existe
    if [ ! -d "$REPORT_DIR" ]; then
        mkdir -p "$REPORT_DIR"
    fi
    
    # Crear archivo de reporte
    REPORT_FILE="$REPORT_DIR/reporte_seguridad_$(date +%Y%m%d_%H%M%S).md"
    
    # Encabezado del reporte
    echo "# Reporte de Seguridad de Webmin/Virtualmin" > "$REPORT_FILE"
    echo "Fecha: $(date)" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Ejecutar todas las verificaciones
    detect_os
    check_open_ports
    check_webmin_security
    check_virtualmin_security
    check_web_server_security
    check_database_security
    check_firewall_security
    check_ssh_security
    check_file_permissions
    check_updates
    check_critical_services
    check_security_logs
    check_webmin_config
    check_ssl_config
    check_virtual_hosts
    check_database_config
    check_email_config
    
    # Resumen del reporte
    echo "# Resumen" >> "$REPORT_FILE"
    echo "- Total de verificaciones: $TOTAL_CHECKS" >> "$REPORT_FILE"
    echo "- Verificaciones exitosas: $PASSED_CHECKS" >> "$REPORT_FILE"
    echo "- Verificaciones fallidas: $FAILED_CHECKS" >> "$REPORT_FILE"
    echo "- Advertencias: $WARNING_CHECKS" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Calcular porcentaje de seguridad
    if [ "$TOTAL_CHECKS" -gt 0 ]; then
        SECURITY_SCORE=$((($PASSED_CHECKS * 100) / $TOTAL_CHECKS))
        echo "## Puntuación de Seguridad: $SECURITY_SCORE%" >> "$REPORT_FILE"
        
        if [ "$SECURITY_SCORE" -ge 90 ]; then
            echo "🔒 **Excelente** - El sistema está muy seguro" >> "$REPORT_FILE"
        elif [ "$SECURITY_SCORE" -ge 75 ]; then
            echo "🔒 **Bueno** - El sistema está bastante seguro, pero hay algunas mejoras posibles" >> "$REPORT_FILE"
        elif [ "$SECURITY_SCORE" -ge 50 ]; then
            echo "⚠️ **Regular** - El sistema tiene problemas de seguridad que deben ser atendidos" >> "$REPORT_FILE"
        else
            echo "❌ **Deficiente** - El sistema tiene graves problemas de seguridad que requieren atención inmediata" >> "$REPORT_FILE"
        fi
    fi
    
    # Mostrar ubicación del reporte
    log "SUCCESS" "Verificación de seguridad completada"
    log "INFO" "Reporte guardado en: $REPORT_FILE"
    
    # Mostrar resumen en la consola
    echo ""
    echo "===== RESUMEN DE SEGURIDAD ====="
    echo "Total de verificaciones: $TOTAL_CHECKS"
    echo "Verificaciones exitosas: $PASSED_CHECKS"
    echo "Verificaciones fallidas: $FAILED_CHECKS"
    echo "Advertencias: $WARNING_CHECKS"
    
    if [ "$TOTAL_CHECKS" -gt 0 ]; then
        SECURITY_SCORE=$((($PASSED_CHECKS * 100) / $TOTAL_CHECKS))
        echo "Puntuación de Seguridad: $SECURITY_SCORE%"
        
        if [ "$SECURITY_SCORE" -ge 90 ]; then
            echo "🔒 Excelente - El sistema está muy seguro"
        elif [ "$SECURITY_SCORE" -ge 75 ]; then
            echo "🔒 Bueno - El sistema está bastante seguro, pero hay algunas mejoras posibles"
        elif [ "$SECURITY_SCORE" -ge 50 ]; then
            echo "⚠️ Regular - El sistema tiene problemas de seguridad que deben ser atendidos"
        else
            echo "❌ Deficiente - El sistema tiene graves problemas de seguridad que requieren atención inmediata"
        fi
    fi
    
    echo "Reporte guardado en: $REPORT_FILE"
    echo "==============================="
    
    return 0
}

# Ejecutar la función principal
main
