#!/bin/bash

# =============================================================================
# VERIFICACIÓN POST-INSTALACIÓN - UN COMANDO
# Script para verificar que la instalación automática fue exitosa
# =============================================================================

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -euo pipefail

# Colores
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

# Contadores
TESTS_PASSED=0
TESTS_FAILED=0
WARNINGS=0

# Funciones de logging
# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Contenido de función duplicada
# Fin de función duplicada

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Contenido de función duplicada
# Fin de función duplicada

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Contenido de función duplicada
# Fin de función duplicada

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

log_header() {
    echo
    echo -e "${PURPLE}=== $1 ===${NC}"
}

# Banner
show_banner() {
    clear
    cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════════
   🔍 VERIFICACIÓN POST-INSTALACIÓN WEBMIN Y VIRTUALMIN
   
   ✅ Validación completa de servicios
   🔧 Verificación de configuración
   📊 Comprobación de funcionalidades
   
═══════════════════════════════════════════════════════════════════════════════
EOF
}

# Verificar servicios del sistema
verify_system_services() {
    log_header "VERIFICACIÓN DE SERVICIOS DEL SISTEMA"
    
    local services=("webmin" "apache2" "mysql" "postfix")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            local status=$(systemctl is-enabled "$service" 2>/dev/null)
            log_success "Servicio $service: ACTIVO ($status)"
        else
            log_error "Servicio $service: INACTIVO"
        fi
    done
}

# Verificar puertos de red
verify_network_ports() {
    log_header "VERIFICACIÓN DE PUERTOS DE RED"
    
    local ports=(
        "10000:Webmin"
        "80:Apache HTTP"
        "443:Apache HTTPS"
        "25:SMTP"
        "3306:MySQL"
    )
    
    for port_info in "${ports[@]}"; do
        local port="${port_info%:*}"
        local service="${port_info#*:}"
        
        if ss -tlnp 2>/dev/null | grep -q ":$port\b" || netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            log_success "Puerto $port ($service): ABIERTO"
        else
            log_warning "Puerto $port ($service): CERRADO"
        fi
    done
}

# Verificar Webmin
verify_webmin() {
    log_header "VERIFICACIÓN DE WEBMIN"
    
    # Verificar instalación
    if [[ -d "/etc/webmin" ]]; then
        log_success "Directorio de configuración Webmin: PRESENTE"
    else
        log_error "Directorio de configuración Webmin: AUSENTE"
        return 1
    fi
    
    # Verificar proceso
    if pgrep -f "miniserv.pl" >/dev/null; then
        log_success "Proceso Webmin: EJECUTÁNDOSE"
    else
        log_error "Proceso Webmin: NO EJECUTÁNDOSE"
    fi
    
    # Verificar acceso web
    local server_ip=$(hostname -I | awk '{print $1}')
    if curl -k -s --connect-timeout 5 "https://$server_ip:10000" >/dev/null 2>&1; then
        log_success "Acceso HTTPS a Webmin: DISPONIBLE"
    elif curl -s --connect-timeout 5 "http://$server_ip:10000" >/dev/null 2>&1; then
        log_success "Acceso HTTP a Webmin: DISPONIBLE"
    else
        log_error "Acceso web a Webmin: NO DISPONIBLE"
    fi
    
    # Verificar configuración SSL
    if grep -q "ssl=1" /etc/webmin/miniserv.conf 2>/dev/null; then
        log_success "SSL en Webmin: HABILITADO"
    else
        log_warning "SSL en Webmin: DESHABILITADO"
    fi
}

# Verificar Virtualmin
verify_virtualmin() {
    log_header "VERIFICACIÓN DE VIRTUALMIN"
    
    # Verificar comando virtualmin
    if command -v virtualmin >/dev/null 2>&1; then
        log_success "Comando virtualmin: DISPONIBLE"
        
        # Verificar funcionalidad básica
        if virtualmin list-domains >/dev/null 2>&1; then
            log_success "Virtualmin: FUNCIONANDO"
        else
            log_warning "Virtualmin: INSTALADO PERO CON ERRORES"
        fi
    else
        log_error "Comando virtualmin: NO DISPONIBLE"
    fi
    
    # Verificar módulo en Webmin
    if [[ -d "/etc/webmin/virtual-server" ]]; then
        log_success "Módulo Virtualmin en Webmin: PRESENTE"
    else
        log_error "Módulo Virtualmin en Webmin: AUSENTE"
    fi
    
    # Verificar configuración
    if [[ -f "/etc/webmin/virtual-server/config" ]]; then
        log_success "Configuración Virtualmin: PRESENTE"
    else
        log_warning "Configuración Virtualmin: AUSENTE"
    fi
}

