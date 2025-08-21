#!/bin/bash

# =============================================================================
# DIAGNÓSTICO COMPLETO DE WEBMIN Y VIRTUALMIN
# Script para verificar que todas las funciones estén funcionando sin errores
# =============================================================================

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -e

# Colores para output
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

# Variables globales
DIAGNOSTIC_LOG="/tmp/diagnostico_webmin_$(date +%Y%m%d_%H%M%S).log"
ERROR_COUNT=0
WARNING_COUNT=0
SUCCESS_COUNT=0

# Funciones de logging
# DUPLICADA: Función reemplazada por common_functions.sh
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
# Contenido de función duplicada
# Fin de función duplicada

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

log_step() {
    echo -e "${PURPLE}[PASO $(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$DIAGNOSTIC_LOG"
}

# Función para verificar instalación de Webmin
check_webmin_installation() {
    log_step "Verificando instalación de Webmin..."
    
    # Verificar directorio de instalación
    if [[ -d "/opt/webmin" ]]; then
        log_success "Directorio de Webmin encontrado: /opt/webmin"
        
        # Verificar archivos principales
        local required_files=(
            "/opt/webmin/miniserv.pl"
            "/opt/webmin/miniserv.conf"
            "/opt/webmin/config"
            "/opt/webmin/setup.sh"
        )
        
        for file in "${required_files[@]}"; do
            if [[ -f "$file" ]]; then
                log_success "Archivo encontrado: $file"
            else
                log_error "Archivo faltante: $file"
            fi
        done
        
        # Verificar permisos
        if [[ -x "/opt/webmin/miniserv.pl" ]]; then
            log_success "Permisos de ejecución correctos en miniserv.pl"
        else
            log_error "Permisos incorrectos en miniserv.pl"
        fi
        
    else
        log_error "Directorio de Webmin no encontrado: /opt/webmin"
    fi
    
    # Verificar instalación alternativa
    if [[ -d "/usr/share/webmin" ]]; then
        log_info "Instalación alternativa encontrada: /usr/share/webmin"
    fi
}

# Función para verificar servicios del sistema
check_system_services() {
    log_step "Verificando servicios del sistema..."
    
    local services=("webmin" "apache2" "httpd" "mysql" "mysqld" "mariadb" "postfix" "named" "bind9")
    
    for service in "${services[@]}"; do
        if systemctl list-unit-files 2>/dev/null | grep -q "^$service.service" || \
           service --status-all 2>/dev/null | grep -q "$service"; then
            
            if systemctl is-active --quiet "$service" 2>/dev/null || \
               service "$service" status >/dev/null 2>&1; then
                log_success "Servicio $service está ejecutándose"
            else
                log_warning "Servicio $service está instalado pero no ejecutándose"
            fi
        fi
    done
}

# Función para verificar conectividad de Webmin
check_webmin_connectivity() {
    log_step "Verificando conectividad de Webmin..."
    
    local ports=("10000" "10001" "10002")
    
    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port " || \
           ss -tuln 2>/dev/null | grep -q ":$port "; then
            log_success "Puerto $port está en uso (posiblemente Webmin)"
            
            # Probar conexión HTTP/HTTPS
            if curl -k -s --connect-timeout 5 "https://localhost:$port" >/dev/null 2>&1; then
                log_success "Conexión HTTPS exitosa en puerto $port"
            elif curl -s --connect-timeout 5 "http://localhost:$port" >/dev/null 2>&1; then
                log_success "Conexión HTTP exitosa en puerto $port"
            else
                log_warning "Puerto $port en uso pero no responde a HTTP/HTTPS"
            fi
        fi
    done
}

