#!/bin/bash

# =============================================================================
# VERIFICACIÓN FINAL COMPLETA - WEBMIN Y VIRTUALMIN 100% FUNCIONAL
# Script exhaustivo para garantizar que todo funcione perfectamente en Ubuntu/Debian
# =============================================================================

set -euo pipefail
export TERM=${TERM:-xterm}

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Variables
REPORT_FILE="/var/log/webmin-virtualmin-verification-$(date +%Y%m%d_%H%M%S).log"
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Funciones de logging
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")  echo -e "${BLUE}[INFO]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[✓]${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}[⚠]${NC} $message" ;;
        "ERROR") echo -e "${RED}[✗]${NC} $message" ;;
        "HEADER") echo -e "\n${PURPLE}=== $message ===${NC}" ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$REPORT_FILE"
}

# Contadores
increment_total() { ((TOTAL_CHECKS++)); }
increment_passed() { ((PASSED_CHECKS++)); }
increment_failed() { ((FAILED_CHECKS++)); }
increment_warning() { ((WARNING_CHECKS++)); }

# Verificar si es Ubuntu/Debian
check_ubuntu_debian() {
    log "HEADER" "VERIFICACIÓN DE SISTEMA OPERATIVO"
    increment_total
    
    if [[ ! -f /etc/os-release ]]; then
        log "ERROR" "Sistema no compatible: falta /etc/os-release"
        increment_failed
        return 1
    fi
    
    source /etc/os-release
    case "$ID" in
        ubuntu|debian)
            log "SUCCESS" "Sistema compatible: $ID $VERSION_ID"
            increment_passed
            return 0
            ;;
        *)
            log "ERROR" "Sistema no compatible: $ID"
            increment_failed
            return 1
            ;;
    esac
}

# Verificar privilegios root
check_root() {
    log "HEADER" "VERIFICACIÓN DE PRIVILEGIOS"
    increment_total
    
    if [[ $EUID -eq 0 ]]; then
        log "SUCCESS" "Ejecutando con privilegios root"
        increment_passed
    else
        log "ERROR" "Requiere privilegios root"
        increment_failed
        exit 1
    fi
}

# Verificar conectividad
check_connectivity() {
    log "HEADER" "VERIFICACIÓN DE CONECTIVIDAD"
    
    local urls=(
        "google.com"
        "download.webmin.com"
        "software.virtualmin.com"
    )
    
    for url in "${urls[@]}"; do
        increment_total
        if ping -c 1 -W 3 "$url" >/dev/null 2>&1; then
            log "SUCCESS" "Conectividad a $url: OK"
            increment_passed
        else
            log "WARNING" "Conectividad a $url: FALLA"
            increment_warning
        fi
    done
}

# Verificar servicios críticos
check_critical_services() {
    log "HEADER" "VERIFICACIÓN DE SERVICIOS CRÍTICOS"
    
    local services=(
        "webmin:10000"
        "apache2:80"
        "mysql:3306"
        "postfix:25"
        "dovecot:143"
        "bind9:53"
        "vsftpd:21"
    )
    
    for service_info in "${services[@]}"; do
        local service="${service_info%:*}"
        local port="${service_info#*:}"
        
        increment_total
        
        # Verificar estado del servicio
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log "SUCCESS" "Servicio $service: ACTIVO"
            increment_passed
        else
            log "WARNING" "Servicio $service: INACTIVO"
            increment_warning
        fi
        
        # Verificar puerto
        if ss -tlnp 2>/dev/null | grep -q ":$port\b" || netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            log "SUCCESS" "Puerto $port ($service): ABIERTO"
            increment_passed
        else
            log "WARNING" "Puerto $port ($service): CERRADO"
            increment_warning
        fi
    done
}

