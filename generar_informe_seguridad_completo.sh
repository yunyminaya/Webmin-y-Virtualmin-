#!/bin/bash

# ============================================================================
# Script para generar un informe completo de seguridad de Webmin/Virtualmin
# Autor: Sistema DevOps Automatizado
# Versión: 1.0
# ============================================================================

# Colores para la salida
# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

# Variables globales
VERBOSE=false
OUTPUT_FILE="/tmp/informe_seguridad_$(date +%Y%m%d_%H%M%S).md"
HTML_OUTPUT=false
HTML_FILE="/tmp/informe_seguridad_$(date +%Y%m%d_%H%M%S).html"
EMAIL_REPORT=false
EMAIL_ADDRESS=""
OS=""
HOSTNAME=$(hostname)
DATE=$(date +"%Y-%m-%d %H:%M:%S")

# Función para mostrar el banner
show_banner() {
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${CYAN}                INFORME DE SEGURIDAD WEBMIN/VIRTUALMIN${NC}"
    echo -e "${CYAN}                      Generado: $DATE${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo ""
}

# Función para registrar mensajes
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
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
    elif [ -f /etc/debian_version ]; then
        OS="Debian"
    elif [ -f /etc/redhat-release ]; then
        OS="RedHat"
    elif [ -f /etc/fedora-release ]; then
        OS="Fedora"
    elif [ -f /etc/centos-release ]; then
        OS="CentOS"
    elif [[ "$(uname)" == "Darwin" ]]; then
        OS="macOS"
    else
        OS="Desconocido"
    fi
}

# Función para verificar la información del sistema
check_system_info() {
    echo "## Información del Sistema" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    log "INFO" "Recopilando información del sistema..."
    
    # Detectar sistema operativo
    detect_os
    echo "- **Sistema Operativo**: $OS" >> "$OUTPUT_FILE"
    
    # Información del kernel
    echo "- **Kernel**: $(uname -r)" >> "$OUTPUT_FILE"
    echo "- **Arquitectura**: $(uname -m)" >> "$OUTPUT_FILE"
    echo "- **Hostname**: $HOSTNAME" >> "$OUTPUT_FILE"
    
    # Tiempo de actividad
    if command -v uptime &> /dev/null; then
        echo "- **Tiempo de actividad**: $(uptime -p 2>/dev/null || uptime)" >> "$OUTPUT_FILE"
    fi
    
    # Uso de CPU
    if command -v top &> /dev/null; then
        echo "- **Uso de CPU**: $(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')%" >> "$OUTPUT_FILE"
    fi
    
    # Uso de memoria
    if command -v free &> /dev/null; then
        echo "- **Memoria Total**: $(free -h | grep Mem | awk '{print $2}')" >> "$OUTPUT_FILE"
        echo "- **Memoria Usada**: $(free -h | grep Mem | awk '{print $3}')" >> "$OUTPUT_FILE"
    fi
    
    # Uso de disco
    if command -v df &> /dev/null; then
        echo "" >> "$OUTPUT_FILE"
        echo "### Uso de Disco" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        echo '```' >> "$OUTPUT_FILE"
        df -h | grep -v "tmpfs\|udev" >> "$OUTPUT_FILE"
        echo '```' >> "$OUTPUT_FILE"
    fi
    
    echo "" >> "$OUTPUT_FILE"
    log "SUCCESS" "Información del sistema recopilada"
}

# Función para verificar Webmin/Virtualmin
check_webmin_virtualmin() {
    echo "## Webmin/Virtualmin" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    log "INFO" "Verificando instalación de Webmin/Virtualmin..."
    
    # Verificar si Webmin está instalado
    if [ -d "/etc/webmin" ]; then
        log "SUCCESS" "Webmin está instalado"
        echo "- **Webmin instalado**: Sí" >> "$OUTPUT_FILE"
        
        # Verificar versión de Webmin
        if [ -f "/etc/webmin/version" ]; then
            WEBMIN_VERSION=$(cat /etc/webmin/version)
            echo "- **Versión de Webmin**: $WEBMIN_VERSION" >> "$OUTPUT_FILE"
        else
            log "WARNING" "No se pudo determinar la versión de Webmin"
            echo "- **Versión de Webmin**: No disponible" >> "$OUTPUT_FILE"
        fi
        
        # Verificar si Virtualmin está instalado
        if [ -d "/etc/webmin/virtual-server" ]; then
            log "SUCCESS" "Virtualmin está instalado"
            echo "- **Virtualmin instalado**: Sí" >> "$OUTPUT_FILE"
            
            # Verificar versión de Virtualmin
            if [ -f "/etc/webmin/virtual-server/version" ]; then
                VIRTUALMIN_VERSION=$(cat /etc/webmin/virtual-server/version)
                echo "- **Versión de Virtualmin**: $VIRTUALMIN_VERSION" >> "$OUTPUT_FILE"
            else
                log "WARNING" "No se pudo determinar la versión de Virtualmin"
                echo "- **Versión de Virtualmin**: No disponible" >> "$OUTPUT_FILE"
            fi
        else
            log "INFO" "Virtualmin no está instalado"
            echo "- **Virtualmin instalado**: No" >> "$OUTPUT_FILE"
        fi
        
        # Verificar configuración SSL de Webmin
        echo "" >> "$OUTPUT_FILE"
        echo "### Configuración SSL de Webmin" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        
        if [ -f "/etc/webmin/miniserv.conf" ]; then
            # Verificar si SSL está habilitado
            if grep -q "^ssl=1" /etc/webmin/miniserv.conf; then
                log "SUCCESS" "SSL está habilitado en Webmin"
                echo "- **SSL habilitado**: Sí" >> "$OUTPUT_FILE"
            else
                log "CRITICAL" "SSL no está habilitado en Webmin (INSEGURO)"
                echo "- **SSL habilitado**: No (INSEGURO)" >> "$OUTPUT_FILE"
            fi
            
            # Verificar protocolos SSL
            if grep -q "^ssl_protocols=" /etc/webmin/miniserv.conf; then
                SSL_PROTOCOLS=$(grep "^ssl_protocols=" /etc/webmin/miniserv.conf | cut -d= -f2)
                echo "- **Protocolos SSL**: $SSL_PROTOCOLS" >> "$OUTPUT_FILE"
                
                # Verificar si se están utilizando protocolos seguros
                if [[ "$SSL_PROTOCOLS" == *"TLSv1.2"* ]] || [[ "$SSL_PROTOCOLS" == *"TLSv1.3"* ]]; then
                    log "SUCCESS" "Se están utilizando protocolos SSL seguros"
                else
                    log "CRITICAL" "Se están utilizando protocolos SSL inseguros"
                fi
            else
                log "WARNING" "No se han configurado protocolos SSL específicos"
                echo "- **Protocolos SSL**: No configurados" >> "$OUTPUT_FILE"
            fi
            
            # Verificar cifrados SSL
            if grep -q "^ssl_ciphers=" /etc/webmin/miniserv.conf; then
                SSL_CIPHERS=$(grep "^ssl_ciphers=" /etc/webmin/miniserv.conf | cut -d= -f2)
                echo "- **Cifrados SSL**: $SSL_CIPHERS" >> "$OUTPUT_FILE"
            else
                log "WARNING" "No se han configurado cifrados SSL específicos"
                echo "- **Cifrados SSL**: No configurados" >> "$OUTPUT_FILE"
            fi
            
            # Verificar tiempo de expiración de sesión
            if grep -q "^session_timeout=" /etc/webmin/miniserv.conf; then
                SESSION_TIMEOUT=$(grep "^session_timeout=" /etc/webmin/miniserv.conf | cut -d= -f2)
                echo "- **Tiempo de expiración de sesión**: $SESSION_TIMEOUT minutos" >> "$OUTPUT_FILE"
                
                if [ "$SESSION_TIMEOUT" -gt 60 ]; then
                    log "WARNING" "El tiempo de expiración de sesión es demasiado largo (>60 minutos)"
                else
                    log "SUCCESS" "El tiempo de expiración de sesión es adecuado"
                fi
            else
                log "WARNING" "No se ha configurado un tiempo de expiración de sesión"
                echo "- **Tiempo de expiración de sesión**: No configurado" >> "$OUTPUT_FILE"
            fi
            
            # Verificar intentos de inicio de sesión
            if grep -q "^passdelay=" /etc/webmin/miniserv.conf; then
                PASS_DELAY=$(grep "^passdelay=" /etc/webmin/miniserv.conf | cut -d= -f2)
                echo "- **Retraso de contraseña**: $PASS_DELAY segundos" >> "$OUTPUT_FILE"
            else
                log "WARNING" "No se ha configurado un retraso de contraseña"
                echo "- **Retraso de contraseña**: No configurado" >> "$OUTPUT_FILE"
            fi
            
            # Verificar bloqueo de IP
            if grep -q "^blockhost_failures=" /etc/webmin/miniserv.conf; then
                BLOCKHOST_FAILURES=$(grep "^blockhost_failures=" /etc/webmin/miniserv.conf | cut -d= -f2)
                BLOCKHOST_TIME=$(grep "^blockhost_time=" /etc/webmin/miniserv.conf | cut -d= -f2)
                echo "- **Bloqueo de IP**: Después de $BLOCKHOST_FAILURES intentos fallidos por $BLOCKHOST_TIME segundos" >> "$OUTPUT_FILE"
                
                if [ "$BLOCKHOST_FAILURES" -gt 5 ]; then
                    log "WARNING" "El número de intentos fallidos antes del bloqueo es demasiado alto (>5)"
                else
                    log "SUCCESS" "La configuración de bloqueo de IP es adecuada"
                fi
            else
                log "WARNING" "No se ha configurado el bloqueo de IP"
                echo "- **Bloqueo de IP**: No configurado" >> "$OUTPUT_FILE"
            fi
            
            # Verificar registro de acceso
            if grep -q "^log=1" /etc/webmin/miniserv.conf; then
                log "SUCCESS" "El registro de acceso está habilitado"
                echo "- **Registro de acceso**: Habilitado" >> "$OUTPUT_FILE"
            else
                log "WARNING" "El registro de acceso no está habilitado"
                echo "- **Registro de acceso**: No habilitado" >> "$OUTPUT_FILE"
            fi
        else
            log "ERROR" "No se encontró el archivo de configuración de Webmin"
            echo "- **Archivo de configuración**: No encontrado" >> "$OUTPUT_FILE"
        fi
    else
        log "INFO" "Webmin no está instalado"
        echo "- **Webmin instalado**: No" >> "$OUTPUT_FILE"
    fi
    
    echo "" >> "$OUTPUT_FILE"
    log "SUCCESS" "Verificación de Webmin/Virtualmin completada"
}