# Función para verificar configuración de Webmin
check_webmin_configuration() {
    log_step "Verificando configuración de Webmin..."
    
    local config_files=(
        "/opt/webmin/miniserv.conf"
        "/etc/webmin/miniserv.conf"
        "/usr/share/webmin/miniserv.conf"
    )
    
    local config_found=false
    
    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            log_success "Archivo de configuración encontrado: $config_file"
            config_found=true
            
            # Verificar configuraciones críticas
            if grep -q "^port=" "$config_file"; then
                local port=$(grep "^port=" "$config_file" | cut -d'=' -f2)
                log_info "Puerto configurado: $port"
            else
                log_warning "Puerto no configurado en $config_file"
            fi
            
            if grep -q "^ssl=" "$config_file"; then
                local ssl=$(grep "^ssl=" "$config_file" | cut -d'=' -f2)
                log_info "SSL configurado: $ssl"
            else
                log_warning "SSL no configurado en $config_file"
            fi
            
            # Verificar permisos del archivo de configuración
            if [[ -r "$config_file" ]]; then
                log_success "Permisos de lectura correctos en $config_file"
            else
                log_error "No se puede leer $config_file"
            fi
            
            break
        fi
    done
    
    if [[ "$config_found" == false ]]; then
        log_error "No se encontró archivo de configuración de Webmin"
    fi
}

# Función para verificar módulos de Webmin
check_webmin_modules() {
    log_step "Verificando módulos de Webmin..."
    
    local module_dirs=(
        "/opt/webmin"
        "/usr/share/webmin"
        "/etc/webmin"
    )
    
    for module_dir in "${module_dirs[@]}"; do
        if [[ -d "$module_dir" ]]; then
            log_info "Verificando módulos en: $module_dir"
            
            # Contar módulos disponibles
            local module_count=$(find "$module_dir" -maxdepth 1 -type d -name "*" | wc -l)
            log_info "Módulos encontrados: $module_count"
            
            # Verificar módulos críticos
            local critical_modules=("system-status" "proc" "mount" "fdisk" "users" "groups")
            
            for module in "${critical_modules[@]}"; do
                if [[ -d "$module_dir/$module" ]]; then
                    log_success "Módulo crítico encontrado: $module"
                else
                    log_warning "Módulo crítico faltante: $module"
                fi
            done
            
            break
        fi
    done
}

# Función para verificar Virtualmin
check_virtualmin_installation() {
    log_step "Verificando instalación de Virtualmin..."
    
    local virtualmin_dirs=(
        "/opt/webmin/virtual-server"
        "/usr/share/webmin/virtual-server"
        "/etc/webmin/virtual-server"
    )
    
    local virtualmin_found=false
    
    for vmin_dir in "${virtualmin_dirs[@]}"; do
        if [[ -d "$vmin_dir" ]]; then
            log_success "Directorio de Virtualmin encontrado: $vmin_dir"
            virtualmin_found=true
            
            # Verificar archivos principales de Virtualmin
            local vmin_files=("module.info" "virtual_server.pl" "config")
            
            for file in "${vmin_files[@]}"; do
                if [[ -f "$vmin_dir/$file" ]]; then
                    log_success "Archivo de Virtualmin encontrado: $file"
                else
                    log_warning "Archivo de Virtualmin faltante: $file"
                fi
            done
            
            # Verificar versión de Virtualmin
            if [[ -f "$vmin_dir/module.info" ]]; then
                local version=$(grep "version=" "$vmin_dir/module.info" | cut -d'=' -f2 | tr -d '"')
                log_info "Versión de Virtualmin: $version"
            fi
            
            break
        fi
    done
    
    if [[ "$virtualmin_found" == false ]]; then
        log_error "Virtualmin no está instalado"
    fi
}

# Función para verificar Authentic Theme
check_authentic_theme() {
    log_step "Verificando Authentic Theme..."
    
    local theme_dirs=(
        "/opt/webmin/authentic-theme"
        "/usr/share/webmin/authentic-theme"
    )
    
    local theme_found=false
    
    for theme_dir in "${theme_dirs[@]}"; do
        if [[ -d "$theme_dir" ]]; then
            log_success "Authentic Theme encontrado: $theme_dir"
            theme_found=true
            
            # Verificar archivos del tema
            local theme_files=("theme.info" "config" "index.cgi")
            
            for file in "${theme_files[@]}"; do
                if [[ -f "$theme_dir/$file" ]]; then
                    log_success "Archivo del tema encontrado: $file"
                else
                    log_warning "Archivo del tema faltante: $file"
                fi
            done
            
            # Verificar versión del tema
            if [[ -f "$theme_dir/theme.info" ]]; then
                local version=$(grep "version=" "$theme_dir/theme.info" | cut -d'=' -f2 | tr -d '"')
                log_info "Versión de Authentic Theme: $version"
            fi
            
            break
        fi
    done
    
    if [[ "$theme_found" == false ]]; then
        log_warning "Authentic Theme no está instalado"
    fi
}

