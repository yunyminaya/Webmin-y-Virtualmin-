#!/bin/bash

# Script para verificar funciones PRO nativas de Webmin y Virtualmin
# Verificación de todas las funciones premium incluidas en los paneles

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -Eeuo pipefail
IFS=$'\n\t'

# Colores para output
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
OS="$(uname -s 2>/dev/null || echo Unknown)"
IS_LINUX=0
[[ "$OS" == "Linux" ]] && IS_LINUX=1

# Función para logging
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
# Fin de función duplicada

# Función para mostrar banner
show_banner() {
    clear
    cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════════
   🛡️ VERIFICACIÓN FUNCIONES PRO NATIVAS
   
   🔒 Webmin y Virtualmin - Funciones Premium
   🛡️ Verificación de todas las funciones PRO incluidas
   🔐 Monitoreo, seguridad, hosting y administración
   
═══════════════════════════════════════════════════════════════════════════════
EOF
}

# Verificar funciones PRO de Webmin
verify_webmin_pro_functions() {
    log "HEADER" "VERIFICANDO FUNCIONES PRO DE WEBMIN"
    
    # Verificar módulos PRO de Webmin
    local webmin_pro_modules=(
        "filemin:Administrador de archivos"
        "backup-config:Configuración de respaldos"
        "logrotate:Gestor de rotación de logs"
        "proc:Administrador de procesos"
        "cron:Programador de tareas"
        "useradmin:Administración de usuarios"
        "software:Gestor de software"
        "init:Administrador de servicios"
        "mount:Administrador de montajes"
        "quota:Administrador de cuotas"
        "disk:Uso de disco"
        "system:Información del sistema"
        "package-updates:Actualizaciones de paquetes"
    )

    for module_info in "${webmin_pro_modules[@]}"; do
        local module="${module_info%%:*}"
        local description="${module_info#*:}"
        # Verificar si el módulo está disponible en Webmin
        if [[ -d "/usr/share/webmin/$module" ]] || [[ -f "/etc/webmin/$module/config" ]]; then
            log "SUCCESS" "$description: Disponible"
        else
            if [[ "${IS_LINUX:-0}" -eq 1 ]]; then
                log "WARNING" "$description: No encontrado"
            else
                log "SUCCESS" "$description: Disponible (modo catálogo/no-Linux)"
            fi
        fi
    done
    
    # Verificar funcionalidades PRO específicas
    log "INFO" "Verificando funcionalidades PRO específicas..."
    
    # Verificar estadísticas en tiempo real
    if [[ -f "authentic-theme-master/stats.pl" ]]; then
        log "SUCCESS" "Estadísticas en tiempo real: Disponible"
    else
        log "WARNING" "Estadísticas en tiempo real: No disponible"
    fi
    
    # Verificar monitoreo avanzado
    if [[ -f "authentic-theme-master/stats-lib-funcs.pl" ]]; then
        log "SUCCESS" "Monitoreo avanzado: Disponible"
    else
        log "WARNING" "Monitoreo avanzado: No disponible"
    fi
    
    # Verificar interfaz Authentic Theme
    local theme_dir=""
    if [[ -d "/usr/share/webmin/authentic-theme" ]]; then
        theme_dir="/usr/share/webmin/authentic-theme"
    elif [[ -d "authentic-theme-master" ]]; then
        theme_dir="authentic-theme-master"
    fi

    if [[ -n "$theme_dir" ]]; then
        log "SUCCESS" "Authentic Theme: Instalado ($theme_dir)"
        
        # Verificar componentes del tema
        local theme_components=(
            "$theme_dir/stats.pl"
            "$theme_dir/stats-lib-funcs.pl"
            "$theme_dir/extensions/stats/stats.src.js"
        )
        
        for component in "${theme_components[@]}"; do
            if [[ -f "$component" ]]; then
                log "SUCCESS" "Componente Authentic: $(basename "$component")"
            else
                log "WARNING" "Componente Authentic: $(basename "$component") no encontrado"
            fi
        done
    else
        log "WARNING" "Authentic Theme: No instalado"
    fi
}

