#!/bin/bash

# Diagnóstico completo de problemas Webmin/Virtualmin en Ubuntu
# Detecta y reporta todos los problemas de instalación

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

set -euo pipefail

# Configuración de colores
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

LOG_FILE="/tmp/diagnostico_webmin_$(date +%Y%m%d_%H%M%S).log"
PROBLEMS_FOUND=()
SOLUTIONS=()

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Contenido de función duplicada
# Fin de función duplicada

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

add_solution() {
    SOLUTIONS+=("$1")
}

echo -e "${PURPLE}============================================${NC}"
echo -e "${PURPLE}  DIAGNÓSTICO WEBMIN/VIRTUALMIN UBUNTU    ${NC}"
echo -e "${PURPLE}============================================${NC}"
echo ""

# 1. INFORMACIÓN DEL SISTEMA
check_system_info() {
    log_info "=== INFORMACIÓN DEL SISTEMA ==="
    
    echo "Sistema: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Desconocido")"
    echo "Versión: $(lsb_release -r 2>/dev/null | cut -f2 || echo "Desconocida")"
    echo "Codename: $(lsb_release -c 2>/dev/null | cut -f2 || echo "Desconocido")"
    echo "Arquitectura: $(uname -m)"
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
    echo "Memoria: $(free -h | grep '^Mem:' | awk '{print $2 " total, " $7 " disponible"}')"
    echo "Disco: $(df -h / | awk 'NR==2 {print $4 " libre de " $2}')"
    echo ""
}

# 2. VERIFICAR PERMISOS Y USUARIO
check_permissions() {
    log_info "=== VERIFICANDO PERMISOS ==="
    
    if [[ $EUID -eq 0 ]]; then
        log_success "Ejecutándose como root"
    else
        log_warning "No se está ejecutando como root"
        log_warning "Usuario actual: $(whoami)"
        
        if groups "$USER" | grep -q sudo; then
            log_info "Usuario tiene permisos sudo"
        else
            log_error "Usuario NO tiene permisos sudo"
            add_solution "Agregar usuario al grupo sudo: sudo usermod -aG sudo $USER"
        fi
    fi
    echo ""
}

# 3. VERIFICAR CONECTIVIDAD DE RED
check_network() {
    log_info "=== VERIFICANDO CONECTIVIDAD ==="
    
    # Internet
    if ping -c 3 8.8.8.8 >/dev/null 2>&1; then
        log_success "Conectividad a Internet: OK"
    else
        log_error "Sin conectividad a Internet"
        add_solution "Verificar configuración de red y DNS"
    fi
    
    # DNS
    if nslookup google.com >/dev/null 2>&1; then
        log_success "Resolución DNS: OK"
    else
        log_error "Problemas con resolución DNS"
        add_solution "Configurar DNS: echo 'nameserver 8.8.8.8' >> /etc/resolv.conf"
    fi
    
    # Repositorios oficiales
    if curl -s --connect-timeout 10 https://download.webmin.com >/dev/null 2>&1; then
        log_success "Acceso a repositorios Webmin: OK"
    else
        log_warning "Problemas de acceso a repositorios Webmin"
    fi
    
    echo ""
}

# 4. VERIFICAR REPOSITORIOS
check_repositories() {
    log_info "=== VERIFICANDO REPOSITORIOS ==="
    
    # Repositorio Webmin
    if grep -r "download.webmin.com" /etc/apt/sources.list* 2>/dev/null | grep -v "^#"; then
        log_success "Repositorio Webmin configurado"
    else
        log_error "Repositorio Webmin NO configurado"
        add_solution "Agregar repositorio Webmin"
    fi
    
    # Llaves GPG
    if apt-key list 2>/dev/null | grep -i webmin >/dev/null; then
        log_success "Llave GPG Webmin presente"
    else
        log_warning "Llave GPG Webmin no encontrada"
        add_solution "Instalar llave GPG de Webmin"
    fi
    
    # Actualización de repositorios
    local last_update=$(stat -c %Y /var/lib/apt/lists 2>/dev/null || echo 0)
    local current_time=$(date +%s)
    local hours_since_update=$(( (current_time - last_update) / 3600 ))
    
    if [[ $hours_since_update -lt 24 ]]; then
        log_success "Repositorios actualizados recientemente"
    else
        log_warning "Repositorios no actualizados en ${hours_since_update} horas"
        add_solution "Actualizar repositorios: apt update"
    fi
    
    echo ""
}

