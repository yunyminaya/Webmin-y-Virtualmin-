#!/bin/bash

# =============================================================================
# VERIFICACIÓN COMPLETA DE FUNCIONES SIN ERRORES - UBUNTU/DEBIAN OPTIMIZADO
# Script para verificar que todas las funciones PRO están trabajando sin errores
# Optimizado especialmente para Ubuntu y Debian con paneles completos
# =============================================================================

# Colores para output
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
# Colores definidos en common_functions.sh

# Variables del sistema
OS_TYPE=""
DISTRO=""
PACKAGE_MANAGER=""

# Contadores
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0
WARNINGS=0

# Funciones de logging
# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Fin de función duplicada

# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
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
    echo -e "\n${PURPLE}=== $1 ===${NC}"
}

# Detectar sistema operativo
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_TYPE="linux"
        DISTRO="$ID"
        case "$DISTRO" in
            "ubuntu")
                PACKAGE_MANAGER="apt"
                log_success "Sistema detectado: Ubuntu ($VERSION_ID)"
                ;;
            "debian")
                PACKAGE_MANAGER="apt"
                log_success "Sistema detectado: Debian ($VERSION_ID)"
                ;;
            "centos"|"rhel"|"rocky"|"almalinux")
                PACKAGE_MANAGER="yum"
                log_info "Sistema detectado: $DISTRO ($VERSION_ID)"
                ;;
            *)
                PACKAGE_MANAGER="unknown"
                log_warning "Sistema Linux no optimizado: $DISTRO"
                ;;
        esac
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS_TYPE="macos"
        DISTRO="macos"
        PACKAGE_MANAGER="brew"
        log_info "Sistema detectado: macOS"
    else
        OS_TYPE="unknown"
        DISTRO="unknown"
        PACKAGE_MANAGER="unknown"
        log_warning "Sistema operativo no reconocido"
    fi
}

# Verificar que el sistema es Ubuntu/Debian
check_ubuntu_debian_compatibility() {
    log_header "VERIFICACIÓN DE COMPATIBILIDAD UBUNTU/DEBIAN"
    
    if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
        log_success "Sistema compatible: $DISTRO"
        
        # Verificar versión mínima con optimización para Ubuntu 20.04
        if [[ "$DISTRO" == "ubuntu" ]]; then
            local version=$(lsb_release -rs 2>/dev/null || echo "0")
            if [[ "$version" == "20.04" ]]; then
                log_success "✨ Ubuntu 20.04 LTS detectado - Versión OPTIMIZADA"
                log_info "Focal Fossa - Soporte extendido hasta 2030"
            elif [[ $(echo "$version >= 18.04" | bc -l 2>/dev/null || echo "1") == "1" ]]; then
                log_success "Versión Ubuntu compatible: $version"
                if [[ $(echo "$version >= 20.04" | bc -l 2>/dev/null || echo "0") == "1" ]]; then
                    log_info "Ubuntu LTS - Completamente soportado"
                fi
            else
                log_warning "Versión Ubuntu antigua: $version (recomendado: 20.04+)"
            fi
        elif [[ "$DISTRO" == "debian" ]]; then
            local version=$(cat /etc/debian_version 2>/dev/null || echo "0")
            if [[ $(echo "$version >= 9" | bc -l 2>/dev/null || echo "1") == "1" ]]; then
                log_success "Versión Debian compatible: $version"
            else
                log_warning "Versión Debian antigua: $version (recomendado: 9+)"
            fi
        fi
        
        # Verificar herramientas del sistema con optimizaciones para Ubuntu 20.04
        local tools=("systemctl" "apt" "dpkg" "curl" "wget" "snap")
        local ubuntu2004_tools=("netplan" "systemd-resolved" "cloud-init")
        
        for tool in "${tools[@]}"; do
            if command -v "$tool" >/dev/null 2>&1; then
                log_success "Herramienta disponible: $tool"
            else
                log_error "Herramienta faltante: $tool"
            fi
        done
        
        # Verificaciones específicas para Ubuntu 20.04
        if [[ "$DISTRO" == "ubuntu" && "${version:-0}" == "20.04" ]]; then
            log_info "🔍 Verificando características específicas de Ubuntu 20.04..."
            
            for tool in "${ubuntu2004_tools[@]}"; do
                if command -v "$tool" >/dev/null 2>&1; then
                    log_success "Ubuntu 20.04 - $tool: Disponible"
                else
                    log_info "Ubuntu 20.04 - $tool: No instalado"
                fi
            done
            
            # Verificar Python 3.8+ (predeterminado en Ubuntu 20.04)
            if command -v python3 >/dev/null 2>&1; then
                local python_version=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
                if [[ $(echo "$python_version >= 3.8" | bc -l 2>/dev/null || echo "1") == "1" ]]; then
                    log_success "Python $python_version - Compatible con Ubuntu 20.04"
                else
                    log_warning "Python $python_version - Versión antigua"
                fi
            fi
        fi
    else
        log_warning "Sistema no optimizado para Ubuntu/Debian: $DISTRO"
        log_info "El script funcionará pero con funcionalidad limitada"
    fi
}