# Función para verificar el servidor web (Apache/Nginx)
check_web_server() {
    echo "## Servidor Web" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    log "INFO" "Verificando servidor web..."
    
    # Verificar Apache
    if command -v apache2 &> /dev/null || command -v httpd &> /dev/null; then
        if command -v apache2 &> /dev/null; then
            APACHE_CMD="apache2"
        else
            APACHE_CMD="httpd"
        fi
        
        log "SUCCESS" "Apache está instalado"
        echo "- **Apache instalado**: Sí" >> "$OUTPUT_FILE"
        
        # Verificar versión de Apache
        APACHE_VERSION=$($APACHE_CMD -v 2>/dev/null | grep version | awk -F'/' '{print $2}' | awk '{print $1}')
        echo "- **Versión de Apache**: $APACHE_VERSION" >> "$OUTPUT_FILE"
        
        # Verificar estado de Apache
        if command -v systemctl &> /dev/null; then
            if systemctl is-active --quiet $APACHE_CMD; then
                log "SUCCESS" "Apache está activo"
                echo "- **Estado de Apache**: Activo" >> "$OUTPUT_FILE"
            else
                log "WARNING" "Apache no está activo"
                echo "- **Estado de Apache**: Inactivo" >> "$OUTPUT_FILE"
            fi
        elif command -v service &> /dev/null; then
            if service $APACHE_CMD status &> /dev/null; then
                log "SUCCESS" "Apache está activo"
                echo "- **Estado de Apache**: Activo" >> "$OUTPUT_FILE"
            else
                log "WARNING" "Apache no está activo"
                echo "- **Estado de Apache**: Inactivo" >> "$OUTPUT_FILE"
            fi
        fi
        
        # Verificar configuración de seguridad de Apache
        echo "" >> "$OUTPUT_FILE"
        echo "### Configuración de Seguridad de Apache" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        
        # Verificar módulos de seguridad
        if [ "$APACHE_CMD" = "apache2" ]; then
            SECURITY_MODULES=("mod_ssl" "mod_security2" "mod_evasive" "mod_headers")
            for module in "${SECURITY_MODULES[@]}"; do
                if apache2ctl -M 2>/dev/null | grep -q "$module"; then
                    log "SUCCESS" "Módulo $module está habilitado"
                    echo "- **Módulo $module**: Habilitado" >> "$OUTPUT_FILE"
                else
                    log "WARNING" "Módulo $module no está habilitado"
                    echo "- **Módulo $module**: No habilitado" >> "$OUTPUT_FILE"
                fi
            done
        elif [ "$APACHE_CMD" = "httpd" ]; then
            SECURITY_MODULES=("mod_ssl" "mod_security2" "mod_evasive" "mod_headers")
            for module in "${SECURITY_MODULES[@]}"; do
                if httpd -M 2>/dev/null | grep -q "$module"; then
                    log "SUCCESS" "Módulo $module está habilitado"
                    echo "- **Módulo $module**: Habilitado" >> "$OUTPUT_FILE"
                else
                    log "WARNING" "Módulo $module no está habilitado"
                    echo "- **Módulo $module**: No habilitado" >> "$OUTPUT_FILE"
                fi
            done
        fi
        
        # Verificar configuración SSL
        if [ "$APACHE_CMD" = "apache2" ] && [ -d "/etc/apache2/sites-enabled" ]; then
            SSL_SITES=$(grep -l "SSLEngine on" /etc/apache2/sites-enabled/* 2>/dev/null | wc -l)
            if [ "$SSL_SITES" -gt 0 ]; then
                log "SUCCESS" "SSL está habilitado en $SSL_SITES sitios"
                echo "- **SSL habilitado**: Sí (en $SSL_SITES sitios)" >> "$OUTPUT_FILE"
            else
                log "WARNING" "SSL no está habilitado en ningún sitio"
                echo "- **SSL habilitado**: No" >> "$OUTPUT_FILE"
            fi
        elif [ "$APACHE_CMD" = "httpd" ] && [ -d "/etc/httpd/conf.d" ]; then
            SSL_SITES=$(grep -l "SSLEngine on" /etc/httpd/conf.d/* 2>/dev/null | wc -l)
            if [ "$SSL_SITES" -gt 0 ]; then
                log "SUCCESS" "SSL está habilitado en $SSL_SITES sitios"
                echo "- **SSL habilitado**: Sí (en $SSL_SITES sitios)" >> "$OUTPUT_FILE"
            else
                log "WARNING" "SSL no está habilitado en ningún sitio"
                echo "- **SSL habilitado**: No" >> "$OUTPUT_FILE"
            fi
        fi
        
        # Verificar cabeceras de seguridad
        SECURITY_HEADERS=("X-Frame-Options" "X-XSS-Protection" "X-Content-Type-Options" "Content-Security-Policy" "Strict-Transport-Security")
        HEADERS_FOUND=0
        
        if [ "$APACHE_CMD" = "apache2" ] && [ -d "/etc/apache2/conf-enabled" ]; then
            for header in "${SECURITY_HEADERS[@]}"; do
                if grep -r "$header" /etc/apache2/conf-enabled/ /etc/apache2/sites-enabled/ &> /dev/null; then
                    HEADERS_FOUND=$((HEADERS_FOUND+1))
                fi
            done
        elif [ "$APACHE_CMD" = "httpd" ] && [ -d "/etc/httpd/conf.d" ]; then
            for header in "${SECURITY_HEADERS[@]}"; do
                if grep -r "$header" /etc/httpd/conf.d/ &> /dev/null; then
                    HEADERS_FOUND=$((HEADERS_FOUND+1))
                fi
            done
        fi
        
        if [ "$HEADERS_FOUND" -eq ${#SECURITY_HEADERS[@]} ]; then
            log "SUCCESS" "Todas las cabeceras de seguridad están configuradas"
            echo "- **Cabeceras de seguridad**: Todas configuradas" >> "$OUTPUT_FILE"
        elif [ "$HEADERS_FOUND" -gt 0 ]; then
            log "WARNING" "Solo $HEADERS_FOUND de ${#SECURITY_HEADERS[@]} cabeceras de seguridad están configuradas"
            echo "- **Cabeceras de seguridad**: $HEADERS_FOUND de ${#SECURITY_HEADERS[@]} configuradas" >> "$OUTPUT_FILE"
        else
            log "CRITICAL" "No se encontraron cabeceras de seguridad"
            echo "- **Cabeceras de seguridad**: No configuradas" >> "$OUTPUT_FILE"
        fi
    else
        log "INFO" "Apache no está instalado"
        echo "- **Apache instalado**: No" >> "$OUTPUT_FILE"
    fi
    
    # Verificar Nginx
    if command -v nginx &> /dev/null; then
        log "SUCCESS" "Nginx está instalado"
        echo "" >> "$OUTPUT_FILE"
        echo "- **Nginx instalado**: Sí" >> "$OUTPUT_FILE"
        
        # Verificar versión de Nginx
        NGINX_VERSION=$(nginx -v 2>&1 | awk -F'/' '{print $2}')
        echo "- **Versión de Nginx**: $NGINX_VERSION" >> "$OUTPUT_FILE"
        
        # Verificar estado de Nginx
        if command -v systemctl &> /dev/null; then
            if systemctl is-active --quiet nginx; then
                log "SUCCESS" "Nginx está activo"
                echo "- **Estado de Nginx**: Activo" >> "$OUTPUT_FILE"
            else
                log "WARNING" "Nginx no está activo"
                echo "- **Estado de Nginx**: Inactivo" >> "$OUTPUT_FILE"
            fi
        elif command -v service &> /dev/null; then
            if service nginx status &> /dev/null; then
                log "SUCCESS" "Nginx está activo"
                echo "- **Estado de Nginx**: Activo" >> "$OUTPUT_FILE"
            else
                log "WARNING" "Nginx no está activo"
                echo "- **Estado de Nginx**: Inactivo" >> "$OUTPUT_FILE"
            fi
        fi
        
        # Verificar configuración de seguridad de Nginx
        echo "" >> "$OUTPUT_FILE"
        echo "### Configuración de Seguridad de Nginx" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        
        # Verificar configuración SSL
        if [ -d "/etc/nginx/sites-enabled" ]; then
            SSL_SITES=$(grep -l "ssl_certificate" /etc/nginx/sites-enabled/* 2>/dev/null | wc -l)
            if [ "$SSL_SITES" -gt 0 ]; then
                log "SUCCESS" "SSL está habilitado en $SSL_SITES sitios"
                echo "- **SSL habilitado**: Sí (en $SSL_SITES sitios)" >> "$OUTPUT_FILE"
            else
                log "WARNING" "SSL no está habilitado en ningún sitio"
                echo "- **SSL habilitado**: No" >> "$OUTPUT_FILE"
            fi
        elif [ -d "/etc/nginx/conf.d" ]; then
            SSL_SITES=$(grep -l "ssl_certificate" /etc/nginx/conf.d/* 2>/dev/null | wc -l)
            if [ "$SSL_SITES" -gt 0 ]; then
                log "SUCCESS" "SSL está habilitado en $SSL_SITES sitios"
                echo "- **SSL habilitado**: Sí (en $SSL_SITES sitios)" >> "$OUTPUT_FILE"
            else
                log "WARNING" "SSL no está habilitado en ningún sitio"
                echo "- **SSL habilitado**: No" >> "$OUTPUT_FILE"
            fi
        fi
        
        # Verificar cabeceras de seguridad
        SECURITY_HEADERS=("X-Frame-Options" "X-XSS-Protection" "X-Content-Type-Options" "Content-Security-Policy" "Strict-Transport-Security")
        HEADERS_FOUND=0
        
        if [ -d "/etc/nginx/conf.d" ]; then
            for header in "${SECURITY_HEADERS[@]}"; do
                if grep -r "$header" /etc/nginx/conf.d/ &> /dev/null; then
                    HEADERS_FOUND=$((HEADERS_FOUND+1))
                fi
            done
        fi
        
        if [ -d "/etc/nginx/sites-enabled" ]; then
            for header in "${SECURITY_HEADERS[@]}"; do
                if grep -r "$header" /etc/nginx/sites-enabled/ &> /dev/null; then
                    HEADERS_FOUND=$((HEADERS_FOUND+1))
                fi
            done
        fi
        
        if [ "$HEADERS_FOUND" -eq ${#SECURITY_HEADERS[@]} ]; then
            log "SUCCESS" "Todas las cabeceras de seguridad están configuradas"
            echo "- **Cabeceras de seguridad**: Todas configuradas" >> "$OUTPUT_FILE"
        elif [ "$HEADERS_FOUND" -gt 0 ]; then
            log "WARNING" "Solo $HEADERS_FOUND de ${#SECURITY_HEADERS[@]} cabeceras de seguridad están configuradas"
            echo "- **Cabeceras de seguridad**: $HEADERS_FOUND de ${#SECURITY_HEADERS[@]} configuradas" >> "$OUTPUT_FILE"
        else
            log "CRITICAL" "No se encontraron cabeceras de seguridad"
            echo "- **Cabeceras de seguridad**: No configuradas" >> "$OUTPUT_FILE"
        fi
    else
        log "INFO" "Nginx no está instalado"
        echo "- **Nginx instalado**: No" >> "$OUTPUT_FILE"
    fi
    
    echo "" >> "$OUTPUT_FILE"
    log "SUCCESS" "Verificación del servidor web completada"
}

# Función para verificar la base de datos (MySQL/MariaDB/PostgreSQL)
check_database() {
    echo "## Base de Datos" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    log "INFO" "Verificando base de datos..."
    
    # Verificar MySQL/MariaDB
    if command -v mysql &> /dev/null; then
        log "SUCCESS" "MySQL/MariaDB está instalado"
        echo "- **MySQL/MariaDB instalado**: Sí" >> "$OUTPUT_FILE"
        
        # Verificar versión de MySQL/MariaDB
        MYSQL_VERSION=$(mysql --version | awk '{print $3}')
        echo "- **Versión de MySQL/MariaDB**: $MYSQL_VERSION" >> "$OUTPUT_FILE"
        
        # Verificar estado de MySQL/MariaDB
        if command -v systemctl &> /dev/null; then
            if systemctl is-active --quiet mysql || systemctl is-active --quiet mariadb; then
                log "SUCCESS" "MySQL/MariaDB está activo"
                echo "- **Estado de MySQL/MariaDB**: Activo" >> "$OUTPUT_FILE"
            else
                log "WARNING" "MySQL/MariaDB no está activo"
                echo "- **Estado de MySQL/MariaDB**: Inactivo" >> "$OUTPUT_FILE"
            fi
        elif command -v service &> /dev/null; then
            if service mysql status &> /dev/null || service mariadb status &> /dev/null; then
                log "SUCCESS" "MySQL/MariaDB está activo"
                echo "- **Estado de MySQL/MariaDB**: Activo" >> "$OUTPUT_FILE"
            else
                log "WARNING" "MySQL/MariaDB no está activo"
                echo "- **Estado de MySQL/MariaDB**: Inactivo" >> "$OUTPUT_FILE"
            fi
        fi
        
        # Verificar configuración de seguridad de MySQL/MariaDB
        echo "" >> "$OUTPUT_FILE"
        echo "### Configuración de Seguridad de MySQL/MariaDB" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        
        # Verificar si se puede acceder sin contraseña
        if mysql -u root 2>/dev/null <<< "exit" &> /dev/null; then
            log "CRITICAL" "Se puede acceder a MySQL/MariaDB como root sin contraseña"
            echo "- **Acceso sin contraseña**: Sí (INSEGURO)" >> "$OUTPUT_FILE"
        else
            log "SUCCESS" "No se puede acceder a MySQL/MariaDB como root sin contraseña"
            echo "- **Acceso sin contraseña**: No" >> "$OUTPUT_FILE"
        fi
        
        # Verificar usuarios anónimos
        ANONYMOUS_USERS=$(mysql -u root -e "SELECT User FROM mysql.user WHERE User='';" 2>/dev/null | grep -v User | wc -l)
        if [ "$ANONYMOUS_USERS" -gt 0 ]; then
            log "CRITICAL" "Existen $ANONYMOUS_USERS usuarios anónimos en MySQL/MariaDB"
            echo "- **Usuarios anónimos**: $ANONYMOUS_USERS (INSEGURO)" >> "$OUTPUT_FILE"
        else
            log "SUCCESS" "No existen usuarios anónimos en MySQL/MariaDB"
            echo "- **Usuarios anónimos**: 0" >> "$OUTPUT_FILE"
        fi
        
        # Verificar usuarios con acceso remoto
        REMOTE_USERS=$(mysql -u root -e "SELECT User FROM mysql.user WHERE Host='%';" 2>/dev/null | grep -v User | wc -l)
        if [ "$REMOTE_USERS" -gt 0 ]; then
            log "WARNING" "Existen $REMOTE_USERS usuarios con acceso remoto en MySQL/MariaDB"
            echo "- **Usuarios con acceso remoto**: $REMOTE_USERS" >> "$OUTPUT_FILE"
        else
            log "SUCCESS" "No existen usuarios con acceso remoto en MySQL/MariaDB"
            echo "- **Usuarios con acceso remoto**: 0" >> "$OUTPUT_FILE"
        fi
        
        # Verificar si MySQL/MariaDB está escuchando en todas las interfaces
        if netstat -tuln | grep -q "0.0.0.0:3306"; then
            log "WARNING" "MySQL/MariaDB está escuchando en todas las interfaces"
            echo "- **Escuchando en todas las interfaces**: Sí" >> "$OUTPUT_FILE"
        else
            log "SUCCESS" "MySQL/MariaDB no está escuchando en todas las interfaces"
            echo "- **Escuchando en todas las interfaces**: No" >> "$OUTPUT_FILE"
        fi
    else
        log "INFO" "MySQL/MariaDB no está instalado"
        echo "- **MySQL/MariaDB instalado**: No" >> "$OUTPUT_FILE"
    fi
    
    # Verificar PostgreSQL
    if command -v psql &> /dev/null; then
        log "SUCCESS" "PostgreSQL está instalado"
        echo "" >> "$OUTPUT_FILE"
        echo "- **PostgreSQL instalado**: Sí" >> "$OUTPUT_FILE"
        
        # Verificar versión de PostgreSQL
        POSTGRESQL_VERSION=$(psql --version | awk '{print $3}')
        echo "- **Versión de PostgreSQL**: $POSTGRESQL_VERSION" >> "$OUTPUT_FILE"
        
        # Verificar estado de PostgreSQL
        if command -v systemctl &> /dev/null; then
            if systemctl is-active --quiet postgresql; then
                log "SUCCESS" "PostgreSQL está activo"
                echo "- **Estado de PostgreSQL**: Activo" >> "$OUTPUT_FILE"
            else
                log "WARNING" "PostgreSQL no está activo"
                echo "- **Estado de PostgreSQL**: Inactivo" >> "$OUTPUT_FILE"
            fi
        elif command -v service &> /dev/null; then
            if service postgresql status &> /dev/null; then
                log "SUCCESS" "PostgreSQL está activo"
                echo "- **Estado de PostgreSQL**: Activo" >> "$OUTPUT_FILE"
            else
                log "WARNING" "PostgreSQL no está activo"
                echo "- **Estado de PostgreSQL**: Inactivo" >> "$OUTPUT_FILE"
            fi
        fi
        
        # Verificar configuración de seguridad de PostgreSQL
        echo "" >> "$OUTPUT_FILE"
        echo "### Configuración de Seguridad de PostgreSQL" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        
        # Verificar si PostgreSQL está escuchando en todas las interfaces
        if netstat -tuln | grep -q "0.0.0.0:5432"; then
            log "WARNING" "PostgreSQL está escuchando en todas las interfaces"
            echo "- **Escuchando en todas las interfaces**: Sí" >> "$OUTPUT_FILE"
        else
            log "SUCCESS" "PostgreSQL no está escuchando en todas las interfaces"
            echo "- **Escuchando en todas las interfaces**: No" >> "$OUTPUT_FILE"
        fi
    else
        log "INFO" "PostgreSQL no está instalado"
        echo "- **PostgreSQL instalado**: No" >> "$OUTPUT_FILE"
    fi
    
    echo "" >> "$OUTPUT_FILE"
    log "SUCCESS" "Verificación de la base de datos completada"
}

# Función para verificar el firewall
check_firewall() {
    echo "## Firewall" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    log "INFO" "Verificando firewall..."
    
    # Verificar UFW
    if command -v ufw &> /dev/null; then
        log "SUCCESS" "UFW está instalado"
        echo "- **UFW instalado**: Sí" >> "$OUTPUT_FILE"
        
        # Verificar estado de UFW
        UFW_STATUS=$(ufw status | grep Status | awk '{print $2}')
        echo "- **Estado de UFW**: $UFW_STATUS" >> "$OUTPUT_FILE"
        
        if [ "$UFW_STATUS" = "active" ]; then
            log "SUCCESS" "UFW está activo"
            
            # Verificar reglas de UFW
            echo "" >> "$OUTPUT_FILE"
            echo "### Reglas de UFW" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
            echo '```' >> "$OUTPUT_FILE"
            ufw status verbose >> "$OUTPUT_FILE"
            echo '```' >> "$OUTPUT_FILE"
        else
            log "CRITICAL" "UFW no está activo"
        fi
    else
        log "INFO" "UFW no está instalado"
        echo "- **UFW instalado**: No" >> "$OUTPUT_FILE"
    fi
    
    # Verificar firewalld
    if command -v firewall-cmd &> /dev/null; then
        log "SUCCESS" "firewalld está instalado"
        echo "" >> "$OUTPUT_FILE"
        echo "- **firewalld instalado**: Sí" >> "$OUTPUT_FILE"
        
        # Verificar estado de firewalld
        if systemctl is-active --quiet firewalld; then
            log "SUCCESS" "firewalld está activo"
            echo "- **Estado de firewalld**: Activo" >> "$OUTPUT_FILE"
            
            # Verificar reglas de firewalld
            echo "" >> "$OUTPUT_FILE"
            echo "### Reglas de firewalld" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
            echo '```' >> "$OUTPUT_FILE"
            firewall-cmd --list-all >> "$OUTPUT_FILE"
            echo '```' >> "$OUTPUT_FILE"
        else
            log "CRITICAL" "firewalld no está activo"
            echo "- **Estado de firewalld**: Inactivo" >> "$OUTPUT_FILE"
        fi
    else
        log "INFO" "firewalld no está instalado"
        echo "- **firewalld instalado**: No" >> "$OUTPUT_FILE"
    fi
    
    # Verificar iptables
    if command -v iptables &> /dev/null && ! command -v ufw &> /dev/null && ! command -v firewall-cmd &> /dev/null; then
        log "SUCCESS" "iptables está instalado"
        echo "" >> "$OUTPUT_FILE"
        echo "- **iptables instalado**: Sí" >> "$OUTPUT_FILE"
        
        # Verificar reglas de iptables
        IPTABLES_RULES=$(iptables -L -n | grep -v "Chain" | grep -v "target" | grep -v "^$" | wc -l)
        echo "- **Reglas de iptables**: $IPTABLES_RULES" >> "$OUTPUT_FILE"
        
        if [ "$IPTABLES_RULES" -gt 0 ]; then
            log "SUCCESS" "iptables tiene $IPTABLES_RULES reglas configuradas"
            
            # Verificar reglas de iptables
            echo "" >> "$OUTPUT_FILE"
            echo "### Reglas de iptables" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
            echo '```' >> "$OUTPUT_FILE"
            iptables -L -n >> "$OUTPUT_FILE"
            echo '```' >> "$OUTPUT_FILE"
        else
            log "CRITICAL" "iptables no tiene reglas configuradas"
        fi
    else
        if ! command -v ufw &> /dev/null && ! command -v firewall-cmd &> /dev/null; then
            log "INFO" "iptables no está siendo utilizado como firewall principal"
            echo "- **iptables como firewall principal**: No" >> "$OUTPUT_FILE"
        fi
    fi
    
    # Verificar pf (macOS/FreeBSD)
    if command -v pfctl &> /dev/null; then
        log "SUCCESS" "pf está instalado"
        echo "" >> "$OUTPUT_FILE"
        echo "- **pf instalado**: Sí" >> "$OUTPUT_FILE"
        
        # Verificar estado de pf
        if pfctl -s info | grep -q "Status: Enabled"; then
            log "SUCCESS" "pf está activo"
            echo "- **Estado de pf**: Activo" >> "$OUTPUT_FILE"
            
            # Verificar reglas de pf
            echo "" >> "$OUTPUT_FILE"
            echo "### Reglas de pf" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
            echo '```' >> "$OUTPUT_FILE"
            pfctl -s rules >> "$OUTPUT_FILE"
            echo '```' >> "$OUTPUT_FILE"
        else
            log "CRITICAL" "pf no está activo"
            echo "- **Estado de pf**: Inactivo" >> "$OUTPUT_FILE"
        fi
    else
        log "INFO" "pf no está instalado"
        echo "- **pf instalado**: No" >> "$OUTPUT_FILE"
    fi
    
    # Verificar si hay algún firewall activo
    if ! command -v ufw &> /dev/null && ! command -v firewall-cmd &> /dev/null && ! command -v iptables &> /dev/null && ! command -v pfctl &> /dev/null; then
        log "CRITICAL" "No se encontró ningún firewall instalado"
        echo "- **Firewall instalado**: No (INSEGURO)" >> "$OUTPUT_FILE"
    elif ! (systemctl is-active --quiet firewalld 2>/dev/null || ufw status | grep -q "Status: active" || (command -v iptables &> /dev/null && [ "$(iptables -L -n | grep -v "Chain" | grep -v "target" | grep -v "^$" | wc -l)" -gt 0 ]) || (command -v pfctl &> /dev/null && pfctl -s info | grep -q "Status: Enabled")); then
        log "CRITICAL" "Hay un firewall instalado pero no está activo"
        echo "- **Firewall activo**: No (INSEGURO)" >> "$OUTPUT_FILE"
    fi
    
    echo "" >> "$OUTPUT_FILE"
    log "SUCCESS" "Verificación del firewall completada"
}

# Función para verificar SSH
check_ssh() {
    echo "## SSH" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    log "INFO" "Verificando SSH..."
    
    # Verificar si SSH está instalado
    if command -v ssh &> /dev/null; then
        log "SUCCESS" "SSH está instalado"
        echo "- **SSH instalado**: Sí" >> "$OUTPUT_FILE"
        
        # Verificar versión de SSH
        SSH_VERSION=$(ssh -V 2>&1 | awk '{print $1}' | cut -d'_' -f2)
        echo "- **Versión de SSH**: $SSH_VERSION" >> "$OUTPUT_FILE"
        
        # Verificar estado de SSH
        if command -v systemctl &> /dev/null; then
            if systemctl is-active --quiet sshd; then
                log "SUCCESS" "SSH está activo"
                echo "- **Estado de SSH**: Activo" >> "$OUTPUT_FILE"
            else
                log "WARNING" "SSH no está activo"
                echo "- **Estado de SSH**: Inactivo" >> "$OUTPUT_FILE"
            fi
        elif command -v service &> /dev/null; then
            if service sshd status &> /dev/null || service ssh status &> /dev/null; then
                log "SUCCESS" "SSH está activo"
                echo "- **Estado de SSH**: Activo" >> "$OUTPUT_FILE"
            else
                log "WARNING" "SSH no está activo"
                echo "- **Estado de SSH**: Inactivo" >> "$OUTPUT_FILE"
            fi
        fi
        
        # Verificar configuración de seguridad de SSH
        echo "" >> "$OUTPUT_FILE"
        echo "### Configuración de Seguridad de SSH" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        
        if [ -f "/etc/ssh/sshd_config" ]; then
            # Verificar si se permite el inicio de sesión como root
            if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config; then
                log "CRITICAL" "Se permite el inicio de sesión como root en SSH"
                echo "- **Inicio de sesión como root**: Permitido (INSEGURO)" >> "$OUTPUT_FILE"
            else
                log "SUCCESS" "No se permite el inicio de sesión como root en SSH"
                echo "- **Inicio de sesión como root**: No permitido" >> "$OUTPUT_FILE"
            fi
            
            # Verificar si se permite la autenticación por contraseña
            if grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config; then
                log "WARNING" "Se permite la autenticación por contraseña en SSH"
                echo "- **Autenticación por contraseña**: Permitida" >> "$OUTPUT_FILE"
            else
                log "SUCCESS" "No se permite la autenticación por contraseña en SSH"
                echo "- **Autenticación por contraseña**: No permitida" >> "$OUTPUT_FILE"
            fi
            
            # Verificar si se permite la autenticación por clave pública
            if grep -q "^PubkeyAuthentication yes" /etc/ssh/sshd_config; then
                log "SUCCESS" "Se permite la autenticación por clave pública en SSH"
                echo "- **Autenticación por clave pública**: Permitida" >> "$OUTPUT_FILE"
            else
                log "WARNING" "No se permite la autenticación por clave pública en SSH"
                echo "- **Autenticación por clave pública**: No permitida" >> "$OUTPUT_FILE"
            fi
            
            # Verificar si se permite el protocolo SSH 1
            if grep -q "^Protocol 1" /etc/ssh/sshd_config; then
                log "CRITICAL" "Se permite el protocolo SSH 1 (inseguro)"
                echo "- **Protocolo SSH 1**: Permitido (INSEGURO)" >> "$OUTPUT_FILE"
            else
                log "SUCCESS" "No se permite el protocolo SSH 1"
                echo "- **Protocolo SSH 1**: No permitido" >> "$OUTPUT_FILE"
            fi
            
            # Verificar si se ha configurado un tiempo de inactividad
            if grep -q "^ClientAliveInterval" /etc/ssh/sshd_config; then
                CLIENT_ALIVE_INTERVAL=$(grep "^ClientAliveInterval" /etc/ssh/sshd_config | awk '{print $2}')
                echo "- **Tiempo de inactividad**: $CLIENT_ALIVE_INTERVAL segundos" >> "$OUTPUT_FILE"
                
                if [ "$CLIENT_ALIVE_INTERVAL" -gt 300 ]; then
                    log "WARNING" "El tiempo de inactividad es demasiado largo (>300 segundos)"
                else
                    log "SUCCESS" "El tiempo de inactividad es adecuado"
                fi
            else
                log "WARNING" "No se ha configurado un tiempo de inactividad"
                echo "- **Tiempo de inactividad**: No configurado" >> "$OUTPUT_FILE"
            fi
            
            # Verificar si se ha configurado un número máximo de intentos de autenticación
            if grep -q "^MaxAuthTries" /etc/ssh/sshd_config; then
                MAX_AUTH_TRIES=$(grep "^MaxAuthTries" /etc/ssh/sshd_config | awk '{print $2}')
                echo "- **Intentos máximos de autenticación**: $MAX_AUTH_TRIES" >> "$OUTPUT_FILE"
                
                if [ "$MAX_AUTH_TRIES" -gt 6 ]; then
                    log "WARNING" "El número máximo de intentos de autenticación es demasiado alto (>6)"
                else
                    log "SUCCESS" "El número máximo de intentos de autenticación es adecuado"
                fi
            else
                log "WARNING" "No se ha configurado un número máximo de intentos de autenticación"
                echo "- **Intentos máximos de autenticación**: No configurado" >> "$OUTPUT_FILE"
            fi
            
            # Verificar si se ha configurado un puerto personalizado
            if grep -q "^Port" /etc/ssh/sshd_config; then
                SSH_PORT=$(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}')
                echo "- **Puerto SSH**: $SSH_PORT" >> "$OUTPUT_FILE"
                
                if [ "$SSH_PORT" = "22" ]; then
                    log "WARNING" "Se está utilizando el puerto SSH predeterminado (22)"
                else
                    log "SUCCESS" "Se está utilizando un puerto SSH personalizado"
                fi
            else
                log "WARNING" "No se ha configurado un puerto SSH personalizado"
                echo "- **Puerto SSH**: 22 (predeterminado)" >> "$OUTPUT_FILE"
            fi
        else
            log "ERROR" "No se encontró el archivo de configuración de SSH"
            echo "- **Archivo de configuración**: No encontrado" >> "$OUTPUT_FILE"
        fi
    else
        log "INFO" "SSH no está instalado"
        echo "- **SSH instalado**: No" >> "$OUTPUT_FILE"
    fi
    
    echo "" >> "$OUTPUT_FILE"
    log "SUCCESS" "Verificación de SSH completada"
}

# Función para verificar los permisos de archivos críticos
check_file_permissions() {
    echo "## Permisos de Archivos Críticos" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    log "INFO" "Verificando permisos de archivos críticos..."
    
    # Definir archivos críticos y sus permisos recomendados
    declare -A CRITICAL_FILES
    CRITICAL_FILES["Webmin SSL Certificate"]="/etc/webmin/miniserv.pem:400"
    CRITICAL_FILES["Webmin SSL Key"]="/etc/webmin/miniserv.key:400"
    CRITICAL_FILES["Webmin Configuration"]="/etc/webmin/miniserv.conf:600"
    CRITICAL_FILES["Webmin Users"]="/etc/webmin/miniserv.users:600"
    CRITICAL_FILES["SSH Configuration"]="/etc/ssh/sshd_config:600"
    CRITICAL_FILES["SSH Host Key"]="/etc/ssh/ssh_host_rsa_key:600"
    CRITICAL_FILES["SSH Host Public Key"]="/etc/ssh/ssh_host_rsa_key.pub:644"
    CRITICAL_FILES["Apache Configuration"]="/etc/apache2/apache2.conf:644"
    CRITICAL_FILES["Nginx Configuration"]="/etc/nginx/nginx.conf:644"
    CRITICAL_FILES["MySQL Configuration"]="/etc/mysql/my.cnf:644"
    CRITICAL_FILES["PostgreSQL Configuration"]="/etc/postgresql/*/main/postgresql.conf:644"
    
    # Verificar permisos de archivos críticos
    for file_name in "${!CRITICAL_FILES[@]}"; do
        file_path=$(echo "${CRITICAL_FILES[$file_name]}" | cut -d':' -f1)
        expected_perm=$(echo "${CRITICAL_FILES[$file_name]}" | cut -d':' -f2)
        
        # Expandir comodines en la ruta del archivo
        for expanded_file in $file_path; do
            if [ -f "$expanded_file" ]; then
                # Obtener permisos actuales
                current_perm=$(stat -c "%a" "$expanded_file" 2>/dev/null || stat -f "%Lp" "$expanded_file" 2>/dev/null)
                
                echo "- **$file_name**: $expanded_file (Permisos actuales: $current_perm, Recomendados: $expected_perm)" >> "$OUTPUT_FILE"
                
                if [ "$current_perm" != "$expected_perm" ]; then
                    log "WARNING" "Permisos incorrectos en $expanded_file: $current_perm (debería ser $expected_perm)"
                else
                    log "SUCCESS" "Permisos correctos en $expanded_file: $current_perm"
                fi
            fi
        done
    done
    
    echo "" >> "$OUTPUT_FILE"
    log "SUCCESS" "Verificación de permisos de archivos críticos completada"
}

# Función para verificar actualizaciones pendientes
check_updates() {
    echo "## Actualizaciones Pendientes" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    log "INFO" "Verificando actualizaciones pendientes..."
    
    # Detectar sistema operativo
    detect_os
    
    # Verificar actualizaciones pendientes según el sistema operativo
    case "$OS" in
        "Ubuntu"|"Debian")
            apt-get update -qq &>/dev/null
            UPDATES=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." | wc -l)
            SECURITY_UPDATES=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)
            
            echo "- **Actualizaciones pendientes**: $UPDATES" >> "$OUTPUT_FILE"
            echo "- **Actualizaciones de seguridad pendientes**: $SECURITY_UPDATES" >> "$OUTPUT_FILE"
            
            if [ "$SECURITY_UPDATES" -gt 0 ]; then
                log "CRITICAL" "Hay $SECURITY_UPDATES actualizaciones de seguridad pendientes"
            elif [ "$UPDATES" -gt 0 ]; then
                log "WARNING" "Hay $UPDATES actualizaciones pendientes"
            else
                log "SUCCESS" "No hay actualizaciones pendientes"
            fi
            ;;
        "CentOS"|"RedHat"|"Fedora")
            if command -v dnf &> /dev/null; then
                UPDATES=$(dnf check-update -q 2>/dev/null | grep -v "^$" | wc -l)
                SECURITY_UPDATES=$(dnf check-update --security -q 2>/dev/null | grep -v "^$" | wc -l)
            else
                UPDATES=$(yum check-update -q 2>/dev/null | grep -v "^$" | wc -l)
                SECURITY_UPDATES=$(yum check-update --security -q 2>/dev/null | grep -v "^$" | wc -l)
            fi
            
            echo "- **Actualizaciones pendientes**: $UPDATES" >> "$OUTPUT_FILE"
            echo "- **Actualizaciones de seguridad pendientes**: $SECURITY_UPDATES" >> "$OUTPUT_FILE"
            
            if [ "$SECURITY_UPDATES" -gt 0 ]; then
                log "CRITICAL" "Hay $SECURITY_UPDATES actualizaciones de seguridad pendientes"
            elif [ "$UPDATES" -gt 0 ]; then
                log "WARNING" "Hay $UPDATES actualizaciones pendientes"
            else
                log "SUCCESS" "No hay actualizaciones pendientes"
            fi
            ;;
        "macOS")
            UPDATES=$(softwareupdate -l 2>/dev/null | grep -i "recommended" | wc -l)
            
            echo "- **Actualizaciones pendientes**: $UPDATES" >> "$OUTPUT_FILE"
            
            if [ "$UPDATES" -gt 0 ]; then
                log "WARNING" "Hay $UPDATES actualizaciones pendientes"
            else
                log "SUCCESS" "No hay actualizaciones pendientes"
            fi
            ;;
        *)
            log "WARNING" "No se pudo verificar las actualizaciones pendientes: Sistema operativo no soportado"
            echo "- **Actualizaciones pendientes**: No disponible" >> "$OUTPUT_FILE"
            ;;
    esac
    
    # Verificar actualizaciones pendientes de Webmin
    if [ -d "/etc/webmin" ]; then
        if [ -f "/usr/share/webmin/update.pl" ]; then
            cd /usr/share/webmin
            WEBMIN_UPDATES=$(/usr/share/webmin/update.pl --check 2>/dev/null | grep -i "update" | wc -l)
        elif [ -f "/usr/libexec/webmin/update.pl" ]; then
            cd /usr/libexec/webmin
            WEBMIN_UPDATES=$(/usr/libexec/webmin/update.pl --check 2>/dev/null | grep -i "update" | wc -l)
        else
            WEBMIN_UPDATES="No disponible"
        fi
        
        echo "- **Actualizaciones pendientes de Webmin**: $WEBMIN_UPDATES" >> "$OUTPUT_FILE"
        
        if [ "$WEBMIN_UPDATES" != "No disponible" ] && [ "$WEBMIN_UPDATES" -gt 0 ]; then
            log "WARNING" "Hay $WEBMIN_UPDATES actualizaciones pendientes de Webmin"
        elif [ "$WEBMIN_UPDATES" != "No disponible" ]; then
            log "SUCCESS" "No hay actualizaciones pendientes de Webmin"
        fi
    fi
    
    echo "" >> "$OUTPUT_FILE"
    log "SUCCESS" "Verificación de actualizaciones pendientes completada"
}

