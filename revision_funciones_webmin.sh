#!/bin/bash

# =============================================================================
# REVISIÓN ESPECÍFICA DE FUNCIONES DE WEBMIN Y VIRTUALMIN
# Script para verificar funciones críticas sin errores
# =============================================================================

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Contadores
ERROR_COUNT=0
WARNING_COUNT=0
SUCCESS_COUNT=0

# Funciones de logging
log_error() {
    echo -e "${RED}❌ ERROR:${NC} $1"
    ((ERROR_COUNT++))
}

log_warning() {
    echo -e "${YELLOW}⚠️  WARNING:${NC} $1"
    ((WARNING_COUNT++))
}

log_success() {
    echo -e "${GREEN}✅ SUCCESS:${NC} $1"
    ((SUCCESS_COUNT++))
}

log_info() {
    echo -e "${BLUE}ℹ️  INFO:${NC} $1"
}

log_step() {
    echo -e "${PURPLE}🔍 VERIFICANDO:${NC} $1"
}

# Función para verificar sintaxis de un script
check_syntax() {
    local script="$1"
    local name="$(basename "$script")"
    
    if [[ -f "$script" ]]; then
        if bash -n "$script" 2>/dev/null; then
            log_success "Sintaxis correcta en $name"
        else
            log_error "Error de sintaxis en $name"
            bash -n "$script" 2>&1 | head -5
        fi
    else
        log_warning "Script no encontrado: $name"
    fi
}

# Función para verificar funciones específicas en un script
check_functions_in_script() {
    local script="$1"
    local name="$(basename "$script")"
    
    if [[ ! -f "$script" ]]; then
        log_warning "Script no encontrado: $name"
        return
    fi
    
    log_step "Funciones en $name"
    
    # Extraer funciones definidas
    local functions=$(grep -n '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*()' "$script" | \
                     sed 's/^[0-9]*:[[:space:]]*\([a-zA-Z_][a-zA-Z0-9_]*\)[[:space:]]*().*/\1/')
    
    if [[ -n "$functions" ]]; then
        local func_count=$(echo "$functions" | wc -l | tr -d ' ')
        log_info "Encontradas $func_count funciones en $name:"
        
        echo "$functions" | while read -r func; do
            if [[ -n "$func" ]]; then
                # Verificar si la función tiene contenido
                local func_content=$(sed -n "/^[[:space:]]*$func[[:space:]]*()[[:space:]]*{/,/^}/p" "$script")
                if [[ -n "$func_content" ]]; then
                    log_success "  ✓ $func() - Definida correctamente"
                else
                    log_warning "  ⚠ $func() - Posible definición incompleta"
                fi
            fi
        done
    else
        log_info "No se encontraron funciones en $name"
    fi
}

# Función para verificar variables críticas
check_critical_variables() {
    local script="$1"
    local name="$(basename "$script")"
    
    if [[ ! -f "$script" ]]; then
        return
    fi
    
    log_step "Variables críticas en $name"
    
    # Variables críticas para Webmin/Virtualmin
    local critical_vars=("WEBMIN_VERSION" "WEBMIN_PORT" "WEBMIN_USER" "WEBMIN_PASS")
    
    for var in "${critical_vars[@]}"; do
        if grep -q "^[[:space:]]*$var=\|^[[:space:]]*export[[:space:]]*$var=" "$script"; then
            log_success "  ✓ Variable $var definida"
        else
            log_info "  - Variable $var no encontrada (puede ser opcional)"
        fi
    done
}

# Función para verificar comandos peligrosos
check_dangerous_commands() {
    local script="$1"
    local name="$(basename "$script")"
    
    if [[ ! -f "$script" ]]; then
        return
    fi
    
    log_step "Comandos peligrosos en $name"
    
    local dangerous=("dd if=" "mkfs" "fdisk" "format")
    local found_dangerous=false
    
    for cmd in "${dangerous[@]}"; do
        if grep -q "$cmd" "$script"; then
            log_error "  ❌ Comando peligroso encontrado: $cmd"
            found_dangerous=true
        fi
    done
    
    if [[ "$found_dangerous" == false ]]; then
        log_success "  ✓ No se encontraron comandos peligrosos"
    fi
}

# Función para verificar manejo de errores
check_error_handling() {
    local script="$1"
    local name="$(basename "$script")"
    
    if [[ ! -f "$script" ]]; then
        return
    fi
    
    log_step "Manejo de errores en $name"
    
    # Verificar set -e
    if grep -q "^set -e" "$script"; then
        log_success "  ✓ Usa 'set -e' para manejo automático de errores"
    else
        log_warning "  ⚠ No usa 'set -e'"
    fi
    
    # Verificar trap
    if grep -q "trap" "$script"; then
        log_success "  ✓ Usa 'trap' para manejo de señales"
    else
        log_info "  - No usa 'trap' (puede ser opcional)"
    fi
    
    # Verificar verificaciones de comandos
    if grep -q "command -v\|which\|type" "$script"; then
        log_success "  ✓ Verifica disponibilidad de comandos"
    else
        log_warning "  ⚠ No verifica disponibilidad de comandos"
    fi
}

