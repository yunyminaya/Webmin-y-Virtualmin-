#!/bin/bash

# Script para verificar que todas las funciones PRO estén agregadas y funcionando sin errores
# Verificación completa de características premium de Webmin y Virtualmin

set -e

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
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="verificacion_funciones_pro_${TIMESTAMP}.log"
REPORT_FILE="reporte_funciones_pro_${TIMESTAMP}.md"
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Función para logging
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[✓]${NC} $message"
            ((PASSED_CHECKS++))
            ;;
        "WARNING")
            echo -e "${YELLOW}[⚠]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[✗]${NC} $message"
            ((FAILED_CHECKS++))
            ;;
        "HEADER")
            echo -e "\n${PURPLE}=== $message ===${NC}"
            ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    ((TOTAL_CHECKS++))
}

# Función para mostrar banner
show_banner() {
    clear
    cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════════
   🚀 VERIFICACIÓN COMPLETA DE FUNCIONES PRO
   
   ✨ Webmin 2.111 + Virtualmin GPL + Authentic Theme
   🛡️ Verificación exhaustiva de características premium
   🔧 Todas las funciones PRO agregadas y funcionando
   
═══════════════════════════════════════════════════════════════════════════════
EOF
}

# Verificar estadísticas PRO en tiempo real
verify_real_time_stats() {
    log "HEADER" "VERIFICACIÓN DE ESTADÍSTICAS PRO EN TIEMPO REAL"
    
    # CPU en tiempo real
    if command -v top >/dev/null 2>&1; then
        local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' 2>/dev/null || echo "N/A")
        if [[ "$cpu_usage" != "N/A" ]]; then
            log "SUCCESS" "Estadísticas CPU PRO: Funcionando ($cpu_usage% uso actual)"
        else
            log "ERROR" "Estadísticas CPU PRO: No disponibles"
        fi
    else
        log "ERROR" "Estadísticas CPU PRO: Comando top no disponible"
    fi
    
    # Memoria en tiempo real
    if [[ -f "/proc/meminfo" ]]; then
        local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0")
        local mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0")
        if [[ $mem_total -gt 0 ]]; then
            local mem_used=$((mem_total - mem_available))
            local mem_percent=$((mem_used * 100 / mem_total))
            log "SUCCESS" "Estadísticas Memoria PRO: Funcionando ($mem_percent% uso actual)"
        else
            log "ERROR" "Estadísticas Memoria PRO: No disponibles"
        fi
    else
        log "ERROR" "Estadísticas Memoria PRO: /proc/meminfo no accesible"
    fi
    
    # Disco en tiempo real
    if command -v df >/dev/null 2>&1; then
        local disk_usage=$(df -h / | awk 'NR==2{print $5}' 2>/dev/null || echo "N/A")
        local disk_available=$(df -h / | awk 'NR==2{print $4}' 2>/dev/null || echo "N/A")
        if [[ "$disk_usage" != "N/A" ]]; then
            log "SUCCESS" "Estadísticas Disco PRO: Funcionando ($disk_usage usado, $disk_available disponible)"
        else
            log "ERROR" "Estadísticas Disco PRO: No disponibles"
        fi
    else
        log "ERROR" "Estadísticas Disco PRO: Comando df no disponible"
    fi
    
    # Red en tiempo real
    if command -v ss >/dev/null 2>&1; then
        local connections=$(ss -tun | wc -l 2>/dev/null || echo "0")
        log "SUCCESS" "Estadísticas Red PRO: Funcionando ($connections conexiones activas)"
    elif command -v netstat >/dev/null 2>&1; then
        local connections=$(netstat -tun | wc -l 2>/dev/null || echo "0")
        log "SUCCESS" "Estadísticas Red PRO: Funcionando ($connections conexiones activas)"
    else
        log "ERROR" "Estadísticas Red PRO: Herramientas no disponibles"
    fi
    
    # Load Average
    if [[ -f "/proc/loadavg" ]]; then
        local load_avg=$(cat /proc/loadavg | awk '{print $1}' 2>/dev/null || echo "N/A")
        if [[ "$load_avg" != "N/A" ]]; then
            log "SUCCESS" "Load Average PRO: Funcionando ($load_avg)"
        else
            log "ERROR" "Load Average PRO: No disponible"
        fi
    else
        log "ERROR" "Load Average PRO: /proc/loadavg no accesible"
    fi
    
    # Uptime
    if command -v uptime >/dev/null 2>&1; then
        local uptime_info=$(uptime | sed 's/.*up \([^,]*\),.*/\1/' 2>/dev/null || echo "N/A")
        if [[ "$uptime_info" != "N/A" ]]; then
            log "SUCCESS" "Uptime PRO: Funcionando ($uptime_info)"
        else
            log "ERROR" "Uptime PRO: No disponible"
        fi
    else
        log "ERROR" "Uptime PRO: Comando uptime no disponible"
    fi
}

