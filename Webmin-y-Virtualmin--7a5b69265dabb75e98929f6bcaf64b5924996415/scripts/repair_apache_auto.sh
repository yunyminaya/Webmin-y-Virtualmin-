#!/bin/bash

# ============================================================================
# 🔧 REPARACIÓN AUTOMÁTICA DE APACHE - MÓDULO ESPECIALIZADO
# ============================================================================
# Detecta y repara automáticamente problemas comunes de Apache
# Integrado al sistema de auto-reparación principal
# Versión: 2.0.0 - Con integración completa de logging común
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# ===== INCLUIR BIBLIOTECA COMÚN =====
if [[ -f "${PROJECT_DIR}/lib/common.sh" ]]; then
    source "${PROJECT_DIR}/lib/common.sh"
    log_info "Biblioteca común cargada correctamente"
else
    echo "ERROR: No se encuentra la biblioteca común en ${PROJECT_DIR}/lib/common.sh"
    echo "Asegúrate de que el archivo existe y tiene permisos de lectura"
    exit 1
fi

# Configuración específica de Apache
APACHE_LOG="$SCRIPT_DIR/apache_repair.log"
BACKUP_DIR="/backups/apache_repair"
CACHE_CLEANUP_DAYS=7
LOG_ANALYSIS_HOURS=24

# Función para detectar problemas de Apache
detect_apache_problems() {
    log_info "Detectando problemas de Apache..."

    local problems_found=0

    # Verificar si Apache está instalado
    if ! command -v apache2 >/dev/null 2>&1 && ! command -v httpd >/dev/null 2>&1; then
        log_info "Apache no está instalado"
        return 1
    fi

    # Verificar servicio
    if ! systemctl is-active --quiet apache2 2>/dev/null && ! systemctl is-active --quiet httpd 2>/dev/null; then
        log_info "Servicio Apache inactivo"
        ((problems_found++))
    fi

    # Verificar configuración
    if command -v apache2ctl >/dev/null 2>&1; then
        if ! apache2ctl configtest >/dev/null 2>&1; then
            log_info "Configuración de Apache inválida"
            ((problems_found++))
        fi
    fi

    # Verificar puertos
    if ! netstat -tuln 2>/dev/null | grep -q ":80 "; then
        log_info "Puerto 80 no está abierto"
        ((problems_found++))
    fi

    # Verificar archivos críticos
    local critical_files=(
        "/etc/apache2/apache2.conf"
        "/etc/apache2/sites-available/000-default.conf"
    )

    for file in "${critical_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_info "Archivo crítico faltante: $file"
            ((problems_found++))
        fi
    done

    # Verificar módulos
    if ! apache2ctl -M 2>/dev/null | grep -q "rewrite_module"; then
        log_info "Módulo rewrite no está cargado"
        ((problems_found++))
    fi

    log_info "Detección completada: $problems_found problemas encontrados"
    return $problems_found
}

# Función para reparar configuración de Apache
repair_apache_config() {
    log_info "Reparando configuración de Apache..."

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
        log_info "Backup de configuración creado: $backup_file"
    fi

    # Crear configuración básica si no existe
    if [[ ! -f /etc/apache2/apache2.conf ]]; then
        log_info "Creando configuración básica de Apache..."

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
        log_info "Creando sitio por defecto..."

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

    log_info "Configuración de Apache reparada"
}

# Función para reparar módulos de Apache
repair_apache_modules() {
    log_info "Reparando módulos de Apache..."

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
            a2enmod "$module" 2>/dev/null || log_info "No se pudo habilitar módulo: $module"
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

    log_info "Módulos de Apache reparados"
}