# Verificar instalación de Webmin
check_webmin_installation() {
    log "HEADER" "VERIFICACIÓN DE WEBMIN"
    
    # Verificar paquete instalado
    increment_total
    if dpkg -l | grep -q "^ii.*webmin"; then
        log "SUCCESS" "Webmin: Paquete instalado"
        increment_passed
    else
        log "ERROR" "Webmin: Paquete no instalado"
        increment_failed
    fi
    
    # Verificar archivos críticos
    local webmin_files=(
        "/usr/share/webmin"
        "/etc/webmin"
        "/etc/webmin/miniserv.conf"
        "/etc/webmin/config"
        "/var/webmin"
    )
    
    for file in "${webmin_files[@]}"; do
        increment_total
        if [[ -e "$file" ]]; then
            log "SUCCESS" "Webmin: $file existe"
            increment_passed
        else
            log "ERROR" "Webmin: $file no existe"
            increment_failed
        fi
    done
    
    # Verificar configuración
    increment_total
    if [[ -f /etc/webmin/miniserv.conf ]]; then
        if grep -q "port=" /etc/webmin/miniserv.conf; then
            local port=$(grep "port=" /etc/webmin/miniserv.conf | cut -d= -f2)
            log "SUCCESS" "Webmin: Puerto configurado ($port)"
            increment_passed
        else
            log "ERROR" "Webmin: Puerto no configurado"
            increment_failed
        fi
    fi
    
    # Verificar acceso web
    increment_total
    local server_ip=$(hostname -I | awk '{print $1}')
    if curl -k -s --connect-timeout 5 "https://$server_ip:10000" >/dev/null 2>&1; then
        log "SUCCESS" "Webmin: Acceso web HTTPS funcionando"
        increment_passed
    elif curl -s --connect-timeout 5 "http://$server_ip:10000" >/dev/null 2>&1; then
        log "SUCCESS" "Webmin: Acceso web HTTP funcionando"
        increment_passed
    else
        log "ERROR" "Webmin: Sin acceso web"
        increment_failed
    fi
}

# Verificar instalación de Virtualmin
check_virtualmin_installation() {
    log "HEADER" "VERIFICACIÓN DE VIRTUALMIN"
    
    # Verificar comando virtualmin
    increment_total
    if command -v virtualmin >/dev/null 2>&1; then
        log "SUCCESS" "Virtualmin: Comando disponible"
        increment_passed
    else
        log "ERROR" "Virtualmin: Comando no disponible"
        increment_failed
    fi
    
    # Verificar módulo en Webmin
    increment_total
    if [[ -d /etc/webmin/virtual-server ]]; then
        log "SUCCESS" "Virtualmin: Módulo instalado en Webmin"
        increment_passed
    else
        log "ERROR" "Virtualmin: Módulo no encontrado"
        increment_failed
    fi
    
    # Verificar bibliotecas
    local virtualmin_libs=(
        "/usr/share/webmin/virtual-server"
        "/usr/share/webmin/virtual-server/virtual-server-lib.pl"
        "/etc/webmin/virtual-server/config"
    )
    
    for lib in "${virtualmin_libs[@]}"; do
        increment_total
        if [[ -e "$lib" ]]; then
            log "SUCCESS" "Virtualmin: $lib existe"
            increment_passed
        else
            log "ERROR" "Virtualmin: $lib no existe"
            increment_failed
        fi
    done
    
    # Verificar funcionalidad básica
    increment_total
    if virtualmin list-domains >/dev/null 2>&1; then
        log "SUCCESS" "Virtualmin: Comando list-domains funciona"
        increment_passed
    else
        log "WARNING" "Virtualmin: Comando list-domains falla"
        increment_warning
    fi
}

# Verificar Authentic Theme
check_authentic_theme() {
    log "HEADER" "VERIFICACIÓN DE AUTHENTIC THEME"
    
    # Verificar instalación
    increment_total
    if [[ -d /usr/share/webmin/authentic-theme ]] || [[ -d /usr/share/webmin/authentic-theme-master ]]; then
        log "SUCCESS" "Authentic Theme: Instalado"
        increment_passed
    else
        log "WARNING" "Authentic Theme: No instalado"
        increment_warning
    fi
    
    # Verificar configuración
    increment_total
    if [[ -f /etc/webmin/config ]]; then
        if grep -q "theme=authentic" /etc/webmin/config; then
            log "SUCCESS" "Authentic Theme: Configurado como tema predeterminado"
            increment_passed
        else
            log "WARNING" "Authentic Theme: No configurado como tema predeterminado"
            increment_warning
        fi
    fi
}