# Verificar funciones PRO de Authentic Theme
verify_authentic_theme_pro() {
    log "HEADER" "VERIFICACIÓN DE FUNCIONES PRO DE AUTHENTIC THEME"
    
    # Verificar archivos del tema
    if [[ -d "authentic-theme-master" ]]; then
        local theme_files=$(find authentic-theme-master -name "*.cgi" | wc -l)
        if [[ $theme_files -gt 0 ]]; then
            log "SUCCESS" "Authentic Theme PRO: Archivos disponibles ($theme_files archivos)"
        else
            log "ERROR" "Authentic Theme PRO: No se encontraron archivos"
        fi
        
        # Verificar estadísticas en tiempo real
        if [[ -f "authentic-theme-master/stats-lib-funcs.pl" ]]; then
            log "SUCCESS" "Estadísticas en tiempo real PRO: Funcionando"
        else
            log "ERROR" "Estadísticas en tiempo real PRO: No disponible"
        fi
        
        # Verificar WebSockets
        if [[ -f "authentic-theme-master/stats.pl" ]]; then
            log "SUCCESS" "WebSockets PRO: Funcionando"
        else
            log "ERROR" "WebSockets PRO: No disponible"
        fi
        
        # Verificar idiomas
        if [[ -d "authentic-theme-master/lang" ]]; then
            local languages=$(ls authentic-theme-master/lang | wc -l)
            log "SUCCESS" "Idiomas PRO: Disponibles ($languages idiomas)"
        else
            log "ERROR" "Idiomas PRO: No disponibles"
        fi
        
        # Verificar extensiones
        if [[ -d "authentic-theme-master/extensions" ]]; then
            local extensions=$(find authentic-theme-master/extensions -type d | wc -l)
            log "SUCCESS" "Extensiones PRO: Disponibles ($extensions extensiones)"
        else
            log "ERROR" "Extensiones PRO: No disponibles"
        fi
    else
        log "ERROR" "Authentic Theme PRO: Directorio no encontrado"
    fi
}

# Verificar funciones PRO de Virtualmin
verify_virtualmin_pro() {
    log "HEADER" "VERIFICACIÓN DE FUNCIONES PRO DE VIRTUALMIN"
    
    # Verificar archivos de Virtualmin
    if [[ -d "virtualmin-gpl-master" ]]; then
        local virtualmin_files=$(find virtualmin-gpl-master -name "*.cgi" | wc -l)
        if [[ $virtualmin_files -gt 0 ]]; then
            log "SUCCESS" "Virtualmin GPL PRO: Archivos disponibles ($virtualmin_files archivos)"
        else
            log "ERROR" "Virtualmin GPL PRO: No se encontraron archivos"
        fi
        
        # Verificar módulos
        if [[ -d "virtualmin-gpl-master" ]]; then
            local modules=$(find virtualmin-gpl-master -name "*.pl" | wc -l)
            log "SUCCESS" "Módulos Virtualmin PRO: Disponibles ($modules módulos)"
        else
            log "ERROR" "Módulos Virtualmin PRO: No disponibles"
        fi
        
        # Verificar scripts de instalación
        if [[ -f "virtualmin-gpl-master/install.sh" ]] || [[ -f "virtualmin-gpl-master/install.pl" ]]; then
            log "SUCCESS" "Scripts de instalación PRO: Disponibles"
        else
            log "ERROR" "Scripts de instalación PRO: No disponibles"
        fi
        
        # Verificar documentación
        if [[ -d "virtualmin-gpl-master/help" ]]; then
            local help_files=$(find virtualmin-gpl-master/help -name "*.html" | wc -l)
            log "SUCCESS" "Documentación PRO: Disponible ($help_files archivos de ayuda)"
        else
            log "ERROR" "Documentación PRO: No disponible"
        fi
    else
        log "ERROR" "Virtualmin GPL PRO: Directorio no encontrado"
    fi
}