# Función para verificar base de datos
check_database_connectivity() {
    log_step "Verificando conectividad de base de datos..."
    
    # Verificar MySQL/MariaDB
    if command -v mysql >/dev/null 2>&1; then
        if mysql -e "SELECT 1;" >/dev/null 2>&1; then
            log_success "Conexión a MySQL/MariaDB exitosa"
        else
            log_warning "MySQL/MariaDB instalado pero no se puede conectar"
        fi
    else
        log_warning "Cliente MySQL/MariaDB no encontrado"
    fi
    
    # Verificar PostgreSQL
    if command -v psql >/dev/null 2>&1; then
        if sudo -u postgres psql -c "SELECT 1;" >/dev/null 2>&1; then
            log_success "Conexión a PostgreSQL exitosa"
        else
            log_warning "PostgreSQL instalado pero no se puede conectar"
        fi
    else
        log_info "PostgreSQL no está instalado"
    fi
}

# Función para verificar servidor web
check_web_server() {
    log_step "Verificando servidor web..."
    
    # Verificar Apache
    if command -v apache2 >/dev/null 2>&1 || command -v httpd >/dev/null 2>&1; then
        local apache_cmd="apache2"
        if command -v httpd >/dev/null 2>&1; then
            apache_cmd="httpd"
        fi
        
        if systemctl is-active --quiet "$apache_cmd" 2>/dev/null; then
            log_success "Apache está ejecutándose"
            
            # Verificar puertos
            if netstat -tuln 2>/dev/null | grep -q ":80 " || ss -tuln 2>/dev/null | grep -q ":80 "; then
                log_success "Puerto 80 (HTTP) está activo"
            else
                log_warning "Puerto 80 (HTTP) no está activo"
            fi
            
            if netstat -tuln 2>/dev/null | grep -q ":443 " || ss -tuln 2>/dev/null | grep -q ":443 "; then
                log_success "Puerto 443 (HTTPS) está activo"
            else
                log_warning "Puerto 443 (HTTPS) no está activo"
            fi
        else
            log_warning "Apache está instalado pero no ejecutándose"
        fi
    else
        log_warning "Apache no está instalado"
    fi
    
    # Verificar Nginx
    if command -v nginx >/dev/null 2>&1; then
        if systemctl is-active --quiet nginx 2>/dev/null; then
            log_success "Nginx está ejecutándose"
        else
            log_warning "Nginx está instalado pero no ejecutándose"
        fi
    fi
}

# Función para verificar recursos del sistema
check_system_resources() {
    log_step "Verificando recursos del sistema..."
    
    # Verificar memoria
    local total_mem=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    local used_mem=$(free -m | awk 'NR==2{printf "%.0f", $3}')
    local mem_percent=$((used_mem * 100 / total_mem))
    
    log_info "Memoria total: ${total_mem}MB"
    log_info "Memoria usada: ${used_mem}MB (${mem_percent}%)"
    
    if [[ $mem_percent -gt 90 ]]; then
        log_error "Uso de memoria crítico: ${mem_percent}%"
    elif [[ $mem_percent -gt 80 ]]; then
        log_warning "Uso de memoria alto: ${mem_percent}%"
    else
        log_success "Uso de memoria normal: ${mem_percent}%"
    fi
    
    # Verificar espacio en disco
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    log_info "Uso de disco raíz: ${disk_usage}%"
    
    if [[ $disk_usage -gt 90 ]]; then
        log_error "Espacio en disco crítico: ${disk_usage}%"
    elif [[ $disk_usage -gt 80 ]]; then
        log_warning "Espacio en disco alto: ${disk_usage}%"
    else
        log_success "Espacio en disco normal: ${disk_usage}%"
    fi
    
    # Verificar carga del sistema
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    log_info "Carga promedio del sistema: $load_avg"
}