# Verificar stack LAMP
check_lamp_stack() {
    log "HEADER" "VERIFICACIÓN DEL STACK LAMP"
    
    # Apache
    increment_total
    if dpkg -l | grep -q "^ii.*apache2"; then
        log "SUCCESS" "Apache: Instalado"
        increment_passed
    else
        log "ERROR" "Apache: No instalado"
        increment_failed
    fi
    
    # MySQL/MariaDB
    increment_total
    if dpkg -l | grep -E "^ii.*(mysql-server|mariadb-server)"; then
        log "SUCCESS" "MySQL/MariaDB: Instalado"
        increment_passed
    else
        log "ERROR" "MySQL/MariaDB: No instalado"
        increment_failed
    fi
    
    # PHP
    increment_total
    if dpkg -l | grep -q "^ii.*php"; then
        log "SUCCESS" "PHP: Instalado"
        increment_passed
    else
        log "ERROR" "PHP: No instalado"
        increment_failed
    fi
    
    # Verificar módulos PHP críticos
    local php_modules=("mysql" "curl" "gd" "mbstring" "xml" "zip")
    for module in "${php_modules[@]}"; do
        increment_total
        if php -m 2>/dev/null | grep -q "$module"; then
            log "SUCCESS" "PHP: Módulo $module disponible"
            increment_passed
        else
            log "WARNING" "PHP: Módulo $module no disponible"
            increment_warning
        fi
    done
}

# Verificar servidor de correo
check_mail_server() {
    log "HEADER" "VERIFICACIÓN DEL SERVIDOR DE CORREO"
    
    # Postfix
    increment_total
    if dpkg -l | grep -q "^ii.*postfix"; then
        log "SUCCESS" "Postfix: Instalado"
        increment_passed
    else
        log "ERROR" "Postfix: No instalado"
        increment_failed
    fi
    
    # Dovecot
    increment_total
    if dpkg -l | grep -q "^ii.*dovecot-core"; then
        log "SUCCESS" "Dovecot: Instalado"
        increment_passed
    else
        log "WARNING" "Dovecot: No instalado"
        increment_warning
    fi
    
    # Verificar configuración de correo
    local mail_configs=(
        "/etc/postfix/main.cf"
        "/etc/postfix/master.cf"
        "/etc/dovecot/dovecot.conf"
    )
    
    for config in "${mail_configs[@]}"; do
        increment_total
        if [[ -f "$config" ]]; then
            log "SUCCESS" "Correo: $config existe"
            increment_passed
        else
            log "WARNING" "Correo: $config no existe"
            increment_warning
        fi
    done
}

# Verificar seguridad
check_security() {
    log "HEADER" "VERIFICACIÓN DE SEGURIDAD"
    
    # Firewall
    increment_total
    if command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -q "Status: active"; then
            log "SUCCESS" "Firewall UFW: Activo"
            increment_passed
        else
            log "WARNING" "Firewall UFW: Inactivo"
            increment_warning
        fi
    else
        log "WARNING" "Firewall UFW: No instalado"
        increment_warning
    fi
    
    # Fail2ban
    increment_total
    if dpkg -l | grep -q "^ii.*fail2ban"; then
        if systemctl is-active --quiet fail2ban; then
            log "SUCCESS" "Fail2ban: Activo"
            increment_passed
        else
            log "WARNING" "Fail2ban: Instalado pero inactivo"
            increment_warning
        fi
    else
        log "WARNING" "Fail2ban: No instalado"
        increment_warning
    fi
    
    # SSL
    increment_total
    if [[ -f /etc/webmin/miniserv.pem ]]; then
        log "SUCCESS" "SSL: Certificado Webmin presente"
        increment_passed
    else
        log "WARNING" "SSL: Certificado Webmin no encontrado"
        increment_warning
    fi
    
    # Verificar puertos abiertos
    local critical_ports=(22 25 53 80 110 143 443 465 587 993 995 10000)
    for port in "${critical_ports[@]}"; do
        increment_total
        if ss -tlnp 2>/dev/null | grep -q ":$port\b"; then
            log "SUCCESS" "Puerto $port: Abierto"
            increment_passed
        else
            log "WARNING" "Puerto $port: Cerrado"
            increment_warning
        fi
    done
}