# Función para verificar los servicios críticos
check_critical_services() {
    echo "## Servicios Críticos" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    log "INFO" "Verificando servicios críticos..."
    
    # Definir servicios críticos
    CRITICAL_SERVICES=("webmin" "apache2" "httpd" "nginx" "mysql" "mariadb" "postgresql" "sshd" "ssh" "fail2ban" "ufw" "firewalld" "iptables" "postfix" "dovecot")
    
    # Verificar estado de servicios críticos
    for service in "${CRITICAL_SERVICES[@]}"; do
        if command -v systemctl &> /dev/null; then
            if systemctl is-enabled $service &>/dev/null; then
                if systemctl is-active --quiet $service; then
                    log "SUCCESS" "$service está activo"
                    echo "- **$service**: Activo" >> "$OUTPUT_FILE"
                else
                    log "WARNING" "$service no está activo"
                    echo "- **$service**: Inactivo" >> "$OUTPUT_FILE"
                fi
            elif systemctl is-enabled $service &>/dev/null; then
                log "WARNING" "$service está habilitado pero no activo"
                echo "- **$service**: Habilitado pero inactivo" >> "$OUTPUT_FILE"
            fi
        elif command -v service &> /dev/null; then
            if service $service status &>/dev/null; then
                log "SUCCESS" "$service está activo"
                echo "- **$service**: Activo" >> "$OUTPUT_FILE"
            else
                log "WARNING" "$service no está activo"
                echo "- **$service**: Inactivo" >> "$OUTPUT_FILE"
            fi
        fi
    done
    
    echo "" >> "$OUTPUT_FILE"
    log "SUCCESS" "Verificación de servicios críticos completada"
}