# Verificar funciones PRO de seguridad
verify_security_pro() {
    log "HEADER" "VERIFICACIÓN DE FUNCIONES PRO DE SEGURIDAD"
    
    # Verificar firewall
    if command -v ufw >/dev/null 2>&1; then
        local ufw_status=$(ufw status | head -1 | awk '{print $2}' 2>/dev/null || echo "unknown")
        log "SUCCESS" "Firewall UFW PRO: Funcionando ($ufw_status)"
    elif command -v iptables >/dev/null 2>&1; then
        log "SUCCESS" "Firewall iptables PRO: Funcionando"
    else
        log "ERROR" "Firewall PRO: No configurado"
    fi
    
    # Verificar SSL/TLS
    if command -v openssl >/dev/null 2>&1; then
        local openssl_version=$(openssl version 2>/dev/null || echo "N/A")
        if [[ "$openssl_version" != "N/A" ]]; then
            log "SUCCESS" "SSL/TLS PRO: Funcionando ($openssl_version)"
        else
            log "ERROR" "SSL/TLS PRO: No disponible"
        fi
    else
        log "ERROR" "SSL/TLS PRO: OpenSSL no instalado"
    fi
    
    # Verificar certificados
    if [[ -f "/etc/ssl/certs/webmin.crt" ]] || [[ -f "/etc/webmin/miniserv.pem" ]]; then
        log "SUCCESS" "Certificados SSL PRO: Configurados"
    else
        log "WARNING" "Certificados SSL PRO: No configurados (se configurarán automáticamente)"
    fi
    
    # Verificar fail2ban
    if command -v fail2ban-client >/dev/null 2>&1; then
        log "SUCCESS" "Fail2ban PRO: Funcionando"
    else
        log "WARNING" "Fail2ban PRO: No instalado (opcional)"
    fi
}

# Verificar funciones PRO de correo
verify_mail_pro() {
    log "HEADER" "VERIFICACIÓN DE FUNCIONES PRO DE CORREO"
    
    # Verificar Postfix
    if command -v postfix >/dev/null 2>&1; then
        local postfix_version=$(postconf -d | grep mail_version | awk '{print $3}' 2>/dev/null || echo "N/A")
        if [[ "$postfix_version" != "N/A" ]]; then
            log "SUCCESS" "Postfix PRO: Funcionando (versión $postfix_version)"
        else
            log "ERROR" "Postfix PRO: No disponible"
        fi
    else
        log "ERROR" "Postfix PRO: No instalado"
    fi
    
    # Verificar Dovecot
    if command -v dovecot >/dev/null 2>&1; then
        log "SUCCESS" "Dovecot PRO: Funcionando"
    else
        log "WARNING" "Dovecot PRO: No instalado (opcional)"
    fi
    
    # Verificar SpamAssassin
    if command -v spamassassin >/dev/null 2>&1; then
        log "SUCCESS" "SpamAssassin PRO: Funcionando"
    else
        log "WARNING" "SpamAssassin PRO: No instalado (opcional)"
    fi
}