# Verificar gestión de archivos
check_file_management() {
    log "HEADER" "VERIFICACIÓN DE GESTIÓN DE ARCHIVOS"
    
    # Verificar administrador de archivos
    increment_total
    if [[ -d /usr/share/webmin/filemin ]]; then
        log "SUCCESS" "Administrador de archivos: Disponible"
        increment_passed
    else
        log "WARNING" "Administrador de archivos: No disponible"
        increment_warning
    fi
    
    # Verificar soporte ZIP
    increment_total
    if command -v zip >/dev/null 2>&1 && command -v unzip >/dev/null 2>&1; then
        log "SUCCESS" "Soporte ZIP: Disponible"
        increment_passed
    else
        log "WARNING" "Soporte ZIP: No disponible"
        increment_warning
    fi
    
    # Verificar permisos
    local critical_dirs=(
        "/var/www"
        "/home"
        "/etc/webmin"
        "/usr/share/webmin"
    )
    
    for dir in "${critical_dirs[@]}"; do
        increment_total
        if [[ -d "$dir" ]]; then
            if [[ -r "$dir" && -w "$dir" ]]; then
                log "SUCCESS" "Directorio $dir: Acceso R/W"
                increment_passed
            else
                log "WARNING" "Directorio $dir: Sin permisos R/W"
                increment_warning
            fi
        else
            log "WARNING" "Directorio $dir: No existe"
            increment_warning
        fi
    done
}

# Verificar actualizaciones
check_updates() {
    log "HEADER" "VERIFICACIÓN DE ACTUALIZACIONES"
    
    # Actualizar lista de paquetes
    apt-get update >/dev/null 2>&1
    
    # Verificar actualizaciones disponibles
    increment_total
    local updates=$(apt list --upgradable 2>/dev/null | wc -l)
    if [[ $updates -gt 1 ]]; then
        log "WARNING" "Actualizaciones disponibles: $((updates-1))"
        increment_warning
    else
        log "SUCCESS" "Sistema actualizado"
        increment_passed
    fi
    
    # Verificar actualizaciones de Webmin
    increment_total
    if [[ -f /usr/share/webmin/update-from-repo.sh ]]; then
        log "SUCCESS" "Webmin: Script de actualización disponible"
        increment_passed
    else
        log "WARNING" "Webmin: Script de actualización no disponible"
        increment_warning
    fi
}

# Verificar servidores virtuales
check_virtual_servers() {
    log "HEADER" "VERIFICACIÓN DE SERVIDORES VIRTUALES"
    
    # Verificar capacidad de crear dominios
    increment_total
    if command -v virtualmin >/dev/null 2>&1; then
        local domains=$(virtualmin list-domains --name-only 2>/dev/null | wc -l)
        log "SUCCESS" "Servidores virtuales: $domains dominios configurados"
        increment_passed
    else
        log "WARNING" "Servidores virtuales: Virtualmin no disponible"
        increment_warning
    fi
    
    # Verificar plantillas
    increment_total
    if [[ -d /etc/webmin/virtual-server/templates ]]; then
        log "SUCCESS" "Plantillas de servidor virtual: Disponibles"
        increment_passed
    else
        log "WARNING" "Plantillas de servidor virtual: No disponibles"
        increment_warning
    fi
}