# Función para verificar los puertos abiertos
check_open_ports() {
    echo "## Puertos Abiertos" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    log "INFO" "Verificando puertos abiertos..."
    
    # Verificar puertos abiertos
    if command -v netstat &> /dev/null; then
        echo "### Puertos TCP abiertos" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        echo '```' >> "$OUTPUT_FILE"
        netstat -tuln | grep "LISTEN" >> "$OUTPUT_FILE"
        echo '```' >> "$OUTPUT_FILE"
    elif command -v ss &> /dev/null; then
        echo "### Puertos TCP abiertos" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        echo '```' >> "$OUTPUT_FILE"
        ss -tuln | grep "LISTEN" >> "$OUTPUT_FILE"
        echo '```' >> "$OUTPUT_FILE"
    else
        log "WARNING" "No se pudo verificar los puertos abiertos: netstat y ss no están disponibles"
        echo "- **Puertos abiertos**: No disponible" >> "$OUTPUT_FILE"
    fi
    
    # Verificar puertos comunes
    COMMON_PORTS=(22 80 443 3306 10000)
    COMMON_PORT_NAMES=("SSH" "HTTP" "HTTPS" "MySQL" "Webmin")
    
    echo "" >> "$OUTPUT_FILE"
    echo "### Puertos comunes" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    for i in "${!COMMON_PORTS[@]}"; do
        PORT=${COMMON_PORTS[$i]}
        PORT_NAME=${COMMON_PORT_NAMES[$i]}
        
        if netstat -tuln 2>/dev/null | grep -q ":$PORT " || ss -tuln 2>/dev/null | grep -q ":$PORT "; then
            log "INFO" "Puerto $PORT ($PORT_NAME) está abierto"
            echo "- **Puerto $PORT ($PORT_NAME)**: Abierto" >> "$OUTPUT_FILE"
        else
            log "INFO" "Puerto $PORT ($PORT_NAME) está cerrado"
            echo "- **Puerto $PORT ($PORT_NAME)**: Cerrado" >> "$OUTPUT_FILE"
        fi
    done
    
    echo "" >> "$OUTPUT_FILE"
    log "SUCCESS" "Verificación de puertos abiertos completada"
}

