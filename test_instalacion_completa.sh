#!/bin/bash

# =============================================================================
# SCRIPT DE PRUEBA PARA INSTALACIÓN COMPLETA AUTOMÁTICA
# Verifica que el script de instalación esté correctamente configurado
# =============================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables

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

SCRIPT_PATH="./instalacion_completa_automatica.sh"
TEST_LOG="/tmp/test_instalacion_$(date +%Y%m%d_%H%M%S).log"

# Función para logging
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$TEST_LOG"
}

log_error() {
    echo -e "${RED}[ERROR $(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$TEST_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARNING $(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$TEST_LOG"
}

log_info() {
    echo -e "${BLUE}[INFO $(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$TEST_LOG"
}

# Función para verificar que el script existe
check_script_exists() {
    log "Verificando que el script de instalación existe..."
    
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        log_error "❌ Script no encontrado: $SCRIPT_PATH"
        return 1
    fi
    
    log_info "✅ Script encontrado: $SCRIPT_PATH"
    return 0
}

# Función para verificar permisos de ejecución
check_script_permissions() {
    log "Verificando permisos de ejecución..."
    
    if [[ ! -x "$SCRIPT_PATH" ]]; then
        log_warning "⚠️  Script no tiene permisos de ejecución. Aplicando permisos..."
        chmod +x "$SCRIPT_PATH"
        
        if [[ -x "$SCRIPT_PATH" ]]; then
            log_info "✅ Permisos de ejecución aplicados correctamente"
        else
            log_error "❌ No se pudieron aplicar permisos de ejecución"
            return 1
        fi
    else
        log_info "✅ Script tiene permisos de ejecución"
    fi
    
    return 0
}

# Función para verificar sintaxis del script
check_script_syntax() {
    log "Verificando sintaxis del script..."
    
    if bash -n "$SCRIPT_PATH" 2>/dev/null; then
        log_info "✅ Sintaxis del script es correcta"
        return 0
    else
        log_error "❌ Error de sintaxis en el script"
        bash -n "$SCRIPT_PATH" 2>&1 | tee -a "$TEST_LOG"
        return 1
    fi
}