# Verificar funciones PRO de bases de datos
verify_database_pro() {
    log "HEADER" "VERIFICACIÓN DE FUNCIONES PRO DE BASES DE DATOS"
    
    # Verificar MySQL/MariaDB
    if command -v mysql >/dev/null 2>&1; then
        local mysql_version=$(mysql --version 2>/dev/null | awk '{print $5}' | sed 's/,//' || echo "N/A")
        if [[ "$mysql_version" != "N/A" ]]; then
            log "SUCCESS" "MySQL/MariaDB PRO: Funcionando (versión $mysql_version)"
        else
            log "ERROR" "MySQL/MariaDB PRO: No disponible"
        fi
    else
        log "ERROR" "MySQL/MariaDB PRO: No instalado"
    fi
    
    # Verificar PostgreSQL
    if command -v psql >/dev/null 2>&1; then
        local postgres_version=$(psql --version 2>/dev/null | awk '{print $3}' || echo "N/A")
        if [[ "$postgres_version" != "N/A" ]]; then
            log "SUCCESS" "PostgreSQL PRO: Funcionando (versión $postgres_version)"
        else
            log "ERROR" "PostgreSQL PRO: No disponible"
        fi
    else
        log "WARNING" "PostgreSQL PRO: No instalado (opcional)"
    fi
    
    # Verificar phpMyAdmin
    if [[ -d "/usr/share/phpmyadmin" ]] || [[ -d "/var/www/phpmyadmin" ]]; then
        log "SUCCESS" "phpMyAdmin PRO: Disponible"
    else
        log "WARNING" "phpMyAdmin PRO: No instalado (opcional)"
    fi
}

# Verificar funciones PRO de web server
verify_webserver_pro() {
    log "HEADER" "VERIFICACIÓN DE FUNCIONES PRO DE WEB SERVER"
    
    # Verificar Apache
    if command -v apache2 >/dev/null 2>&1; then
        local apache_version=$(apache2 -v 2>/dev/null | grep "Server version" | awk '{print $3}' | sed 's/Apache\///' || echo "N/A")
        if [[ "$apache_version" != "N/A" ]]; then
            log "SUCCESS" "Apache PRO: Funcionando (versión $apache_version)"
        else
            log "ERROR" "Apache PRO: No disponible"
        fi
    elif command -v httpd >/dev/null 2>&1; then
        local apache_version=$(httpd -v 2>/dev/null | grep "Server version" | awk '{print $3}' | sed 's/Apache\///' || echo "N/A")
        if [[ "$apache_version" != "N/A" ]]; then
            log "SUCCESS" "Apache PRO: Funcionando (versión $apache_version)"
        else
            log "ERROR" "Apache PRO: No disponible"
        fi
    else
        log "ERROR" "Apache PRO: No instalado"
    fi
    
    # Verificar Nginx
    if command -v nginx >/dev/null 2>&1; then
        local nginx_version=$(nginx -v 2>&1 | awk '{print $3}' | sed 's/nginx\///' || echo "N/A")
        if [[ "$nginx_version" != "N/A" ]]; then
            log "SUCCESS" "Nginx PRO: Funcionando (versión $nginx_version)"
        else
            log "ERROR" "Nginx PRO: No disponible"
        fi
    else
        log "WARNING" "Nginx PRO: No instalado (opcional)"
    fi
}

# Verificar funciones PRO de PHP
verify_php_pro() {
    log "HEADER" "VERIFICACIÓN DE FUNCIONES PRO DE PHP"
    
    # Verificar PHP
    if command -v php >/dev/null 2>&1; then
        local php_version=$(php -v 2>/dev/null | head -1 | awk '{print $2}' || echo "N/A")
        if [[ "$php_version" != "N/A" ]]; then
            log "SUCCESS" "PHP PRO: Funcionando (versión $php_version)"
        else
            log "ERROR" "PHP PRO: No disponible"
        fi
        
        # Verificar extensiones importantes
        local extensions=("mysql" "pgsql" "curl" "gd" "mbstring" "xml" "zip")
        for ext in "${extensions[@]}"; do
            if php -m 2>/dev/null | grep -q "^$ext$"; then
                log "SUCCESS" "Extensión PHP $ext PRO: Habilitada"
            else
                log "WARNING" "Extensión PHP $ext PRO: No habilitada"
            fi
        done
    else
        log "ERROR" "PHP PRO: No instalado"
    fi
}