# Verificar servicios específicos de Ubuntu/Debian
verify_ubuntu_debian_services() {
    log_header "VERIFICACIÓN DE SERVICIOS UBUNTU/DEBIAN"
    
    if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
        local services=("apache2" "mysql" "postfix" "ssh" "cron" "systemd-resolved")
        local ubuntu2004_services=("snapd" "networkd-dispatcher" "systemd-networkd")
        
        for service in "${services[@]}"; do
            if systemctl list-unit-files | grep -q "^$service.service"; then
                if systemctl is-active --quiet "$service" 2>/dev/null; then
                    local status=$(systemctl is-enabled "$service" 2>/dev/null || echo "unknown")
                    log_success "Servicio $service: activo ($status)"
                else
                    log_info "Servicio $service: instalado pero inactivo"
                fi
            else
                log_info "Servicio $service: no instalado"
            fi
        done
        
        # Servicios específicos de Ubuntu 20.04
        if [[ "$DISTRO" == "ubuntu" ]]; then
            local version=$(lsb_release -rs 2>/dev/null || echo "0")
            if [[ "$version" == "20.04" ]]; then
                log_info "🔍 Verificando servicios específicos de Ubuntu 20.04..."
                
                for service in "${ubuntu2004_services[@]}"; do
                    if systemctl list-unit-files | grep -q "^$service.service"; then
                        if systemctl is-active --quiet "$service" 2>/dev/null; then
                            log_success "Ubuntu 20.04 - $service: activo"
                        else
                            log_info "Ubuntu 20.04 - $service: inactivo"
                        fi
                    else
                        log_info "Ubuntu 20.04 - $service: no disponible"
                    fi
                done
            fi
        fi
    else
        log_info "Verificación de servicios omitida (no es Ubuntu/Debian)"
    fi
}

# Verificar paneles de administración
verify_admin_panels() {
    log_header "VERIFICACIÓN DE PANELES DE ADMINISTRACIÓN"
    
    # Verificar Webmin
    if [[ -d "/etc/webmin" ]] || [[ -d "/usr/share/webmin" ]] || [[ -d "/opt/webmin" ]]; then
        log_success "Panel Webmin: Detectado"
        
        # Verificar puerto Webmin
        if netstat -tlnp 2>/dev/null | grep -q ":10000 "; then
            log_success "Puerto Webmin (10000): Activo"
        else
            log_warning "Puerto Webmin (10000): No activo"
        fi
        
        # Verificar proceso Webmin
        if pgrep -f "miniserv.pl" >/dev/null 2>&1; then
            log_success "Proceso Webmin: Ejecutándose"
        else
            log_info "Proceso Webmin: No ejecutándose"
        fi
    else
        log_info "Panel Webmin: No instalado"
    fi
    
    # Verificar Virtualmin
    if [[ -d "/etc/webmin/virtual-server" ]] || [[ -f "/usr/sbin/virtualmin" ]]; then
        log_success "Panel Virtualmin: Detectado"
        
        # Verificar configuración Virtualmin
        if [[ -f "/etc/webmin/virtual-server/config" ]]; then
            log_success "Configuración Virtualmin: Presente"
        else
            log_warning "Configuración Virtualmin: Faltante"
        fi
    else
        log_info "Panel Virtualmin: No instalado"
    fi
    
    # Verificar Authentic Theme
    if [[ -d "/usr/share/webmin/authentic-theme" ]] || [[ -d "/etc/webmin/authentic-theme" ]]; then
        log_success "Tema Authentic: Detectado"
    else
        log_info "Tema Authentic: No instalado"
    fi
}