# 5. VERIFICAR INSTALACIÓN DE WEBMIN
check_webmin_installation() {
    log_info "=== VERIFICANDO INSTALACIÓN WEBMIN ==="
    
    # Paquete instalado
    if dpkg -l | grep -q webmin; then
        local version=$(dpkg -l | grep webmin | awk '{print $3}')
        log_success "Webmin instalado: versión $version"
    else
        log_error "Webmin NO está instalado"
        add_solution "Instalar Webmin"
        return
    fi
    
    # Directorio de instalación
    if [[ -d "/usr/share/webmin" ]]; then
        log_success "Directorio Webmin: /usr/share/webmin"
    else
        log_error "Directorio Webmin NO encontrado"
        add_solution "Reinstalar Webmin completamente"
    fi
    
    # Archivos de configuración
    local config_files=(
        "/etc/webmin/miniserv.conf"
        "/etc/webmin/config"
        "/etc/webmin/webmin.acl"
    )
    
    for config in "${config_files[@]}"; do
        if [[ -f "$config" ]]; then
            local size=$(stat -c%s "$config")
            if [[ $size -gt 0 ]]; then
                log_success "Configuración $(basename "$config"): OK"
            else
                log_error "Configuración $(basename "$config"): VACÍA"
                add_solution "Regenerar configuración de Webmin"
            fi
        else
            log_error "Configuración $(basename "$config"): NO EXISTE"
            add_solution "Reinstalar o reconfigurar Webmin"
        fi
    done
    
    echo ""
}

# 6. VERIFICAR VIRTUALMIN
check_virtualmin_installation() {
    log_info "=== VERIFICANDO INSTALACIÓN VIRTUALMIN ==="
    
    # Comando virtualmin
    if command -v virtualmin >/dev/null 2>&1; then
        log_success "Comando virtualmin disponible"
        local version=$(virtualmin version 2>/dev/null | head -1 || echo "Desconocida")
        log_info "Versión: $version"
    else
        log_error "Comando virtualmin NO disponible"
        add_solution "Instalar Virtualmin"
    fi
    
    # Módulo en Webmin
    if [[ -d "/usr/share/webmin/virtual-server" ]]; then
        log_success "Módulo Virtualmin en Webmin: OK"
    else
        log_error "Módulo Virtualmin NO encontrado"
        add_solution "Instalar módulo Virtualmin"
    fi
    
    # Configuración Virtualmin
    if [[ -f "/etc/webmin/virtual-server/config" ]]; then
        log_success "Configuración Virtualmin: OK"
    else
        log_error "Configuración Virtualmin NO existe"
        add_solution "Configurar Virtualmin inicialmente"
    fi
    
    echo ""
}

# 7. VERIFICAR SERVICIOS
check_services() {
    log_info "=== VERIFICANDO SERVICIOS ==="
    
    local critical_services=("webmin" "apache2" "mysql" "postfix" "named" "dovecot")
    
    for service in "${critical_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_success "Servicio $service: ACTIVO"
        else
            if systemctl is-enabled --quiet "$service" 2>/dev/null; then
                log_warning "Servicio $service: INACTIVO (pero habilitado)"
                add_solution "Iniciar servicio: systemctl start $service"
            else
                if dpkg -l | grep -q "^ii.*$service"; then
                    log_warning "Servicio $service: INSTALADO pero deshabilitado"
                    add_solution "Habilitar e iniciar: systemctl enable --now $service"
                else
                    log_error "Servicio $service: NO INSTALADO"
                    add_solution "Instalar $service"
                fi
            fi
        fi
    done
    
    echo ""
}

# 8. VERIFICAR PUERTOS
check_ports() {
    log_info "=== VERIFICANDO PUERTOS ==="
    
    local ports=("10000:Webmin" "80:HTTP" "443:HTTPS" "22:SSH" "25:SMTP" "53:DNS")
    
    for port_info in "${ports[@]}"; do
        local port="${port_info%:*}"
        local service="${port_info#*:}"
        
        if netstat -tuln | grep -q ":${port} "; then
            log_success "Puerto $port ($service): ABIERTO"
        else
            log_warning "Puerto $port ($service): CERRADO"
            add_solution "Verificar servicio para puerto $port"
        fi
    done
    
    echo ""
}

# 9. VERIFICAR FIREWALL
check_firewall() {
    log_info "=== VERIFICANDO FIREWALL ==="
    
    # UFW
    if command -v ufw >/dev/null 2>&1; then
        local ufw_status=$(ufw status | head -1)
        log_info "UFW: $ufw_status"
        
        if ufw status | grep -q "Status: active"; then
            if ufw status | grep -q "10000"; then
                log_success "Puerto Webmin permitido en UFW"
            else
                log_warning "Puerto Webmin NO permitido en UFW"
                add_solution "Permitir Webmin: ufw allow 10000"
            fi
        fi
    fi
    
    # iptables
    if iptables -L 2>/dev/null | grep -q "10000"; then
        log_success "Puerto Webmin en iptables: OK"
    else
        log_info "Puerto Webmin no configurado en iptables"
    fi
    
    echo ""
}