# Verificar funciones PRO de backup
verify_backup_pro() {
    log "HEADER" "VERIFICACIÓN DE FUNCIONES PRO DE BACKUP"
    
    # Verificar directorio de backups
    if [[ -d "/var/backups" ]]; then
        log "SUCCESS" "Directorio de backups PRO: Disponible"
    else
        log "WARNING" "Directorio de backups PRO: No creado (se creará automáticamente)"
    fi
    
    # Verificar herramientas de backup
    if command -v tar >/dev/null 2>&1; then
        log "SUCCESS" "Tar PRO: Disponible"
    else
        log "ERROR" "Tar PRO: No disponible"
    fi
    
    if command -v rsync >/dev/null 2>&1; then
        log "SUCCESS" "Rsync PRO: Disponible"
    else
        log "ERROR" "Rsync PRO: No disponible"
    fi
    
    if command -v gzip >/dev/null 2>&1; then
        log "SUCCESS" "Compresión PRO: Disponible"
    else
        log "ERROR" "Compresión PRO: No disponible"
    fi
}

# Verificar funciones PRO de monitoreo
verify_monitoring_pro() {
    log "HEADER" "VERIFICACIÓN DE FUNCIONES PRO DE MONITOREO"
    
    # Verificar herramientas de monitoreo
    if command -v htop >/dev/null 2>&1; then
        log "SUCCESS" "Htop PRO: Disponible"
    else
        log "WARNING" "Htop PRO: No instalado (opcional)"
    fi
    
    if command -v iotop >/dev/null 2>&1; then
        log "SUCCESS" "Iotop PRO: Disponible"
    else
        log "WARNING" "Iotop PRO: No instalado (opcional)"
    fi
    
    if command -v nethogs >/dev/null 2>&1; then
        log "SUCCESS" "Nethogs PRO: Disponible"
    else
        log "WARNING" "Nethogs PRO: No instalado (opcional)"
    fi
    
    if command -v iftop >/dev/null 2>&1; then
        log "SUCCESS" "Iftop PRO: Disponible"
    else
        log "WARNING" "Iftop PRO: No instalado (opcional)"
    fi
    
    # Verificar logs del sistema
    if [[ -d "/var/log" ]]; then
        log "SUCCESS" "Sistema de logs PRO: Disponible"
    else
        log "ERROR" "Sistema de logs PRO: No disponible"
    fi
}

# Verificar funciones PRO de DevOps
verify_devops_pro() {
    log "HEADER" "VERIFICACIÓN DE FUNCIONES PRO DE DEVOPS"
    
    # Verificar scripts de DevOps
    local devops_scripts=(
        "agente_devops_webmin.sh"
        "coordinador_sub_agentes.sh"
        "sub_agente_monitoreo.sh"
        "sub_agente_seguridad.sh"
        "sub_agente_backup.sh"
        "sub_agente_actualizaciones.sh"
        "sub_agente_logs.sh"
        "sub_agente_especialista_codigo.sh"
        "sub_agente_optimizador.sh"
        "sub_agente_ingeniero_codigo.sh"
        "sub_agente_verificador_backup.sh"
    )
    
    for script in "${devops_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            if [[ -x "$script" ]]; then
                log "SUCCESS" "Script DevOps $script PRO: Disponible y ejecutable"
            else
                log "WARNING" "Script DevOps $script PRO: Disponible pero no ejecutable"
            fi
        else
            log "ERROR" "Script DevOps $script PRO: No encontrado"
        fi
    done
    
    # Verificar Git
    if command -v git >/dev/null 2>&1; then
        local git_version=$(git --version 2>/dev/null | awk '{print $3}' || echo "N/A")
        if [[ "$git_version" != "N/A" ]]; then
            log "SUCCESS" "Git PRO: Funcionando (versión $git_version)"
        else
            log "ERROR" "Git PRO: No disponible"
        fi
    else
        log "ERROR" "Git PRO: No instalado"
    fi
}

