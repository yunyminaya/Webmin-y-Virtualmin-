#!/bin/bash

# =============================================================================
# REVISIÓN COMPLETA DEL SISTEMA WEBMIN Y VIRTUALMIN
# Script de diagnóstico sin permisos de root
# =============================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[PASO]${NC} $1"
}

# Función para detectar sistema operativo
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        DISTRO="macos"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS="linux"
        DISTRO="$ID"
    elif [[ -f /etc/redhat-release ]]; then
        OS="linux"
        if grep -q "CentOS" /etc/redhat-release; then
            DISTRO="centos"
        elif grep -q "Red Hat" /etc/redhat-release; then
            DISTRO="rhel"
        elif grep -q "Fedora" /etc/redhat-release; then
            DISTRO="fedora"
        fi
    elif [[ -f /etc/debian_version ]]; then
        OS="linux"
        DISTRO="debian"
    else
        OS="unknown"
        DISTRO="unknown"
    fi
    
    export OS DISTRO
}

# Función para verificar scripts disponibles
check_available_scripts() {
    log_step "Verificando scripts disponibles..."
    
    local scripts=(
        "instalacion_completa_automatica.sh"
        "instalacion_unificada.sh"
        "verificacion_final_autonomo.sh"
        "verificar_actualizaciones.sh"
        "monitoreo_sistema.sh"
        "test_instalacion_completa.sh"
        "revision_funciones_webmin.sh"
        "verificar_postfix_webmin.sh"
        "webmin_postfix_check.sh"
        "virtualmin_postfix_check.sh"
        "postfix_validation_functions.sh"
        "integrar_validaciones_postfix.sh"
        "corregir_error_postfix.sh"
        "corregir_advertencias.sh"
    )
    
    local available_count=0
    local total_count=${#scripts[@]}
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            if [[ -x "$script" ]]; then
                log_success "✅ $script (ejecutable)"
            else
                log_warning "⚠️  $script (no ejecutable)"
            fi
            ((available_count++))
        else
            log_error "❌ $script (no encontrado)"
        fi
    done
    
    echo
    log_info "Scripts disponibles: $available_count/$total_count"
}

# Función para verificar archivos de configuración
check_config_files() {
    log_step "Verificando archivos de configuración..."
    
    local config_files=(
        "README.md"
        "CHANGELOG.md"
        "GUIA_INSTALACION_UNIFICADA.md"
        "INSTALACION_UN_COMANDO.md"
        "INSTRUCCIONES_RAPIDAS.md"
        "INTEGRACION_PANELES.md"
        "POSTFIX_INTEGRATION_README.md"
        "REPORTE_REVISION_FUNCIONES.md"
        "SERVICIOS_PREMIUM_INCLUIDOS.md"
        "SOLUCION_SERVIDORES_VIRTUALES.md"
    )
    
    local found_count=0
    
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_success "✅ $file"
            ((found_count++))
        else
            log_warning "⚠️  $file (no encontrado)"
        fi
    done
    
    echo
    log_info "Archivos de documentación: $found_count/${#config_files[@]}"
}

# Función para verificar directorios de temas
check_theme_directories() {
    log_step "Verificando directorios de temas..."
    
    local theme_dirs=(
        "authentic-theme-master"
        "virtualmin-gpl-master"
    )
    
    for dir in "${theme_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local file_count=$(find "$dir" -type f | wc -l | tr -d ' ')
            log_success "✅ $dir ($file_count archivos)"
        else
            log_warning "⚠️  $dir (no encontrado)"
        fi
    done
}

# Función para verificar estado de Postfix
check_postfix_status() {
    log_step "Verificando estado de Postfix..."
    
    # Incluir funciones de validación si están disponibles
    if [[ -f "postfix_validation_functions.sh" ]]; then
        source "./postfix_validation_functions.sh"
        
        if is_postfix_installed; then
            log_success "✅ Postfix está instalado"
            log_info "📋 Versión: $(get_postfix_version)"
            
            # Verificar parámetros críticos
            local params=("queue_directory" "command_directory" "daemon_directory")
            for param in "${params[@]}"; do
                if get_postfix_parameter "$param" >/dev/null 2>&1; then
                    log_success "✅ $param: $(get_postfix_parameter "$param")"
                else
                    log_warning "⚠️  $param: No disponible"
                fi
            done
        else
            log_warning "⚠️  Postfix no está instalado o no está disponible"
        fi
    else
        # Verificación básica sin funciones de validación
        if command -v postconf >/dev/null 2>&1; then
            log_success "✅ Postfix está disponible"
            local version=$(postconf mail_version 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
            log_info "📋 Versión: $version"
        else
            log_warning "⚠️  Postfix no está disponible en PATH"
        fi
    fi
}

# Función para verificar puertos comunes
check_common_ports() {
    log_step "Verificando puertos comunes..."
    
    local ports=("10000:Webmin" "20000:Usermin" "80:HTTP" "443:HTTPS" "25:SMTP" "587:SMTP-TLS" "993:IMAPS" "995:POP3S")
    
    for port_info in "${ports[@]}"; do
        local port=$(echo "$port_info" | cut -d':' -f1)
        local service=$(echo "$port_info" | cut -d':' -f2)
        
        if netstat -ln 2>/dev/null | grep -q ":$port " || ss -ln 2>/dev/null | grep -q ":$port "; then
            log_success "✅ Puerto $port ($service) está en uso"
        else
            log_info "ℹ️  Puerto $port ($service) no está en uso"
        fi
    done
}

# Función para verificar servicios del sistema
check_system_services() {
    log_step "Verificando servicios del sistema..."
    
    detect_os
    
    local services=("webmin" "postfix" "apache2" "httpd" "nginx" "mysql" "mariadb" "postgresql")
    
    case "$OS" in
        "linux")
            for service in "${services[@]}"; do
                if systemctl is-active "$service" >/dev/null 2>&1; then
                    log_success "✅ $service está activo"
                elif systemctl is-enabled "$service" >/dev/null 2>&1; then
                    log_warning "⚠️  $service está habilitado pero no activo"
                else
                    log_info "ℹ️  $service no está disponible o no está habilitado"
                fi
            done
            ;;
        "macos")
            # Verificar servicios específicos de macOS
            if launchctl list | grep -q "org.postfix.master"; then
                log_success "✅ Postfix está activo en macOS"
            else
                log_info "ℹ️  Postfix no está activo en macOS"
            fi
            
            if launchctl list | grep -q "webmin"; then
                log_success "✅ Webmin está activo en macOS"
            else
                log_info "ℹ️  Webmin no está activo en macOS"
            fi
            ;;
        *)
            log_warning "⚠️  No se puede verificar servicios en sistema: $OS"
            ;;
    esac
}