# 10. VERIFICAR LOGS DE ERROR
check_error_logs() {
    log_info "=== VERIFICANDO LOGS DE ERROR ==="
    
    # Webmin logs
    if [[ -f "/var/webmin/miniserv.error" ]]; then
        local errors=$(tail -20 /var/webmin/miniserv.error | grep -i error | wc -l)
        if [[ $errors -gt 0 ]]; then
            log_warning "Errores en log Webmin: $errors en las últimas 20 líneas"
            log_info "Ver: tail /var/webmin/miniserv.error"
        else
            log_success "Sin errores recientes en Webmin"
        fi
    fi
    
    # System logs
    local recent_errors=$(journalctl --since "1 hour ago" --priority=err | grep -i webmin | wc -l)
    if [[ $recent_errors -gt 0 ]]; then
        log_warning "Errores de sistema relacionados con Webmin: $recent_errors"
        log_info "Ver: journalctl --since '1 hour ago' --priority=err | grep -i webmin"
    else
        log_success "Sin errores de sistema recientes"
    fi
    
    echo ""
}

# 11. VERIFICAR ACCESO WEB
check_web_access() {
    log_info "=== VERIFICANDO ACCESO WEB ==="
    
    # HTTP
    if curl -s --connect-timeout 5 "http://localhost:10000" >/dev/null 2>&1; then
        log_success "Acceso HTTP a Webmin: OK"
    else
        log_error "No se puede acceder a Webmin por HTTP"
        add_solution "Verificar servicio Webmin y configuración"
    fi
    
    # HTTPS
    if curl -k -s --connect-timeout 5 "https://localhost:10000" >/dev/null 2>&1; then
        log_success "Acceso HTTPS a Webmin: OK"
    else
        log_warning "No se puede acceder a Webmin por HTTPS"
        add_solution "Verificar certificados SSL de Webmin"
    fi
    
    echo ""
}

# 12. VERIFICAR DEPENDENCIAS
check_dependencies() {
    log_info "=== VERIFICANDO DEPENDENCIAS ==="
    
    local deps=("perl" "openssl" "python3" "curl" "wget" "unzip")
    
    for dep in "${deps[@]}"; do
        if command -v "$dep" >/dev/null 2>&1; then
            log_success "Dependencia $dep: OK"
        else
            log_error "Dependencia $dep: FALTANTE"
            add_solution "Instalar $dep: apt install -y $dep"
        fi
    done
    
    # Módulos Perl críticos
    local perl_modules=("Net::SSLeay" "IO::Socket::SSL")
    for module in "${perl_modules[@]}"; do
        if perl -M"$module" -e 1 2>/dev/null; then
            log_success "Módulo Perl $module: OK"
        else
            log_error "Módulo Perl $module: FALTANTE"
            add_solution "Instalar módulo: apt install -y lib$(echo $module | tr '[:upper:]' '[:lower:]' | tr '::' '-')-perl"
        fi
    done
    
    echo ""
}

# GENERAR REPORTE
generate_report() {
    echo -e "${PURPLE}============================================${NC}"
    echo -e "${PURPLE}           RESUMEN DEL DIAGNÓSTICO         ${NC}"
    echo -e "${PURPLE}============================================${NC}"
    echo ""
    
    if [[ ${#PROBLEMS_FOUND[@]} -eq 0 ]]; then
        log_success "¡NO SE ENCONTRARON PROBLEMAS CRÍTICOS!"
    else
        log_error "PROBLEMAS ENCONTRADOS: ${#PROBLEMS_FOUND[@]}"
        echo ""
        log_info "LISTA DE PROBLEMAS:"
        for i in "${!PROBLEMS_FOUND[@]}"; do
            echo -e "${RED}  $((i+1)). ${PROBLEMS_FOUND[$i]}${NC}"
        done
    fi
    
    echo ""
    if [[ ${#SOLUTIONS[@]} -gt 0 ]]; then
        log_info "SOLUCIONES RECOMENDADAS:"
        for i in "${!SOLUTIONS[@]}"; do
            echo -e "${YELLOW}  $((i+1)). ${SOLUTIONS[$i]}${NC}"
        done
    fi
    
    echo ""
    log_info "Log completo guardado en: $LOG_FILE"
    echo ""
    
    # Script de reparación automática
    echo -e "${BLUE}Para reparar automáticamente:${NC}"
    echo "./sub_agente_especialista_codigo.sh repair"
    echo ""
}

# FUNCIÓN PRINCIPAL
main() {
    log_message "Iniciando diagnóstico completo..."
    
    check_system_info
    check_permissions
    check_network
    check_repositories
    check_webmin_installation
    check_virtualmin_installation
    check_services
    check_ports
    check_firewall
    check_error_logs
    check_web_access
    check_dependencies
    
    generate_report
}

# EJECUTAR DIAGNÓSTICO
main