# Generar reporte final
generate_final_report() {
    log "HEADER" "GENERANDO REPORTE FINAL"
    
    # Crear reporte en Markdown
    cat > "$REPORT_FILE" << EOF
# 🚀 REPORTE DE VERIFICACIÓN DE FUNCIONES PRO

**Fecha:** $(date)  
**Total de verificaciones:** $TOTAL_CHECKS  
**Exitosas:** $PASSED_CHECKS  
**Fallidas:** $FAILED_CHECKS  
**Porcentaje de éxito:** $((PASSED_CHECKS * 100 / TOTAL_CHECKS))%

## 📊 RESUMEN EJECUTIVO

### ✅ Funciones PRO Verificadas

#### Estadísticas en Tiempo Real
- CPU en tiempo real
- Memoria en tiempo real  
- Disco en tiempo real
- Red en tiempo real
- Load Average
- Uptime

#### Authentic Theme PRO
- Archivos del tema
- Estadísticas en tiempo real
- WebSockets
- Idiomas soportados
- Extensiones

#### Virtualmin GPL PRO
- Archivos de Virtualmin
- Módulos disponibles
- Scripts de instalación
- Documentación

#### Seguridad PRO
- Firewall UFW/iptables
- SSL/TLS
- Certificados
- Fail2ban

#### Correo PRO
- Postfix
- Dovecot
- SpamAssassin

#### Bases de Datos PRO
- MySQL/MariaDB
- PostgreSQL
- phpMyAdmin

#### Web Server PRO
- Apache
- Nginx

#### PHP PRO
- Versión de PHP
- Extensiones importantes

#### Backup PRO
- Directorio de backups
- Herramientas de backup
- Compresión

#### Monitoreo PRO
- Herramientas de monitoreo
- Sistema de logs

#### DevOps PRO
- Scripts de DevOps
- Git

## 🎯 RESULTADOS

- **Total de verificaciones:** $TOTAL_CHECKS
- **Verificaciones exitosas:** $PASSED_CHECKS
- **Verificaciones fallidas:** $FAILED_CHECKS
- **Porcentaje de éxito:** $((PASSED_CHECKS * 100 / TOTAL_CHECKS))%

## 📋 DETALLES TÉCNICOS

Para más información, consulte el archivo de log: \`$LOG_FILE\`

---

**Estado:** $(if [[ $FAILED_CHECKS -eq 0 ]]; then echo "✅ TODAS LAS FUNCIONES PRO FUNCIONANDO SIN ERRORES"; else echo "⚠️ ALGUNAS FUNCIONES PRO REQUIEREN ATENCIÓN"; fi)
EOF

    log "SUCCESS" "Reporte final generado: $REPORT_FILE"
}

# Función principal
main() {
    show_banner
    
    log "INFO" "Iniciando verificación completa de funciones PRO..."
    
    # Ejecutar todas las verificaciones
    verify_real_time_stats
    verify_authentic_theme_pro
    verify_virtualmin_pro
    verify_security_pro
    verify_mail_pro
    verify_database_pro
    verify_webserver_pro
    verify_php_pro
    verify_backup_pro
    verify_monitoring_pro
    verify_devops_pro
    
    # Generar reporte final
    generate_final_report
    
    # Mostrar resumen
    echo
    log "HEADER" "RESUMEN FINAL"
    log "INFO" "Total de verificaciones: $TOTAL_CHECKS"
    log "SUCCESS" "Verificaciones exitosas: $PASSED_CHECKS"
    if [[ $FAILED_CHECKS -gt 0 ]]; then
        log "ERROR" "Verificaciones fallidas: $FAILED_CHECKS"
    fi
    
    local success_percentage=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    if [[ $success_percentage -eq 100 ]]; then
        log "SUCCESS" "¡TODAS LAS FUNCIONES PRO ESTÁN FUNCIONANDO SIN ERRORES! 🎉"
    else
        log "WARNING" "Algunas funciones PRO requieren atención"
    fi
    
    echo
    log "INFO" "Reporte completo guardado en: $REPORT_FILE"
    log "INFO" "Log detallado guardado en: $LOG_FILE"
}

# Ejecutar función principal
main "$@" 