# Función para verificar conectividad de red
check_network_connectivity() {
    log_step "Verificando conectividad de red..."
    
    local test_hosts=("google.com" "github.com" "download.webmin.com")
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 "$host" >/dev/null 2>&1; then
            log_success "✅ Conectividad a $host"
        else
            log_warning "⚠️  No hay conectividad a $host"
        fi
    done
}

# Función para verificar espacio en disco
check_disk_space() {
    log_step "Verificando espacio en disco..."
    
    local current_dir=$(pwd)
    local available_space
    
    if [[ "$OS" == "macos" ]]; then
        available_space=$(df -h "$current_dir" | tail -1 | awk '{print $4}')
    else
        available_space=$(df -h "$current_dir" | tail -1 | awk '{print $4}')
    fi
    
    log_info "💾 Espacio disponible en directorio actual: $available_space"
    
    # Verificar si hay suficiente espacio (al menos 1GB)
    local available_mb
    if [[ "$available_space" =~ ([0-9]+)G ]]; then
        available_mb=$((${BASH_REMATCH[1]} * 1024))
    elif [[ "$available_space" =~ ([0-9]+)M ]]; then
        available_mb=${BASH_REMATCH[1]}
    else
        available_mb=0
    fi
    
    if [[ $available_mb -gt 1024 ]]; then
        log_success "✅ Espacio suficiente para instalaciones"
    else
        log_warning "⚠️  Espacio limitado - considere liberar espacio"
    fi
}