# Función para verificar los registros de seguridad
check_security_logs() {
    echo "## Registros de Seguridad" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    log "INFO" "Verificando registros de seguridad..."
    
    # Verificar intentos fallidos de inicio de sesión SSH
    if [ -f "/var/log/auth.log" ]; then
        SSH_FAILED_ATTEMPTS=$(grep "Failed password" /var/log/auth.log | wc -l)
        echo "- **Intentos fallidos de inicio de sesión SSH**: $SSH_FAILED_ATTEMPTS" >> "$OUTPUT_FILE"
        
        if [ "$SSH_FAILED_ATTEMPTS" -gt 10 ]; then
            log "WARNING" "Se detectaron $SSH_FAILED_ATTEMPTS intentos fallidos de inicio de sesión SSH"
        else
            log "SUCCESS" "Se detectaron pocos intentos fallidos de inicio de sesión SSH"
        fi
    elif [ -f "/var/log/secure" ]; then
        SSH_FAILED_ATTEMPTS=$(grep "Failed password" /var/log/secure | wc -l)
        echo "- **Intentos fallidos de inicio de sesión SSH**: $SSH_FAILED_ATTEMPTS" >> "$OUTPUT_FILE"
        
        if [ "$SSH_FAILED_ATTEMPTS" -gt 10 ]; then
            log "WARNING" "Se detectaron $SSH_FAILED_ATTEMPTS intentos fallidos de inicio de sesión SSH"
        else
            log "SUCCESS" "Se detectaron pocos intentos fallidos de inicio de sesión SSH"
        fi
    else
        log "WARNING" "No se pudo verificar los intentos fallidos de inicio de sesión SSH: archivo de registro no encontrado"
        echo "- **Intentos fallidos de inicio de sesión SSH**: No disponible" >> "$OUTPUT_FILE"
    fi
    
    # Verificar intentos fallidos de inicio de sesión Webmin
    if [ -f "/var/webmin/miniserv.log" ]; then
        WEBMIN_FAILED_ATTEMPTS=$(grep "Login failed" /var/webmin/miniserv.log | wc -l)
        echo "- **Intentos fallidos de inicio de sesión Webmin**: $WEBMIN_FAILED_ATTEMPTS" >> "$OUTPUT_FILE"
        
        if [ "$WEBMIN_FAILED_ATTEMPTS" -gt 10 ]; then
            log "WARNING" "Se detectaron $WEBMIN_FAILED_ATTEMPTS intentos fallidos de inicio de sesión Webmin"
        else
            log "SUCCESS" "Se detectaron pocos intentos fallidos de inicio de sesión Webmin"
        fi
    else
        log "WARNING" "No se pudo verificar los intentos fallidos de inicio de sesión Webmin: archivo de registro no encontrado"
        echo "- **Intentos fallidos de inicio de sesión Webmin**: No disponible" >> "$OUTPUT_FILE"
    fi
    
    # Verificar registros de fail2ban
    if [ -f "/var/log/fail2ban.log" ]; then
        FAIL2BAN_BANS=$(grep "Ban " /var/log/fail2ban.log | wc -l)
        echo "- **Bloqueos de fail2ban**: $FAIL2BAN_BANS" >> "$OUTPUT_FILE"
        
        if [ "$FAIL2BAN_BANS" -gt 10 ]; then
            log "WARNING" "Se detectaron $FAIL2BAN_BANS bloqueos de fail2ban"
        else
            log "SUCCESS" "Se detectaron pocos bloqueos de fail2ban"
        fi
    else
        log "WARNING" "No se pudo verificar los bloqueos de fail2ban: archivo de registro no encontrado"
        echo "- **Bloqueos de fail2ban**: No disponible" >> "$OUTPUT_FILE"
    fi
    
    echo "" >> "$OUTPUT_FILE"
    log "SUCCESS" "Verificación de registros de seguridad completada"
}