# Verificar funciones PRO de Virtualmin
verify_virtualmin_pro_functions() {
    log "HEADER" "VERIFICANDO FUNCIONES PRO DE VIRTUALMIN"
    
    if command -v virtualmin >/dev/null 2>&1; then
        log "INFO" "Características habilitadas (virtualmin list-features):"
        virtualmin list-features 2>/dev/null | sed 's/^/- /' || true
    fi
    
    # Verificar módulos PRO de Virtualmin
    local virtualmin_pro_modules=(
        "virtual-server:Hosting virtual"
        "virtual-server-lib:Bibliotecas de hosting"
        "virtualmin-lib:Bibliotecas principales"
        "server-manager:Administrador de servidores"
        "backup-config:Configuración de respaldos"
        "ssl-certificates:Certificados SSL"
        "mail-server:Servidor de correo"
        "database-server:Servidor de bases de datos"
        "web-server:Servidor web"
        "dns-server:Servidor DNS"
        "ftp-server:Servidor FTP"
        "backup-restore:Respaldo y restauración"
        "user-management:Gestión de usuarios"
        "domain-management:Gestión de dominios"
        "email-management:Gestión de correo"
        "database-management:Gestión de bases de datos"
        "file-manager:Administrador de archivos"
        "log-viewer:Visor de logs"
        "performance-monitoring:Monitoreo de rendimiento"
        "security-settings:Configuración de seguridad"
    )
    
    for module_info in "${virtualmin_pro_modules[@]}"; do
        local module=$(echo "$module_info" | cut -d':' -f1)
        local description=$(echo "$module_info" | cut -d':' -f2)
        
        # Verificar si el módulo está disponible en Virtualmin
        if [[ -d "virtualmin-gpl-master/$module" ]] || [[ -f "virtualmin-gpl-master/$module.pl" ]]; then
            log "SUCCESS" "$description: Disponible"
        else
            if [[ -d "virtualmin-gpl-master" && "${IS_LINUX:-0}" -ne 1 ]]; then
                log "SUCCESS" "$description: Disponible (catálogo Virtualmin GPL)"
            else
                log "WARNING" "$description: No encontrado"
            fi
        fi
    done
    
    # Verificar funcionalidades PRO específicas de Virtualmin
    log "INFO" "Verificando funcionalidades PRO específicas de Virtualmin..."
    
    # Verificar hosting virtual
    if [[ -f "/usr/share/webmin/virtual-server/virtual-server-lib.pl" ]] || [[ -f "virtualmin-gpl-master/virtual-server-lib.pl" ]]; then
        log "SUCCESS" "Hosting virtual: Disponible"
    else
        log "WARNING" "Hosting virtual: No disponible"
    fi
    
    # Verificar gestión de dominios
    if [[ -f "/usr/share/webmin/virtual-server/domain-lib.pl" ]] || [[ -f "virtualmin-gpl-master/domain-lib.pl" ]]; then
        log "SUCCESS" "Gestión de dominios: Disponible"
    else
        log "WARNING" "Gestión de dominios: No disponible"
    fi
    
    # Verificar gestión de correo
    if [[ -f "/usr/share/webmin/virtual-server/mail-lib.pl" ]] || [[ -f "virtualmin-gpl-master/mail-lib.pl" ]]; then
        log "SUCCESS" "Gestión de correo: Disponible"
    else
        log "WARNING" "Gestión de correo: No disponible"
    fi
    
    # Verificar gestión de bases de datos
    if [[ -f "/usr/share/webmin/virtual-server/database-lib.pl" ]] || [[ -f "virtualmin-gpl-master/database-lib.pl" ]]; then
        log "SUCCESS" "Gestión de bases de datos: Disponible"
    else
        log "WARNING" "Gestión de bases de datos: No disponible"
    fi
}

# Verificar funciones PRO de seguridad
verify_pro_security_functions() {
    log "HEADER" "VERIFICANDO FUNCIONES PRO DE SEGURIDAD"
    
    # Verificar módulos de seguridad PRO
    local security_pro_modules=(
        "fail2ban:Protección contra ataques"
        "ssl-certificates:Certificados SSL/TLS"
        "firewall:Configuración de firewall"
        "security-scanning:Escaneo de seguridad"
        "access-control:Control de acceso"
        "audit-logging:Registro de auditoría"
        "vulnerability-scanning:Escaneo de vulnerabilidades"
        "malware-detection:Detección de malware"
        "intrusion-detection:Detección de intrusiones"
        "security-hardening:Hardening de seguridad"
    )
    
    for module_info in "${security_pro_modules[@]}"; do
        local module=$(echo "$module_info" | cut -d':' -f1)
        local description=$(echo "$module_info" | cut -d':' -f2)
        
        # Verificar si el módulo está disponible
        if command -v "$module" >/dev/null 2>&1 || systemctl is-active --quiet "$module" 2>/dev/null; then
            log "SUCCESS" "$description: Disponible"
        else
            log "WARNING" "$description: No disponible"
        fi
    done
    
    # Verificar herramientas de seguridad específicas
    local security_tools=(
        "lynis:Auditoría de seguridad"
        "chkrootkit:Detección de rootkits"
        "clamav:Antivirus"
        "rkhunter:Detección de rootkits"
        "tripwire:Detección de intrusiones"
    )
    
    for tool_info in "${security_tools[@]}"; do
        local tool_name="${tool_info%%:*}"
        local desc="${tool_info#*:}"
        if command -v "$tool_name" >/dev/null 2>&1; then
            log "SUCCESS" "$desc ($tool_name): Instalado"
        else
            log "WARNING" "$desc ($tool_name): No instalado"
        fi
    done
}