# Función para generar reporte de estado
generate_status_report() {
    log_step "Generando reporte de estado..."
    
    local report_file="./revision_completa_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
═══════════════════════════════════════════════════════════════════════════════
REVISIÓN COMPLETA DEL SISTEMA WEBMIN Y VIRTUALMIN
Generado: $(date)
Sistema: $OS ($DISTRO)
Directorio: $(pwd)
═══════════════════════════════════════════════════════════════════════════════

ESTADO DE SCRIPTS:
EOF
    
    # Agregar información de scripts
    local scripts=("instalacion_completa_automatica.sh" "instalacion_unificada.sh" "verificacion_final_autonomo.sh")
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            if [[ -x "$script" ]]; then
                echo "✅ $script (ejecutable)" >> "$report_file"
            else
                echo "⚠️  $script (no ejecutable)" >> "$report_file"
            fi
        else
            echo "❌ $script (no encontrado)" >> "$report_file"
        fi
    done
    
    echo "" >> "$report_file"
    echo "ESTADO DE POSTFIX:" >> "$report_file"
    
    if command -v postconf >/dev/null 2>&1; then
        echo "✅ Postfix está disponible" >> "$report_file"
        postconf mail_version >> "$report_file" 2>/dev/null || echo "❌ Error al obtener versión" >> "$report_file"
    else
        echo "❌ Postfix no está disponible" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "RECOMENDACIONES:" >> "$report_file"
    echo "• Ejecutar scripts de verificación específicos" >> "$report_file"
    echo "• Revisar logs del sistema" >> "$report_file"
    echo "• Verificar configuraciones de red" >> "$report_file"
    
    log_success "Reporte generado: $report_file"
}

# Función para mostrar resumen final
show_final_summary() {
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CYAN}📋 RESUMEN DE REVISIÓN COMPLETA${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    
    echo -e "${GREEN}✅ Verificaciones completadas:${NC}"
    echo "   • Scripts disponibles"
    echo "   • Archivos de configuración"
    echo "   • Directorios de temas"
    echo "   • Estado de Postfix"
    echo "   • Puertos comunes"
    echo "   • Servicios del sistema"
    echo "   • Conectividad de red"
    echo "   • Espacio en disco"
    echo
    
    echo -e "${BLUE}🔧 Scripts principales disponibles:${NC}"
    local main_scripts=("instalacion_completa_automatica.sh" "verificar_postfix_webmin.sh" "revision_funciones_webmin.sh")
    for script in "${main_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            echo "   ✅ $script"
        else
            echo "   ❌ $script"
        fi
    done
    
    echo
    echo -e "${YELLOW}⚡ Comandos útiles:${NC}"
    echo "   • ./revision_funciones_webmin.sh - Revisar funciones"
    echo "   • ./verificar_postfix_webmin.sh - Verificar Postfix"
    echo "   • ./webmin_postfix_check.sh - Verificar Webmin"
    echo "   • ./virtualmin_postfix_check.sh - Verificar Virtualmin"
    echo
    
    echo -e "${PURPLE}📊 Estado del sistema:${NC}"
    echo "   • Sistema operativo: $OS ($DISTRO)"
    if command -v postconf >/dev/null 2>&1; then
        echo "   • Postfix: Disponible"
    else
        echo "   • Postfix: No disponible"
    fi
    
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
}

# Función principal
main() {
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CYAN}🔍 REVISIÓN COMPLETA DEL SISTEMA WEBMIN Y VIRTUALMIN${NC}"
    echo -e "${CYAN}   Diagnóstico sin permisos de root${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    
    # Detectar sistema operativo
    detect_os
    log_info "Sistema detectado: $OS ($DISTRO)"
    echo
    
    # Ejecutar verificaciones
    check_available_scripts
    echo
    
    check_config_files
    echo
    
    check_theme_directories
    echo
    
    check_postfix_status
    echo
    
    check_common_ports
    echo
    
    check_system_services
    echo
    
    check_network_connectivity
    echo
    
    check_disk_space
    echo
    
    # Generar reporte
    generate_status_report
    echo
    
    # Mostrar resumen
    show_final_summary
}

# Ejecutar función principal
main "$@"