# Función para generar un informe HTML
generate_html_report() {
    log "INFO" "Generando informe HTML..."
    
    # Convertir Markdown a HTML
    if command -v pandoc &> /dev/null; then
        pandoc -f markdown -t html "$OUTPUT_FILE" -o "$HTML_FILE" --standalone --metadata title="Informe de Seguridad Webmin/Virtualmin"
        log "SUCCESS" "Informe HTML generado: $HTML_FILE"
    else
        log "ERROR" "No se pudo generar el informe HTML: pandoc no está instalado"
    fi
}

# Función para enviar el informe por correo electrónico
send_email_report() {
    log "INFO" "Enviando informe por correo electrónico a $EMAIL_ADDRESS..."
    
    # Verificar si mail o mailx está instalado
    if command -v mail &> /dev/null; then
        if [ "$HTML_OUTPUT" = true ] && [ -f "$HTML_FILE" ]; then
            echo "Informe de seguridad adjunto." | mail -s "Informe de Seguridad Webmin/Virtualmin - $HOSTNAME - $(date +%Y-%m-%d)" -a "$HTML_FILE" "$EMAIL_ADDRESS"
        else
            cat "$OUTPUT_FILE" | mail -s "Informe de Seguridad Webmin/Virtualmin - $HOSTNAME - $(date +%Y-%m-%d)" "$EMAIL_ADDRESS"
        fi
        log "SUCCESS" "Informe enviado por correo electrónico a $EMAIL_ADDRESS"
    elif command -v mailx &> /dev/null; then
        if [ "$HTML_OUTPUT" = true ] && [ -f "$HTML_FILE" ]; then
            echo "Informe de seguridad adjunto." | mailx -s "Informe de Seguridad Webmin/Virtualmin - $HOSTNAME - $(date +%Y-%m-%d)" -a "$HTML_FILE" "$EMAIL_ADDRESS"
        else
            cat "$OUTPUT_FILE" | mailx -s "Informe de Seguridad Webmin/Virtualmin - $HOSTNAME - $(date +%Y-%m-%d)" "$EMAIL_ADDRESS"
        fi
        log "SUCCESS" "Informe enviado por correo electrónico a $EMAIL_ADDRESS"
    else
        log "ERROR" "No se pudo enviar el informe por correo electrónico: mail o mailx no está instalado"
    fi
}