# Verificar integridad del sistema
check_system_integrity() {
    log "HEADER" "VERIFICACIÓN DE INTEGRIDAD DEL SISTEMA"
    
    # Verificar integridad de paquetes
    increment_total
    if dpkg --audit >/dev/null 2>&1; then
        log "SUCCESS" "Integridad de paquetes: OK"
        increment_passed
    else
        log "WARNING" "Integridad de paquetes: Problemas detectados"
        increment_warning
    fi
    
    # Verificar espacio en disco
    increment_total
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_usage -lt 80 ]]; then
        log "SUCCESS" "Espacio en disco: ${disk_usage}% usado"
        increment_passed
    else
        log "WARNING" "Espacio en disco: ${disk_usage}% usado"
        increment_warning
    fi
    
    # Verificar memoria
    increment_total
    local mem_info=$(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')
    log "SUCCESS" "Uso de memoria: $mem_info"
    increment_passed
}

# Generar reporte final
generate_final_report() {
    log "HEADER" "REPORTE FINAL DE VERIFICACIÓN"
    
    local success_rate=$(( PASSED_CHECKS * 100 / TOTAL_CHECKS ))
    
    cat << EOF

═══════════════════════════════════════════════════════════════════════════════
📊 RESUMEN FINAL DE VERIFICACIÓN
═══════════════════════════════════════════════════════════════════════════════

📈 ESTADÍSTICAS:
   • Total de verificaciones: $TOTAL_CHECKS
   • Verificaciones exitosas: $PASSED_CHECKS
   • Advertencias: $WARNING_CHECKS
   • Errores: $FAILED_CHECKS
   • Tasa de éxito: $success_rate%

EOF

    if [[ $FAILED_CHECKS -eq 0 && $WARNING_CHECKS -eq 0 ]]; then
        echo -e "${GREEN}🎉 ¡SISTEMA 100% FUNCIONAL!${NC}"
        echo -e "${GREEN}   Webmin y Virtualmin están funcionando perfectamente${NC}"
    elif [[ $FAILED_CHECKS -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  SISTEMA FUNCIONAL CON ADVERTENCIAS${NC}"
        echo -e "${YELLOW}   Algunas funciones opcionales pueden no estar disponibles${NC}"
    else
        echo -e "${RED}❌ SISTEMA CON ERRORES${NC}"
        echo -e "${RED}   Se detectaron errores que requieren atención${NC}"
    fi
    
    echo
    echo -e "${CYAN}📋 DETALLES:${NC}"
    echo -e "   • Reporte completo: $REPORT_FILE"
    echo -e "   • Para corregir errores: sudo bash remediacion_total_webmin_virtualmin.sh"
    echo -e "   • Para verificar nuevamente: sudo bash $0"
    
    echo
    echo -e "${CYAN}🔗 ACCESO AL PANEL:${NC}"
    local server_ip=$(hostname -I | awk '{print $1}')
    echo -e "   • Webmin: https://$server_ip:10000"
    echo -e "   • Virtualmin: https://$server_ip:10000 (módulo Virtualmin)"
    
    echo
    echo -e "${CYAN}🆘 SOPORTE:${NC}"
    echo -e "   • Logs: /var/log/webmin/"
    echo -e "   • Configuración: /etc/webmin/"
    echo -e "   • Documentación: https://webmin.com/docs/"
    
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
}

# Función principal
main() {
    # Inicializar log
    mkdir -p "$(dirname "$REPORT_FILE")"
    echo "=== VERIFICACIÓN FINAL INICIADA $(date) ===" > "$REPORT_FILE"
    
    log "INFO" "Iniciando verificación completa de Webmin y Virtualmin"
    log "INFO" "Reporte: $REPORT_FILE"
    
    # Ejecutar todas las verificaciones
    check_ubuntu_debian
    check_root
    check_connectivity
    check_critical_services
    check_webmin_installation
    check_virtualmin_installation
    check_authentic_theme
    check_lamp_stack
    check_mail_server
    check_security
    check_file_management
    check_updates
    check_virtual_servers
    check_system_integrity
    
    # Generar reporte final
    generate_final_report
    
    # Retornar código de salida
    if [[ $FAILED_CHECKS -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