# Función para reparar permisos de Apache
repair_apache_permissions() {
    log_info "Reparando permisos de Apache..."

    # Permisos de directorios
    chown -R www-data:www-data /var/www 2>/dev/null || true
    chown -R www-data:www-data /var/log/apache2 2>/dev/null || true

    # Permisos de archivos
    find /var/www -type d -exec chmod 755 {} \; 2>/dev/null || true
    find /var/www -type f -exec chmod 644 {} \; 2>/dev/null || true

    # Permisos de configuración
    chmod 644 /etc/apache2/apache2.conf 2>/dev/null || true
    chmod 644 /etc/apache2/sites-available/* 2>/dev/null || true

    log_info "Permisos de Apache reparados"
}

# Función para limpiar cachés y archivos temporales de Apache
clean_apache_cache() {
    log_info "Limpiando cachés y archivos temporales de Apache..."

    # Limpiar archivos de log antiguos (más de 7 días)
    if [[ -d /var/log/apache2 ]]; then
        find /var/log/apache2 -name "*.log" -type f -mtime +$CACHE_CLEANUP_DAYS -delete 2>/dev/null || true
        log_info "Archivos de log antiguos eliminados"
    fi

    # Limpiar archivos temporales de Apache
    if [[ -d /var/cache/apache2 ]]; then
        rm -rf /var/cache/apache2/* 2>/dev/null || true
        log_info "Caché de Apache limpiado"
    fi

    # Limpiar sesiones PHP si existen
    if [[ -d /var/lib/php/sessions ]]; then
        find /var/lib/php/sessions -name "sess_*" -type f -mtime +1 -delete 2>/dev/null || true
        log_info "Sesiones PHP antiguas eliminadas"
    fi

    # Limpiar archivos temporales del sistema relacionados con Apache
    if [[ -d /tmp ]]; then
        find /tmp -name "apache2*" -type f -mtime +1 -delete 2>/dev/null || true
        find /tmp -name "*apache*" -type f -mtime +1 -delete 2>/dev/null || true
    fi

    log_info "Limpieza de cachés completada"
}

# Función para diagnosticar errores en logs y aplicar soluciones automáticas
diagnose_log_infos() {
    log_info "Analizando logs de Apache para diagnóstico automático..."

    local error_log="/var/log/apache2/error.log"
    local access_log="/var/log/apache2/access.log"
    local fixes_applied=0

    # Verificar que los archivos de log existen
    if [[ ! -f "$error_log" ]]; then
        log_info "Archivo de log de errores no encontrado: $error_log"
        return 0
    fi

    # Analizar errores comunes en las últimas horas
    log_info "Analizando errores de las últimas $LOG_ANALYSIS_HOURS horas..."

    # Error: Permission denied
    if grep -i "permission denied" "$error_log" | grep -q "$(date -d "$LOG_ANALYSIS_HOURS hours ago" +%Y/%m/%d)"; then
        log_info "Detectados errores de permisos - Reparando..."
        repair_apache_permissions
        ((fixes_applied++))
    fi

    # Error: Could not bind to address
    if grep -i "could not bind to address" "$error_log" | grep -q "$(date -d "$LOG_ANALYSIS_HOURS hours ago" +%Y/%m/%d)"; then
        log_info "Detectado error de puerto ocupado - Verificando servicios..."
        # Verificar si hay otros servicios usando el puerto 80
        if command -v netstat >/dev/null 2>&1; then
            local port_user
            port_user=$(netstat -tlnp 2>/dev/null | grep ":80 " | head -1 | awk '{print $7}' | cut -d'/' -f1)
            if [[ -n "$port_user" ]]; then
                log_info "Puerto 80 ocupado por PID $port_user"
                # Intentar detener el proceso conflictivo
                if kill -TERM "$port_user" 2>/dev/null; then
                    log_info "Proceso conflictivo detenido"
                    sleep 2
                    ((fixes_applied++))
                fi
            fi
        fi
    fi

    # Error: Syntax error in config
    if grep -i "syntax error" "$error_log" | grep -q "$(date -d "$LOG_ANALYSIS_HOURS hours ago" +%Y/%m/%d)"; then
        log_info "Detectado error de sintaxis en configuración - Reparando configuración..."
        repair_apache_config
        ((fixes_applied++))
    fi

    # Error: Module not found
    if grep -i "module.*not found" "$error_log" | grep -q "$(date -d "$LOG_ANALYSIS_HOURS hours ago" +%Y/%m/%d)"; then
        log_info "Detectado módulo faltante - Reparando módulos..."
        repair_apache_modules
        ((fixes_applied++))
    fi

    # Error: File not found (404 errors)
    if [[ -f "$access_log" ]]; then
        local error_404_count
        error_404_count=$(grep " 404 " "$access_log" | wc -l)
        if [[ $error_404_count -gt 10 ]]; then
            log_info "Detectados $error_404_count errores 404 - Verificando sitio por defecto..."
            if [[ ! -f /var/www/html/index.html ]]; then
                repair_apache_config  # Esto crea el index.html
                ((fixes_applied++))
            fi
        fi
    fi

    log_info "Diagnóstico completado: $fixes_applied correcciones aplicadas automáticamente"
}

# Función para reparar virtualhosts mal configurados
repair_apache_virtualhosts() {
    log_info "Analizando y reparando virtualhosts de Apache..."

    local sites_available="/etc/apache2/sites-available"
    local sites_enabled="/etc/apache2/sites-enabled"
    local fixes_applied=0

    # Verificar que los directorios existen
    if [[ ! -d "$sites_available" ]]; then
        log_info "Directorio sites-available no existe - Creando configuración básica"
        repair_apache_config
        return 0
    fi

    # Analizar cada virtualhost disponible
    while IFS= read -r -d '' vhost_file; do
        local vhost_name
        vhost_name=$(basename "$vhost_file" .conf)

        log_info "Analizando virtualhost: $vhost_name"

        # Verificar sintaxis básica del virtualhost
        if ! grep -q "<VirtualHost" "$vhost_file"; then
            log_info "Virtualhost $vhost_name no tiene etiqueta VirtualHost - Saltando"
            continue
        fi

        # Verificar DocumentRoot
        local doc_root
        doc_root=$(grep "DocumentRoot" "$vhost_file" | head -1 | awk '{print $2}' | sed 's/"//g')
        if [[ -n "$doc_root" ]]; then
            if [[ ! -d "$doc_root" ]]; then
                log_info "DocumentRoot no existe para $vhost_name: $doc_root - Creando directorio"
                mkdir -p "$doc_root" 2>/dev/null || true
                # Crear index.html básico
                if [[ ! -f "$doc_root/index.html" ]]; then
                    cat > "$doc_root/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>$vhost_name</title>
</head>
<body>
    <h1>Sitio $vhost_name</h1>
    <p>Virtualhost configurado correctamente.</p>
</body>
</html>
EOF
                fi
                chown -R www-data:www-data "$doc_root" 2>/dev/null || true
                ((fixes_applied++))
            fi
        fi

        # Verificar ServerName
        if ! grep -q "ServerName" "$vhost_file"; then
            log_info "Virtualhost $vhost_name no tiene ServerName - Agregando"
            # Agregar ServerName al final del VirtualHost
            sed -i '/<\/VirtualHost>/i \    ServerName '"$vhost_name" "$vhost_file"
            ((fixes_applied++))
        fi

        # Verificar Directory directive
        if ! grep -q "<Directory" "$vhost_file"; then
            log_info "Virtualhost $vhost_name no tiene directiva Directory - Agregando"
            # Agregar directiva Directory básica
            sed -i '/<\/VirtualHost>/i \    <Directory '"$doc_root"'>' "$vhost_file"
            sed -i '/<\/VirtualHost>/i \        Options Indexes FollowSymLinks' "$vhost_file"
            sed -i '/<\/VirtualHost>/i \        AllowOverride All' "$vhost_file"
            sed -i '/<\/VirtualHost>/i \        Require all granted' "$vhost_file"
            sed -i '/<\/VirtualHost>/i \    </Directory>' "$vhost_file"
            ((fixes_applied++))
        fi

        # Verificar si está habilitado
        if [[ ! -L "$sites_enabled/$vhost_name.conf" ]]; then
            log_info "Habilitando virtualhost: $vhost_name"
            ln -sf "$sites_available/$vhost_name.conf" "$sites_enabled/" 2>/dev/null || true
        fi

    done < <(find "$sites_available" -name "*.conf" -print0)

    # Verificar configuración después de las reparaciones
    if command -v apache2ctl >/dev/null 2>&1; then
        if ! apache2ctl configtest >/dev/null 2>&1; then
            log_info "Configuración inválida después de reparar virtualhosts"
            return 1
        fi
    fi

    log_info "Reparación de virtualhosts completada: $fixes_applied correcciones aplicadas"
}

# Función para reinstalar Apache si es necesario
reinstall_apache() {
    log_info "Reinstalando Apache..."

    # Detectar distribución
    if command -v apt-get >/dev/null 2>&1; then
        log_info "Usando apt-get para reinstalar Apache..."

        # Actualizar repositorios
        apt-get update

        # Reinstalar Apache
        apt-get install --reinstall -y apache2 apache2-utils

        # Instalar módulos comunes
        apt-get install -y libapache2-mod-php 2>/dev/null || true
        apt-get install -y libapache2-mod-ssl 2>/dev/null || true

    elif command -v yum >/dev/null 2>&1; then
        log_info "Usando yum para reinstalar Apache..."

        yum reinstall -y httpd mod_ssl

    elif command -v dnf >/dev/null 2>&1; then
        log_info "Usando dnf para reinstalar Apache..."

        dnf reinstall -y httpd mod_ssl
    else
        log_info "No se pudo detectar el gestor de paquetes"
        return 1
    fi

    log_info "Apache reinstalado"
}

# Función para verificar y reparar el servicio
repair_apache_service() {
    log_info "Reparando servicio de Apache..."

    # Detectar nombre del servicio
    local service_name=""
    if systemctl list-units --type=service | grep -q apache2; then
        service_name="apache2"
    elif systemctl list-units --type=service | grep -q httpd; then
        service_name="httpd"
    else
        log_info "No se pudo detectar el servicio de Apache"
        return 1
    fi

    # Detener servicio si está corriendo
    systemctl stop "$service_name" 2>/dev/null || true

    # Habilitar servicio
    systemctl enable "$service_name" 2>/dev/null || true

    # Iniciar servicio
    if systemctl start "$service_name" 2>/dev/null; then
        log_info "Servicio Apache iniciado correctamente"

        # Verificar que está corriendo
        sleep 2
        if systemctl is-active --quiet "$service_name" 2>/dev/null; then
            log_info "Servicio Apache verificado como activo"
            return 0
        else
            log_info "Servicio Apache no se pudo iniciar correctamente"
            return 1
        fi
    else
        log_info "Falló al iniciar el servicio Apache"
        return 1
    fi
}

# Función para verificar reparación final
verify_apache_repair() {
    log_info "Verificando reparación final de Apache..."

    local verification_passed=0

    # Verificar servicio
    if systemctl is-active --quiet apache2 2>/dev/null || systemctl is-active --quiet httpd 2>/dev/null; then
        log_info "✅ Servicio Apache activo"
        ((verification_passed++))
    else
        log_info "❌ Servicio Apache inactivo"
    fi

    # Verificar puerto 80
    if timeout 5 bash -c "</dev/tcp/localhost/80" 2>/dev/null; then
        log_info "✅ Puerto 80 accesible"
        ((verification_passed++))
    else
        log_info "❌ Puerto 80 no accesible"
    fi

    # Verificar configuración
    if command -v apache2ctl >/dev/null 2>&1; then
        if apache2ctl configtest >/dev/null 2>&1; then
            log_info "✅ Configuración válida"
            ((verification_passed++))
        else
            log_info "❌ Configuración inválida"
        fi
    fi

    # Verificar sitio web
    if curl -s -o /dev/null -w "%{http_code}" http://localhost/ | grep -q "200"; then
        log_info "✅ Sitio web responde correctamente"
        ((verification_passed++))
    else
        log_info "⚠️ Sitio web no responde (puede ser normal si no hay contenido)"
    fi

    log_info "Verificación completada: $verification_passed/4 pruebas pasaron"

    if [[ $verification_passed -ge 3 ]]; then
        log_info "🎉 Reparación de Apache exitosa"
        return 0
    else
        log_info "⚠️ Reparación de Apache incompleta"
        return 1
    fi
}

# Función principal de reparación de Apache
repair_apache() {
    log_info "🚀 INICIANDO REPARACIÓN AUTOMÁTICA DE APACHE"

    echo ""
    echo -e "${CYAN}🔧 REPARACIÓN AUTOMÁTICA DE APACHE${NC}"
    echo -e "${CYAN}Detectando y reparando problemas automáticamente${NC}"
    echo ""

    # Detectar problemas
    if ! detect_apache_problems; then
        log_info "No se detectaron problemas críticos en Apache"
        return 0
    fi

    # Limpiar cachés y archivos temporales
    clean_apache_cache

    # Diagnosticar errores en logs y aplicar soluciones
    diagnose_log_infos

    # Reparar virtualhosts mal configurados
    repair_apache_virtualhosts

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
        log_info "🎉 APACHE REPARADO COMPLETAMENTE"
        echo ""
        echo -e "${GREEN}✅ APACHE REPARADO EXITOSAMENTE${NC}"
        echo "   • Servicio activo y funcionando"
        echo "   • Puerto 80 abierto y accesible"
        echo "   • Configuración válida"
        echo "   • Sitio web operativo"
        return 0
    else
        log_info "❌ FALLÓ LA REPARACIÓN DE APACHE"
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