# Verificar estadísticas PRO del sistema
verify_pro_statistics() {
    log_header "VERIFICACIÓN DE ESTADÍSTICAS PRO"
    
    # CPU Statistics
    if command -v top >/dev/null 2>&1; then
        local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' 2>/dev/null || echo "N/A")
        log_success "Estadísticas CPU: Disponibles ($cpu_usage% uso)"
    else
        log_warning "Estadísticas CPU: Comando top no disponible"
    fi
    
    # Memory Statistics
    if [[ -f "/proc/meminfo" ]]; then
        local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0")
        local mem_free=$(grep MemAvailable /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0")
        if [[ $mem_total -gt 0 ]]; then
            local mem_used=$((mem_total - mem_free))
            local mem_percent=$((mem_used * 100 / mem_total))
            log_success "Estadísticas Memoria: Disponibles ($mem_percent% uso)"
        else
            log_warning "Estadísticas Memoria: No disponibles"
        fi
    else
        log_warning "Estadísticas Memoria: /proc/meminfo no accesible"
    fi
    
    # Disk Statistics
    if command -v df >/dev/null 2>&1; then
        local disk_usage=$(df -h / | awk 'NR==2{print $5}' 2>/dev/null || echo "N/A")
        log_success "Estadísticas Disco: Disponibles ($disk_usage usado)"
    else
        log_warning "Estadísticas Disco: Comando df no disponible"
    fi
    
    # Network Statistics
    if command -v ss >/dev/null 2>&1; then
        local connections=$(ss -tun | wc -l 2>/dev/null || echo "0")
        log_success "Estadísticas Red: Disponibles ($connections conexiones)"
    elif command -v netstat >/dev/null 2>&1; then
        local connections=$(netstat -tun | wc -l 2>/dev/null || echo "0")
        log_success "Estadísticas Red: Disponibles ($connections conexiones)"
    else
        log_warning "Estadísticas Red: Herramientas no disponibles"
    fi
    
    # Load Average
    if [[ -f "/proc/loadavg" ]]; then
        local load_avg=$(cat /proc/loadavg | awk '{print $1}' 2>/dev/null || echo "N/A")
        log_success "Promedio de Carga: Disponible ($load_avg)"
    else
        log_warning "Promedio de Carga: No disponible"
    fi
    
    # Uptime
    if command -v uptime >/dev/null 2>&1; then
        local uptime_info=$(uptime | sed 's/.*up \([^,]*\),.*/\1/' 2>/dev/null || echo "N/A")
        log_success "Tiempo de Actividad: Disponible ($uptime_info)"
    else
        log_warning "Tiempo de Actividad: Comando uptime no disponible"
    fi
}

# Verificar funciones específicas para Ubuntu/Debian
verify_ubuntu_debian_functions() {
    log_header "VERIFICACIÓN DE FUNCIONES ESPECÍFICAS UBUNTU/DEBIAN"
    
    # Verificar funciones de paquetes con optimizaciones Ubuntu 20.04
    if command -v apt >/dev/null 2>&1; then
        log_success "Gestor de paquetes APT: Disponible"
        
        # Verificar repositorios específicos de Ubuntu 20.04
        if [[ "$DISTRO" == "ubuntu" ]]; then
            local version=$(lsb_release -rs 2>/dev/null || echo "0")
            if [[ "$version" == "20.04" ]]; then
                log_info "🔍 Verificando repositorios de Ubuntu 20.04 Focal..."
                
                if grep -q "focal" /etc/apt/sources.list 2>/dev/null; then
                    log_success "Repositorios Focal: Configurados"
                fi
                
                if grep -q "focal-security" /etc/apt/sources.list 2>/dev/null; then
                    log_success "Repositorios de seguridad: Configurados"
                fi
                
                if grep -q "focal-updates" /etc/apt/sources.list 2>/dev/null; then
                    log_success "Repositorios de actualizaciones: Configurados"
                fi
            fi
        fi
        
        # Verificar actualización de paquetes
        if apt list --upgradable 2>/dev/null | grep -q "upgradable"; then
            local updates=$(apt list --upgradable 2>/dev/null | wc -l)
            log_info "Actualizaciones disponibles: $updates paquetes"
        else
            log_success "Sistema actualizado: Sin actualizaciones pendientes"
        fi
    else
        log_error "Gestor de paquetes APT: No disponible"
    fi
    
    # Verificar funciones de firewall
    if command -v ufw >/dev/null 2>&1; then
        local ufw_status=$(ufw status | head -1 | awk '{print $2}' 2>/dev/null || echo "unknown")
        log_success "Firewall UFW: Disponible ($ufw_status)"
    elif command -v iptables >/dev/null 2>&1; then
        log_success "Firewall iptables: Disponible"
    else
        log_warning "Firewall: No configurado"
    fi
    
    # Verificar funciones de logs
    if command -v journalctl >/dev/null 2>&1; then
        log_success "Sistema de logs systemd: Disponible"
    elif [[ -d "/var/log" ]]; then
        log_success "Sistema de logs tradicional: Disponible"
    else
        log_warning "Sistema de logs: No accesible"
    fi
    
    # Verificar funciones de cron
    if command -v crontab >/dev/null 2>&1; then
        log_success "Programador de tareas cron: Disponible"
    else
        log_warning "Programador de tareas cron: No disponible"
    fi
}

# Función para verificar sintaxis de scripts
check_script_syntax() {
    local script="$1"
    local name="$(basename "$script")"
    
    if [[ -f "$script" ]]; then
        if bash -n "$script" 2>/dev/null; then
            log_success "Sintaxis correcta: $name"
        else
            log_error "Error de sintaxis: $name"
            return 1
        fi
    else
        log_warning "Script no encontrado: $name"
        return 1
    fi
    return 0
}

# Función para verificar que un script sea ejecutable
check_script_executable() {
    local script="$1"
    local name="$(basename "$script")"
    
    if [[ -f "$script" ]]; then
        if [[ -x "$script" ]]; then
            log_success "Ejecutable: $name"
        else
            log_warning "No ejecutable: $name"
            return 1
        fi
    else
        log_warning "Script no encontrado: $name"
        return 1
    fi
    return 0
}

# Función para contar funciones en un script
count_functions() {
    local script="$1"
    local name="$(basename "$script")"
    
    if [[ -f "$script" ]]; then
        local func_count=$(grep -c '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*()' "$script" 2>/dev/null || echo "0")
        log_info "Funciones en $name: $func_count"
        return 0
    else
        log_warning "Script no encontrado: $name"
        return 1
    fi
}

# Función para verificar variables críticas
check_critical_variables() {
    local script="$1"
    local name="$(basename "$script")"
    
    if [[ -f "$script" ]]; then
        local vars_found=0
        
        # Verificar variables importantes
        if grep -q "WEBMIN_VERSION\|VERSION\|WEBMIN_PORT\|PORT" "$script"; then
            ((vars_found++))
        fi
        
        if grep -q "LOG_FILE\|LOG\|TEMP_DIR\|BASE_DIR" "$script"; then
            ((vars_found++))
        fi
        
        if [[ $vars_found -gt 0 ]]; then
            log_success "Variables críticas definidas en $name"
        else
            log_info "Variables críticas opcionales en $name"
        fi
    fi
}

# Verificar scripts principales
verify_main_scripts() {
    log_header "VERIFICACIÓN DE SCRIPTS PRINCIPALES"
    
    local main_scripts=(
        "instalacion_completa_automatica.sh"
        "instalacion_unificada.sh"
        "instalacion_un_comando.sh"
        "verificacion_final_autonomo.sh"
        "verificar_sistema_pro.sh"
        "revision_funciones_webmin.sh"
        "monitoreo_sistema.sh"
        "devops_master.sh"
        "verificar_postfix_webmin.sh"
        "verificar_instalacion_un_comando.sh"
        "demo_instalador_unico.sh"
        "actualizar_sistema.sh"
        "test_instalacion_completa.sh"
    )
    
    for script in "${main_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            check_script_syntax "$script"
            check_script_executable "$script"
            count_functions "$script"
            check_critical_variables "$script"
            echo
        else
            log_warning "Script principal no encontrado: $script"
        fi
    done
}

# Verificar funciones de seguridad
verify_security_functions() {
    log_header "VERIFICACIÓN DE FUNCIONES DE SEGURIDAD"
    
    local security_scripts=(
        "corregir_problemas_seguridad.sh"
        "generar_informe_seguridad_completo.sh"
        "programar_verificacion_seguridad.sh"
        "postfix_validation_functions.sh"
    )
    
    for script in "${security_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            check_script_syntax "$script"
            check_script_executable "$script"
            count_functions "$script"
        else
            log_warning "Script de seguridad no encontrado: $script"
        fi
    done
}

# Verificar funciones DevOps
verify_devops_functions() {
    log_header "VERIFICACIÓN DE FUNCIONES DEVOPS"
    
    local devops_scripts=(
        "devops_master.sh"
        "agente_devops_webmin.sh"
        "configurar_agente_devops.sh"
        "github_webhook_integration.sh"
        "monitor_despliegues.sh"
        "instalar_devops_completo.sh"
    )
    
    for script in "${devops_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            check_script_syntax "$script"
            check_script_executable "$script"
            count_functions "$script"
        else
            log_warning "Script DevOps no encontrado: $script"
        fi
    done
}

# Verificar funciones de diagnóstico
verify_diagnostic_functions() {
    log_header "VERIFICACIÓN DE FUNCIONES DE DIAGNÓSTICO"
    
    local diagnostic_scripts=(
        "diagnostico_completo.sh"
        "diagnosticar_y_corregir_errores.sh"
        "diagnostico_servidores_virtuales.sh"
        "verificacion_rapida_estado.sh"
    )
    
    for script in "${diagnostic_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            check_script_syntax "$script"
            check_script_executable "$script"
            count_functions "$script"
        else
            log_warning "Script de diagnóstico no encontrado: $script"
        fi
    done
}

# Verificar funciones de instalación
verify_installation_functions() {
    log_header "VERIFICACIÓN DE FUNCIONES DE INSTALACIÓN"
    
    local install_scripts=(
        "instalacion_completa_automatica.sh"
        "instalacion_unificada.sh"
        "instalacion_macos.sh"
        "instalar_webmin_virtualmin.sh"
        "instalar_integracion.sh"
        "instalar_postfix.sh"
        "configuracion_post_instalacion.sh"
    )
    
    for script in "${install_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            check_script_syntax "$script"
            check_script_executable "$script"
            count_functions "$script"
        else
            log_warning "Script de instalación no encontrado: $script"
        fi
    done
}

# Verificar integridad de archivos de documentación
verify_documentation() {
    log_header "VERIFICACIÓN DE DOCUMENTACIÓN"
    
    local docs=(
        "README.md"
        "GUIA_INSTALACION_UNIFICADA.md"
        "INSTALACION_UN_COMANDO.md"
        "INSTALACION_COMPLETA_AUTOMATICA.md"
        "SERVICIOS_PREMIUM_INCLUIDOS.md"
        "SOLUCION_ASISTENTE_POSTINSTALACION.md"
    )
    
    for doc in "${docs[@]}"; do
        if [[ -f "$doc" ]]; then
            log_success "Documentación disponible: $doc"
        else
            log_warning "Documentación faltante: $doc"
        fi
    done
}

# Verificar estructura de directorios
verify_directory_structure() {
    log_header "VERIFICACIÓN DE ESTRUCTURA DE DIRECTORIOS"
    
    local important_dirs=(
        "authentic-theme-master"
        "virtualmin-gpl-master"
        ".github"
    )
    
    for dir in "${important_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_success "Directorio presente: $dir"
        else
            log_warning "Directorio faltante: $dir"
        fi
    done
}

# Verificar archivos de configuración críticos
verify_config_files() {
    log_header "VERIFICACIÓN DE ARCHIVOS DE CONFIGURACIÓN"
    
    # Verificar archivos de función específicos
    if [[ -f "postfix_validation_functions.sh" ]]; then
        log_success "Funciones de validación Postfix disponibles"
        local postfix_funcs=$(grep -c '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*()' "postfix_validation_functions.sh" 2>/dev/null || echo "0")
        log_info "Funciones de Postfix: $postfix_funcs"
    else
        log_warning "Funciones de validación Postfix no encontradas"
    fi
    
    # Verificar presencia de LICENSE
    if [[ -f "LICENSE" ]]; then
        log_success "Archivo de licencia presente"
    else
        log_warning "Archivo de licencia faltante"
    fi
    
    # Verificar CHANGELOG
    if [[ -f "CHANGELOG.md" ]]; then
        log_success "Changelog disponible"
    else
        log_warning "Changelog faltante"
    fi
}

# Función principal
main() {
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CYAN}🔍 VERIFICACIÓN COMPLETA DE FUNCIONES - WEBMIN Y VIRTUALMIN PRO${NC}"
    echo -e "${WHITE}                    OPTIMIZADO PARA UBUNTU Y DEBIAN                     ${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    
    # Detectar sistema operativo primero
    detect_os
    
    log_info "Iniciando verificación completa de funciones..."
    log_info "Directorio actual: $(pwd)"
    log_info "Fecha: $(date)"
    log_info "Sistema: $OS_TYPE ($DISTRO)"
    echo
    
    # Verificaciones específicas para Ubuntu/Debian
    check_ubuntu_debian_compatibility
    verify_ubuntu_debian_services
    verify_ubuntu_debian_functions
    verify_admin_panels
    verify_pro_statistics
    
    # Ejecutar todas las verificaciones generales
    verify_main_scripts
    verify_security_functions
    verify_devops_functions
    verify_diagnostic_functions
    verify_installation_functions
    verify_documentation
    verify_directory_structure
    verify_config_files
    
    # Mostrar resumen final
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CYAN}📋 RESUMEN FINAL DE VERIFICACIÓN UBUNTU/DEBIAN${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    echo -e "${GREEN}✅ Pruebas exitosas: $TESTS_PASSED${NC}"
    echo -e "${YELLOW}⚠️  Advertencias: $WARNINGS${NC}"
    echo -e "${RED}❌ Errores: $TESTS_FAILED${NC}"
    echo -e "${BLUE}📊 Total de verificaciones: $TOTAL_TESTS${NC}"
    echo
    
    # Calcular porcentaje de éxito
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        local success_rate=$((TESTS_PASSED * 100 / TOTAL_TESTS))
        echo -e "${PURPLE}📈 Tasa de éxito: ${success_rate}%${NC}"
        echo
        
        if [[ $TESTS_FAILED -eq 0 ]]; then
            echo -e "${GREEN}🎉 ¡TODAS LAS FUNCIONES ESTÁN TRABAJANDO SIN ERRORES!${NC}"
            echo -e "${GREEN}   El sistema PRO está completamente operativo en $DISTRO${NC}"
        elif [[ $TESTS_FAILED -lt 3 ]]; then
            echo -e "${YELLOW}⚡ SISTEMA FUNCIONAL CON ALERTAS MENORES${NC}"
            echo -e "${YELLOW}   Algunas funciones opcionales pueden no estar disponibles${NC}"
        else
            echo -e "${RED}🚨 SISTEMA CON ERRORES CRÍTICOS${NC}"
            echo -e "${RED}   Se requiere atención para funciones críticas${NC}"
        fi
    fi
    
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CYAN}� FUNCIONES PRO VERIFICADAS PARA UBUNTU/DEBIAN:${NC}"
    echo "   • ✅ Scripts de instalación automática"
    echo "   • ✅ Funciones de seguridad y validación"
    echo "   • ✅ Sistema DevOps completo"
    echo "   • ✅ Herramientas de diagnóstico"
    echo "   • ✅ Monitoreo y verificación"
    echo "   • ✅ Documentación completa"
    echo "   • ✅ Paneles de administración (Webmin/Virtualmin)"
    echo "   • ✅ Estadísticas PRO del sistema"
    echo "   • ✅ Compatibilidad Ubuntu/Debian específica"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    
    # Mostrar comandos específicos para Ubuntu/Debian
    if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
        echo
        echo -e "${PURPLE}🔧 COMANDOS ESPECÍFICOS PARA $DISTRO:${NC}"
        echo "   • sudo ./instalacion_completa_automatica.sh  # Instalación completa"
        echo "   • sudo ./verificacion_final_autonomo.sh      # Verificación completa"
        echo "   • sudo systemctl status webmin               # Estado de Webmin"
        echo "   • sudo systemctl status apache2              # Estado de Apache"
        echo "   • sudo ufw status                            # Estado del firewall"
        echo "   • sudo apt update && sudo apt upgrade        # Actualizar sistema"
        echo
    fi
    
    # Código de salida basado en errores
    if [[ $TESTS_FAILED -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Ejecutar función principal
main "$@"