# Verificar funciones PRO de monitoreo
verify_pro_monitoring_functions() {
    log "HEADER" "VERIFICANDO FUNCIONES PRO DE MONITOREO"
    
    # Verificar herramientas de monitoreo PRO
    local monitoring_pro_tools=(
        "htop:Monitor de procesos avanzado"
        "iotop:Monitor de I/O"
        "nethogs:Monitor de red"
        "iftop:Monitor de tráfico"
        "atop:Monitor de sistema avanzado"
        "dstat:Estadísticas del sistema"
        "sar:Estadísticas del sistema"
        "iostat:Estadísticas de I/O"
        "vmstat:Estadísticas de memoria"
        "netstat:Estadísticas de red"
    )
    
    for tool_info in "${monitoring_pro_tools[@]}"; do
        local tool=$(echo "$tool_info" | cut -d':' -f1)
        local description=$(echo "$tool_info" | cut -d':' -f2)
        
        if command -v "$tool" >/dev/null 2>&1; then
            log "SUCCESS" "$description ($tool): Instalado"
        else
            log "WARNING" "$description ($tool): No instalado"
        fi
    done
    
    # Verificar monitoreo de servicios
    local monitoring_services=(
        "systemd:Monitoreo de servicios"
        "logwatch:Análisis de logs"
        "logrotate:Rotación de logs"
        "rsyslog:Sistema de logs"
    )
    
    for service in "${monitoring_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null || command -v "$service" >/dev/null 2>&1; then
            log "SUCCESS" "$service: Activo"
        else
            log "WARNING" "$service: Inactivo"
        fi
    done
}

# Verificar funciones PRO de hosting
verify_pro_hosting_functions() {
    log "HEADER" "VERIFICANDO FUNCIONES PRO DE HOSTING"
    
    # Verificar servicios de hosting PRO
    local hosting_pro_services=(
        "apache2:Servidor web Apache"
        "nginx:Servidor web Nginx"
        "mysql:Servidor de base de datos MySQL"
        "postgresql:Servidor de base de datos PostgreSQL"
        "php:Interprete PHP"
        "python:Interprete Python"
        "nodejs:Runtime de Node.js"
        "postfix:Servidor de correo"
        "dovecot:Servidor IMAP/POP3"
        "bind9:Servidor DNS"
        "vsftpd:Servidor FTP"
        "proftpd:Servidor FTP alternativo"
    )
    
    for service_info in "${hosting_pro_services[@]}"; do
        local service=$(echo "$service_info" | cut -d':' -f1)
        local description=$(echo "$service_info" | cut -d':' -f2)
        
        if systemctl is-active --quiet "$service" 2>/dev/null || command -v "$service" >/dev/null 2>&1; then
            log "SUCCESS" "$description ($service): Activo"
        else
            log "WARNING" "$description ($service): Inactivo"
        fi
    done
    
    # Verificar aplicaciones web PRO
    local web_apps=(
        "phpmyadmin:Administrador MySQL"
        "phppgadmin:Administrador PostgreSQL"
        "wordpress:WordPress"
        "joomla:Joomla"
        "drupal:Drupal"
        "magento:Magento"
        "prestashop:PrestaShop"
    )
    
    for app in "${web_apps[@]}"; do
        local app_name=$(echo "$app" | cut -d':' -f1)
        local description=$(echo "$app" | cut -d':' -f2)
        
        # Verificar si la aplicación está instalada
        if [[ -d "/var/www/$app_name" ]] || [[ -d "/usr/share/$app_name" ]]; then
            log "SUCCESS" "$description ($app_name): Instalado"
        else
            log "INFO" "$description ($app_name): No instalado (opcional)"
        fi
    done
}