# Verificar Authentic Theme
verify_authentic_theme() {
    log_header "VERIFICACIÓN DE AUTHENTIC THEME"
    
    if [[ -d "/usr/share/webmin/authentic-theme" ]]; then
        log_success "Authentic Theme: INSTALADO"
        
        if grep -q "theme=authentic-theme" /etc/webmin/config 2>/dev/null; then
            log_success "Authentic Theme: ACTIVADO"
        else
            log_warning "Authentic Theme: INSTALADO PERO NO ACTIVADO"
        fi
    else
        log_warning "Authentic Theme: NO INSTALADO"
    fi
}

# Verificar stack LAMP
verify_lamp_stack() {
    log_header "VERIFICACIÓN DEL STACK LAMP"
    
    # Apache
    if systemctl is-active --quiet apache2; then
        log_success "Apache: ACTIVO"
        
        # Verificar módulos importantes
        local modules=("rewrite" "ssl" "headers")
        for module in "${modules[@]}"; do
            if apache2ctl -M 2>/dev/null | grep -q "${module}_module"; then
                log_success "Módulo Apache $module: HABILITADO"
            else
                log_warning "Módulo Apache $module: DESHABILITADO"
            fi
        done
    else
        log_error "Apache: INACTIVO"
    fi
    
    # MySQL
    if systemctl is-active --quiet mysql; then
        log_success "MySQL: ACTIVO"
        
        # Verificar acceso
        if mysql -e "SELECT 1;" >/dev/null 2>&1; then
            log_success "Acceso a MySQL: FUNCIONANDO"
        else
            log_warning "Acceso a MySQL: REQUIERE CONFIGURACIÓN"
        fi
    else
        log_error "MySQL: INACTIVO"
    fi
    
    # PHP
    if command -v php >/dev/null 2>&1; then
        local php_version=$(php -v | head -1 | awk '{print $2}' | cut -d. -f1,2)
        log_success "PHP: INSTALADO (versión $php_version)"
        
        # Verificar módulos PHP importantes
        local php_modules=("mysql" "curl" "gd" "xml")
        for module in "${php_modules[@]}"; do
            if php -m | grep -qi "$module"; then
                log_success "Módulo PHP $module: DISPONIBLE"
            else
                log_warning "Módulo PHP $module: NO DISPONIBLE"
            fi
        done
    else
        log_error "PHP: NO INSTALADO"
    fi
}

# Verificar correo electrónico
verify_mail_system() {
    log_header "VERIFICACIÓN DEL SISTEMA DE CORREO"
    
    # Postfix
    if systemctl is-active --quiet postfix; then
        log_success "Postfix: ACTIVO"
        
        # Verificar configuración básica
        if [[ -f "/etc/postfix/main.cf" ]]; then
            log_success "Configuración Postfix: PRESENTE"
        else
            log_error "Configuración Postfix: AUSENTE"
        fi
    else
        log_error "Postfix: INACTIVO"
    fi
    
    # Dovecot (si está instalado)
    if systemctl is-active --quiet dovecot 2>/dev/null; then
        log_success "Dovecot: ACTIVO"
    else
        log_info "Dovecot: NO INSTALADO (opcional)"
    fi
}

# Verificar firewall
verify_firewall() {
    log_header "VERIFICACIÓN DEL FIREWALL"
    
    if command -v ufw >/dev/null 2>&1; then
        local ufw_status=$(ufw status | head -1 | awk '{print $2}')
        
        if [[ "$ufw_status" == "active" ]]; then
            log_success "UFW Firewall: ACTIVO"
            
            # Verificar reglas importantes
            if ufw status | grep -q "10000"; then
                log_success "Regla firewall Webmin: CONFIGURADA"
            else
                log_warning "Regla firewall Webmin: NO CONFIGURADA"
            fi
        else
            log_warning "UFW Firewall: INACTIVO"
        fi
    else
        log_info "UFW: NO INSTALADO"
    fi
}