# Función para verificar compatibilidad de SO
check_os_compatibility() {
    local script="$1"
    local name="$(basename "$script")"
    
    if [[ ! -f "$script" ]]; then
        return
    fi
    
    log_step "Compatibilidad de SO en $name"
    
    # Verificar detección de SO
    if grep -q "uname\|/etc/os-release\|lsb_release" "$script"; then
        log_success "  ✓ Detecta sistema operativo"
    else
        log_warning "  ⚠ No detecta sistema operativo"
    fi
    
    # Verificar gestores de paquetes
    local package_managers=("apt-get" "yum" "dnf" "brew")
    local found_managers=()
    
    for pm in "${package_managers[@]}"; do
        if grep -q "\b$pm\b" "$script"; then
            found_managers+=("$pm")
        fi
    done
    
    if [[ ${#found_managers[@]} -gt 1 ]]; then
        log_success "  ✓ Soporte multi-plataforma: ${found_managers[*]}"
    elif [[ ${#found_managers[@]} -eq 1 ]]; then
        log_warning "  ⚠ Soporte limitado: ${found_managers[0]}"
    else
        log_info "  - No se detectaron gestores de paquetes específicos"
    fi
}

# Función para verificar funciones específicas de Webmin
check_webmin_functions() {
    local script="$1"
    local name="$(basename "$script")"
    
    if [[ ! -f "$script" ]]; then
        return
    fi
    
    log_step "Funciones específicas de Webmin en $name"
    
    # Funciones críticas de Webmin
    local webmin_functions=(
        "install_webmin"
        "configure_webmin"
        "start_webmin"
        "setup_webmin"
        "download_webmin"
    )
    
    for func in "${webmin_functions[@]}"; do
        if grep -q "^[[:space:]]*$func[[:space:]]*()" "$script"; then
            log_success "  ✓ Función $func() encontrada"
        else
            log_info "  - Función $func() no encontrada (puede estar en otro script)"
        fi
    done
}

# Función para verificar funciones específicas de Virtualmin
check_virtualmin_functions() {
    local script="$1"
    local name="$(basename "$script")"
    
    if [[ ! -f "$script" ]]; then
        return
    fi
    
    log_step "Funciones específicas de Virtualmin en $name"
    
    # Funciones críticas de Virtualmin
    local virtualmin_functions=(
        "install_virtualmin"
        "configure_virtualmin"
        "setup_virtualmin"
        "download_virtualmin"
    )
    
    for func in "${virtualmin_functions[@]}"; do
        if grep -q "^[[:space:]]*$func[[:space:]]*()" "$script"; then
            log_success "  ✓ Función $func() encontrada"
        else
            log_info "  - Función $func() no encontrada (puede estar en otro script)"
        fi
    done
}

# Función principal de análisis
analyze_script() {
    local script="$1"
    local name="$(basename "$script")"
    
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CYAN}📄 ANALIZANDO: $name${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    
    check_syntax "$script"
    check_functions_in_script "$script"
    check_critical_variables "$script"
    check_error_handling "$script"
    check_os_compatibility "$script"
    check_dangerous_commands "$script"
    check_webmin_functions "$script"
    check_virtualmin_functions "$script"
}

# Función para mostrar resumen
show_summary() {
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CYAN}📋 RESUMEN DE LA REVISIÓN${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    echo -e "${GREEN}✅ Verificaciones exitosas: $SUCCESS_COUNT${NC}"
    echo -e "${YELLOW}⚠️  Advertencias: $WARNING_COUNT${NC}"
    echo -e "${RED}❌ Errores: $ERROR_COUNT${NC}"
    echo
    
    if [[ $ERROR_COUNT -eq 0 && $WARNING_COUNT -eq 0 ]]; then
        echo -e "${GREEN}🎉 TODAS LAS FUNCIONES ESTÁN CORRECTAS${NC}"
        echo "No se encontraron errores en las funciones de Webmin y Virtualmin."
    elif [[ $ERROR_COUNT -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  FUNCIONES OPERATIVAS CON MEJORAS RECOMENDADAS${NC}"
        echo "Las funciones están funcionando pero hay mejoras recomendadas."
    else
        echo -e "${RED}❌ SE ENCONTRARON ERRORES${NC}"
        echo "Hay errores que deben corregirse para el funcionamiento óptimo."
    fi
    
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
}

# Función principal
main() {
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CYAN}🔍 REVISIÓN DE FUNCIONES DE WEBMIN Y VIRTUALMIN${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    
    # Scripts a analizar
    local scripts=(
        "./instalacion_completa_automatica.sh"
        "./instalacion_unificada.sh"
        "./verificar_actualizaciones.sh"
        "./monitoreo_sistema.sh"
        "./test_instalacion_completa.sh"
    )
    
    # Analizar cada script
    for script in "${scripts[@]}"; do
        analyze_script "$script"
    done
    
    # Mostrar resumen
    show_summary
    
    # Código de salida
    if [[ $ERROR_COUNT -gt 0 ]]; then
        exit 1
    elif [[ $WARNING_COUNT -gt 0 ]]; then
        exit 2
    else
        exit 0
    fi
}

# Ejecutar
main "$@"