# Función para mostrar el menú de ayuda
show_help() {
    echo "Uso: $0 [opciones]"
    echo ""
    echo "Opciones:"
    echo "  -h, --help              Muestra esta ayuda"
    echo "  -v, --verbose           Modo detallado"
    echo "  -o, --output FILE       Archivo de salida (por defecto: $OUTPUT_FILE)"
    echo "  -H, --html              Genera un informe HTML"
    echo "  -e, --email ADDRESS     Envía el informe por correo electrónico"
    echo ""
    echo "Ejemplos:"
    echo "  $0 --verbose            Genera un informe detallado"
    echo "  $0 --html               Genera un informe HTML"
    echo "  $0 --email admin@example.com  Envía el informe por correo electrónico"
    echo ""
}

# Función principal
main() {
    # Procesar argumentos
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift
                ;;
            -H|--html)
                HTML_OUTPUT=true
                ;;
            -e|--email)
                EMAIL_REPORT=true
                EMAIL_ADDRESS="$2"
                shift
                ;;
            *)
                echo "Opción desconocida: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
    
    # Mostrar banner
    show_banner
    
    # Inicializar archivo de salida
    echo "# Informe de Seguridad Webmin/Virtualmin" > "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "Generado: $DATE" >> "$OUTPUT_FILE"
    echo "Hostname: $HOSTNAME" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    # Ejecutar verificaciones
    check_system_info
    check_webmin_virtualmin
    check_web_server
    check_database
    check_firewall
    check_ssh
    check_file_permissions
    check_updates
    check_critical_services
    check_open_ports
    check_security_logs
    
    # Generar informe HTML si se solicita
    if [ "$HTML_OUTPUT" = true ]; then
        generate_html_report
    fi
    
    # Enviar informe por correo electrónico si se solicita
    if [ "$EMAIL_REPORT" = true ] && [ -n "$EMAIL_ADDRESS" ]; then
        send_email_report
    fi
    
    log "SUCCESS" "Informe de seguridad generado: $OUTPUT_FILE"
    
    # Mostrar resumen
    echo ""
    echo -e "${GREEN}=== RESUMEN ===${NC}"
    echo "Informe de seguridad generado: $OUTPUT_FILE"
    if [ "$HTML_OUTPUT" = true ]; then
        echo "Informe HTML generado: $HTML_FILE"
    fi
    if [ "$EMAIL_REPORT" = true ] && [ -n "$EMAIL_ADDRESS" ]; then
        echo "Informe enviado por correo electrónico a: $EMAIL_ADDRESS"
    fi
    echo ""
    echo "Para ver el informe completo, ejecute:"
    echo "  cat $OUTPUT_FILE"
    echo ""
}

# Ejecutar la función principal
main "$@"