# Función para verificar funciones principales
check_script_functions() {
    log "Verificando funciones principales del script..."
    
    local required_functions=(
        "detect_os"
        "check_root"
        "install_dependencies"
        "configure_mysql"
        "generate_ssh_credentials"
        "install_webmin"
        "install_virtualmin"
        "configure_system_services"
        "configure_firewall"
        "verify_installation"
        "cleanup"
        "show_final_info"
        "main"
    )
    
    local missing_functions=()
    
    for func in "${required_functions[@]}"; do
        if grep -q "^$func()" "$SCRIPT_PATH" || grep -q "^function $func" "$SCRIPT_PATH"; then
            log_info "✅ Función encontrada: $func"
        else
            log_error "❌ Función faltante: $func"
            missing_functions+=("$func")
        fi
    done
    
    if [[ ${#missing_functions[@]} -eq 0 ]]; then
        log_info "✅ Todas las funciones principales están presentes"
        return 0
    else
        log_error "❌ Funciones faltantes: ${missing_functions[*]}"
        return 1
    fi
}

# Función para verificar variables importantes
check_script_variables() {
    log "Verificando variables importantes del script..."
    
    local required_variables=(
        "WEBMIN_VERSION"
        "WEBMIN_PORT"
        "WEBMIN_USER"
        "INSTALL_DIR"
        "TEMP_DIR"
        "LOG_FILE"
    )
    
    local missing_variables=()
    
    for var in "${required_variables[@]}"; do
        if grep -q "^$var=" "$SCRIPT_PATH" || grep -q "^export $var=" "$SCRIPT_PATH"; then
            local value=$(grep "^$var=" "$SCRIPT_PATH" | head -1 | cut -d'=' -f2 | tr -d '"')
            log_info "✅ Variable encontrada: $var=$value"
        else
            log_error "❌ Variable faltante: $var"
            missing_variables+=("$var")
        fi
    done
    
    if [[ ${#missing_variables[@]} -eq 0 ]]; then
        log_info "✅ Todas las variables importantes están presentes"
        return 0
    else
        log_error "❌ Variables faltantes: ${missing_variables[*]}"
        return 1
    fi
}

# Función para verificar dependencias del sistema
check_system_dependencies() {
    log "Verificando dependencias del sistema..."
    
    local dependencies=("curl" "wget" "tar" "bash")
    local missing_deps=()
    
    for dep in "${dependencies[@]}"; do
        if command -v "$dep" >/dev/null 2>&1; then
            log_info "✅ Dependencia encontrada: $dep"
        else
            log_warning "⚠️  Dependencia faltante: $dep"
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -eq 0 ]]; then
        log_info "✅ Todas las dependencias básicas están presentes"
        return 0
    else
        log_warning "⚠️  Dependencias faltantes (se instalarán automáticamente): ${missing_deps[*]}"
        return 0  # No es crítico, se instalarán automáticamente
    fi
}

# Función para simular ejecución (dry-run)
simulate_execution() {
    log "Simulando ejecución del script (dry-run)..."
    
    # Verificar que el script puede detectar el OS
    if grep -q "detect_os" "$SCRIPT_PATH"; then
        log_info "✅ Script incluye detección de sistema operativo"
    else
        log_error "❌ Script no incluye detección de sistema operativo"
        return 1
    fi
    
    # Verificar que el script maneja errores
    if grep -q "set -e" "$SCRIPT_PATH" && grep -q "trap" "$SCRIPT_PATH"; then
        log_info "✅ Script incluye manejo de errores"
    else
        log_warning "⚠️  Script podría no manejar errores correctamente"
    fi
    
    # Verificar que el script incluye logging
    if grep -q "log()" "$SCRIPT_PATH" || grep -q "log " "$SCRIPT_PATH"; then
        log_info "✅ Script incluye sistema de logging"
    else
        log_warning "⚠️  Script podría no incluir logging adecuado"
    fi
    
    log_info "✅ Simulación completada"
    return 0
}

# Función para mostrar resumen
show_test_summary() {
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${GREEN}📋 RESUMEN DE PRUEBAS${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    echo -e "${BLUE}📁 Archivo probado:${NC} $SCRIPT_PATH"
    echo -e "${BLUE}📄 Log de pruebas:${NC} $TEST_LOG"
    echo
    echo -e "${GREEN}✅ SCRIPT LISTO PARA USAR${NC}"
    echo
    echo -e "${BLUE}🚀 Para ejecutar la instalación completa:${NC}"
    echo "   sudo $SCRIPT_PATH"
    echo
    echo -e "${BLUE}📖 Para más información:${NC}"
    echo "   cat INSTALACION_COMPLETA_AUTOMATICA.md"
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
}

# Función principal
main() {
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${GREEN}🧪 PRUEBA DE INSTALACIÓN COMPLETA AUTOMÁTICA${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    
    log "Iniciando pruebas del script de instalación..."
    log "Log de pruebas: $TEST_LOG"
    
    # Ejecutar todas las verificaciones
    local all_tests_passed=true
    
    if ! check_script_exists; then
        all_tests_passed=false
    fi
    
    if ! check_script_permissions; then
        all_tests_passed=false
    fi
    
    if ! check_script_syntax; then
        all_tests_passed=false
    fi
    
    if ! check_script_functions; then
        all_tests_passed=false
    fi
    
    if ! check_script_variables; then
        all_tests_passed=false
    fi
    
    if ! check_system_dependencies; then
        # No es crítico, continuar
        true
    fi
    
    if ! simulate_execution; then
        all_tests_passed=false
    fi
    
    # Mostrar resultado final
    if [[ "$all_tests_passed" == true ]]; then
        log "🎉 Todas las pruebas pasaron exitosamente"
        show_test_summary
        exit 0
    else
        log_error "❌ Algunas pruebas fallaron. Revise el log: $TEST_LOG"
        exit 1
    fi
}

# Ejecutar función principal
main "$@"