# Verificar certificados SSL
verify_ssl_certificates() {
    log_header "VERIFICACIÓN DE CERTIFICADOS SSL"
    
    if [[ -f "/etc/webmin/miniserv.pem" ]]; then
        log_success "Certificado SSL Webmin: PRESENTE"
        
        # Verificar validez del certificado
        if openssl x509 -in /etc/webmin/miniserv.pem -checkend 86400 >/dev/null 2>&1; then
            log_success "Certificado SSL Webmin: VÁLIDO"
        else
            log_warning "Certificado SSL Webmin: EXPIRANDO PRONTO"
        fi
    else
        log_warning "Certificado SSL Webmin: AUSENTE"
    fi
}

# Verificar recursos del sistema
verify_system_resources() {
    log_header "VERIFICACIÓN DE RECURSOS DEL SISTEMA"
    
    # Memoria
    local mem_total=$(free -m | awk 'NR==2{print $2}')
    local mem_used=$(free -m | awk 'NR==2{print $3}')
    local mem_percent=$((mem_used * 100 / mem_total))
    
    if [[ $mem_percent -lt 80 ]]; then
        log_success "Uso de memoria: ${mem_percent}% (${mem_used}MB/${mem_total}MB)"
    else
        log_warning "Uso de memoria alto: ${mem_percent}% (${mem_used}MB/${mem_total}MB)"
    fi
    
    # Disco
    local disk_usage=$(df -h / | awk 'NR==2{print $5}' | sed 's/%//')
    
    if [[ $disk_usage -lt 80 ]]; then
        log_success "Uso de disco: ${disk_usage}%"
    else
        log_warning "Uso de disco alto: ${disk_usage}%"
    fi
    
    # Carga del sistema
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    log_info "Carga promedio del sistema: $load_avg"
}

# Verificar conectividad externa
verify_external_connectivity() {
    log_header "VERIFICACIÓN DE CONECTIVIDAD EXTERNA"
    
    local test_sites=("google.com" "github.com" "download.webmin.com")
    
    for site in "${test_sites[@]}"; do
        if ping -c 1 -W 5 "$site" >/dev/null 2>&1; then
            log_success "Conectividad a $site: OK"
        else
            log_warning "Conectividad a $site: FALLA"
        fi
    done
}

# Mostrar resumen final
show_summary() {
    log_header "RESUMEN DE VERIFICACIÓN"
    
    local total_tests=$((TESTS_PASSED + TESTS_FAILED))
    local success_rate=0
    
    if [[ $total_tests -gt 0 ]]; then
        success_rate=$((TESTS_PASSED * 100 / total_tests))
    fi
    
    echo
    echo -e "${GREEN}✅ Pruebas exitosas: $TESTS_PASSED${NC}"
    echo -e "${YELLOW}⚠️  Advertencias: $WARNINGS${NC}"
    echo -e "${RED}❌ Errores: $TESTS_FAILED${NC}"
    echo -e "${BLUE}📊 Tasa de éxito: ${success_rate}%${NC}"
    echo
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 ¡INSTALACIÓN VERIFICADA EXITOSAMENTE!${NC}"
        echo -e "${GREEN}   Todos los componentes están funcionando correctamente${NC}"
        echo
        echo -e "${CYAN}🌐 Acceso al panel:${NC}"
        echo -e "   URL: https://$(hostname -I | awk '{print $1}'):10000"
        echo -e "   Usuario: root"
        echo -e "   Contraseña: [contraseña de root del sistema]"
    elif [[ $TESTS_FAILED -lt 3 ]]; then
        echo -e "${YELLOW}⚡ INSTALACIÓN FUNCIONAL CON ADVERTENCIAS MENORES${NC}"
        echo -e "${YELLOW}   El sistema está operativo pero puede requerir ajustes${NC}"
    else
        echo -e "${RED}🚨 INSTALACIÓN CON ERRORES CRÍTICOS${NC}"
        echo -e "${RED}   Se requiere revisión manual de la configuración${NC}"
    fi
    
    echo
}

# Función principal
main() {
    show_banner
    
    echo
    log_info "Iniciando verificación post-instalación..."
    log_info "Fecha: $(date)"
    log_info "Sistema: $(uname -sr)"
    
    # Ejecutar todas las verificaciones
    verify_system_services
    verify_network_ports
    verify_webmin
    verify_virtualmin
    verify_authentic_theme
    verify_lamp_stack
    verify_mail_system
    verify_firewall
    verify_ssl_certificates
    verify_system_resources
    verify_external_connectivity
    
    # Mostrar resumen
    show_summary
    
    # Código de salida
    if [[ $TESTS_FAILED -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Ejecutar función principal
main "$@"