# Función para verificar logs de errores
check_error_logs() {
    log_step "Verificando logs de errores..."
    
    local log_files=(
        "/var/log/webmin/miniserv.error"
        "/var/log/webmin/miniserv.log"
        "/var/log/apache2/error.log"
        "/var/log/httpd/error_log"
        "/var/log/mysql/error.log"
        "/var/log/mysqld.log"
        "/var/log/syslog"
        "/var/log/messages"
    )
    
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            log_info "Verificando log: $log_file"
            
            # Buscar errores recientes (últimas 24 horas)
            local recent_errors=$(find "$log_file" -mtime -1 -exec grep -i "error\|critical\|fatal" {} \; 2>/dev/null | wc -l)
            
            if [[ $recent_errors -gt 0 ]]; then
                log_warning "$recent_errors errores encontrados en $log_file (últimas 24h)"
            else
                log_success "No se encontraron errores recientes en $log_file"
            fi
        fi
    done
}

# Función para verificar permisos de archivos
check_file_permissions() {
    log_step "Verificando permisos de archivos críticos..."
    
    local critical_files=(
        "/opt/webmin/miniserv.pl:755"
        "/opt/webmin/miniserv.conf:600"
        "/etc/webmin:755"
        "/var/log/webmin:755"
    )
    
    for file_perm in "${critical_files[@]}"; do
        local file=$(echo "$file_perm" | cut -d':' -f1)
        local expected_perm=$(echo "$file_perm" | cut -d':' -f2)
        
        if [[ -e "$file" ]]; then
            local actual_perm=$(stat -c "%a" "$file" 2>/dev/null || echo "unknown")
            
            if [[ "$actual_perm" == "$expected_perm" ]]; then
                log_success "Permisos correctos en $file ($actual_perm)"
            else
                log_warning "Permisos incorrectos en $file (actual: $actual_perm, esperado: $expected_perm)"
            fi
        else
            log_warning "Archivo no encontrado: $file"
        fi
    done
}

# Función para mostrar resumen del diagnóstico
show_diagnostic_summary() {
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CYAN}📋 RESUMEN DEL DIAGNÓSTICO${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    echo -e "${GREEN}✅ Verificaciones exitosas: $SUCCESS_COUNT${NC}"
    echo -e "${YELLOW}⚠️  Advertencias: $WARNING_COUNT${NC}"
    echo -e "${RED}❌ Errores: $ERROR_COUNT${NC}"
    echo
    echo -e "${BLUE}📄 Log completo: $DIAGNOSTIC_LOG${NC}"
    echo
    
    if [[ $ERROR_COUNT -eq 0 && $WARNING_COUNT -eq 0 ]]; then
        echo -e "${GREEN}🎉 SISTEMA COMPLETAMENTE FUNCIONAL${NC}"
        echo "Todas las funciones de Webmin y Virtualmin están operando correctamente."
    elif [[ $ERROR_COUNT -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  SISTEMA FUNCIONAL CON ADVERTENCIAS${NC}"
        echo "El sistema está funcionando pero hay algunas configuraciones que podrían mejorarse."
    else
        echo -e "${RED}❌ SISTEMA CON ERRORES${NC}"
        echo "Se encontraron errores que requieren atención inmediata."
    fi
    
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
}

# Función principal
main() {
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CYAN}🔍 DIAGNÓSTICO COMPLETO DE WEBMIN Y VIRTUALMIN${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    
    log "Iniciando diagnóstico completo del sistema..."
    log "Log de diagnóstico: $DIAGNOSTIC_LOG"
    
    # Ejecutar todas las verificaciones
    check_webmin_installation
    check_webmin_configuration
    check_webmin_modules
    check_webmin_connectivity
    check_virtualmin_installation
    check_authentic_theme
    check_system_services
    check_web_server
    check_database_connectivity
    check_system_resources
    check_file_permissions
    check_error_logs
    
    # Mostrar resumen
    show_diagnostic_summary
    
    log "Diagnóstico completado"
    
    # Código de salida basado en errores
    if [[ $ERROR_COUNT -gt 0 ]]; then
        exit 1
    elif [[ $WARNING_COUNT -gt 0 ]]; then
        exit 2
    else
        exit 0
    fi
}

# Ejecutar función principal
main "$@"