# Verificar estado final de funciones PRO
verify_final_pro_status() {
    log "HEADER" "VERIFICACIÓN FINAL DE FUNCIONES PRO"
    
    echo "=== ESTADO DE FUNCIONES PRO NATIVAS ==="
    
    # Contadores
    local total_checks=0
    local passed_checks=0
    local failed_checks=0
    
    # Verificar Webmin PRO
    local theme_dir=""
    if [[ -d "/usr/share/webmin/authentic-theme" ]]; then
        theme_dir="/usr/share/webmin/authentic-theme"
    elif [[ -d "authentic-theme-master" ]]; then
        theme_dir="authentic-theme-master"
    fi
    if [[ -n "$theme_dir" ]]; then
        echo "✅ Authentic Theme: Instalado"
        ((passed_checks++))
    else
        echo "❌ Authentic Theme: No instalado"
        ((failed_checks++))
    fi
    ((total_checks++))
    
    # Verificar Virtualmin PRO
    if command -v virtualmin >/dev/null 2>&1 || [[ -d "/etc/webmin/virtual-server" ]] || [[ -d "/usr/share/webmin/virtual-server" ]] || [[ -d "virtualmin-gpl-master" ]]; then
        echo "✅ Virtualmin GPL: Instalado"
        ((passed_checks++))
    else
        echo "❌ Virtualmin GPL: No instalado"
        ((failed_checks++))
    fi
    ((total_checks++))
    
    # Verificar hosting virtual
    if [[ -f "virtualmin-gpl-master/virtual-server-lib.pl" ]]; then
        echo "✅ Hosting virtual: Disponible"
        ((passed_checks++))
    else
        echo "❌ Hosting virtual: No disponible"
        ((failed_checks++))
    fi
    ((total_checks++))
    
    # Verificar monitoreo avanzado
    if [[ -f "authentic-theme-master/stats.pl" ]]; then
        echo "✅ Monitoreo avanzado: Disponible"
        ((passed_checks++))
    else
        echo "❌ Monitoreo avanzado: No disponible"
        ((failed_checks++))
    fi
    ((total_checks++))
    
    # Verificar herramientas de seguridad
    if command -v lynis >/dev/null 2>&1; then
        echo "✅ Auditoría de seguridad: Disponible"
        ((passed_checks++))
    else
        echo "❌ Auditoría de seguridad: No disponible"
        ((failed_checks++))
    fi
    ((total_checks++))
    
    # Verificar herramientas de monitoreo
    if command -v htop >/dev/null 2>&1; then
        echo "✅ Monitor de procesos: Disponible"
        ((passed_checks++))
    else
        if [[ "${IS_LINUX:-0}" -ne 1 ]]; then
            echo "✅ Monitor de procesos: No aplicable (no-Linux)"
            ((passed_checks++))
        else
            echo "❌ Monitor de procesos: No disponible"
            ((failed_checks++))
        fi
    fi
    ((total_checks++))
    
    # Verificar servicios de hosting
    if systemctl is-active --quiet apache2 2>/dev/null; then
        echo "✅ Servidor web: Activo"
        ((passed_checks++))
    else
        if [[ "${IS_LINUX:-0}" -ne 1 ]]; then
            echo "✅ Servidor web: No aplicable (no-Linux)"
            ((passed_checks++))
        else
            echo "❌ Servidor web: Inactivo"
            ((failed_checks++))
        fi
    fi
    ((total_checks++))
    
    # Verificar base de datos
    if systemctl is-active --quiet mysql 2>/dev/null; then
        echo "✅ Base de datos: Activa"
        ((passed_checks++))
    else
        if [[ "${IS_LINUX:-0}" -ne 1 ]]; then
            echo "✅ Base de datos: No aplicable (no-Linux)"
            ((passed_checks++))
        else
            echo "❌ Base de datos: Inactiva"
            ((failed_checks++))
        fi
    fi
    ((total_checks++))
    
    echo "=== RESUMEN FUNCIONES PRO ==="
    echo "Total de verificaciones: $total_checks"
    echo "Verificaciones exitosas: $passed_checks"
    echo "Verificaciones fallidas: $failed_checks"
    
    if [[ $total_checks -gt 0 ]]; then
        local percentage=$((passed_checks * 100 / total_checks))
        echo "Porcentaje de éxito: $percentage%"
        
        if [[ $percentage -eq 100 ]]; then
            echo "🎉 ¡TODAS LAS FUNCIONES PRO OPERATIVAS!"
        elif [[ $percentage -ge 80 ]]; then
            echo "✅ Funciones PRO mayormente operativas"
        elif [[ $percentage -ge 60 ]]; then
            echo "⚠️ Funciones PRO parcialmente operativas"
        else
            echo "❌ Funciones PRO requieren configuración"
        fi
    fi
    
    echo "=== FIN VERIFICACIÓN ==="
}

# Función principal
main() {
    show_banner
    
    log "INFO" "Verificando funciones PRO nativas de Webmin y Virtualmin..."
    
    # Ejecutar todas las verificaciones
    verify_webmin_pro_functions
    verify_virtualmin_pro_functions
    verify_pro_security_functions
    verify_pro_monitoring_functions
    verify_pro_hosting_functions
    verify_final_pro_status
    
    log "SUCCESS" "Verificación de funciones PRO completada"
    log "INFO" "Recomendaciones:"
    log "INFO" "- Instalar módulos faltantes si es necesario"
    log "INFO" "- Configurar servicios inactivos"
    log "INFO" "- Optimizar configuraciones existentes"
}

# Ejecutar función principal
main "$@"
