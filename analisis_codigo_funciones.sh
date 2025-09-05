#!/bin/bash

# =============================================================================
# ANÁLISIS DE CÓDIGO - FUNCIONES DE WEBMIN Y VIRTUALMIN
# Script para revisar el código y detectar errores potenciales en las funciones
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
ANALYSIS_LOG="/tmp/analisis_codigo_$(date +%Y%m%d_%H%M%S).log"
ERROR_COUNT=0
WARNING_COUNT=0
SUCCESS_COUNT=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    echo -e "${PURPLE}[PASO $(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$ANALYSIS_LOG"
}

# Función para verificar sintaxis de bash
check_bash_syntax() {
    local script_file="$1"
    log_step "Verificando sintaxis de bash en: $(basename "$script_file")"
    
    if [[ -f "$script_file" ]]; then
        if bash -n "$script_file" 2>/dev/null; then
            log_success "Sintaxis correcta en $(basename "$script_file")"
        else
            log_error "Error de sintaxis en $(basename "$script_file")"
            bash -n "$script_file" 2>&1 | while read -r line; do
                log_error "  $line"
            done
        fi
    else
        log_warning "Archivo no encontrado: $script_file"
    fi
}

# Función para verificar variables no definidas
check_undefined_variables() {
    local script_file="$1"
    log_step "Verificando variables no definidas en: $(basename "$script_file")"
    
    if [[ -f "$script_file" ]]; then
        # Buscar variables que se usan pero no se definen
        local undefined_vars=$(grep -n '\$[A-Za-z_][A-Za-z0-9_]*' "$script_file" | \
                              grep -v '^[[:space:]]*#' | \
                              grep -v '\$[0-9]\|\$@\|\$\*\|\$#\|\$\?\|\$\$\|\$!' | \
                              sed 's/.*\$\([A-Za-z_][A-Za-z0-9_]*\).*/\1/' | \
                              sort -u)
        
        if [[ -n "$undefined_vars" ]]; then
            log_info "Variables encontradas en $(basename "$script_file"):"
            echo "$undefined_vars" | while read -r var; do
                if ! grep -q "^[[:space:]]*$var=\|^[[:space:]]*export[[:space:]]*$var=\|^[[:space:]]*local[[:space:]]*$var=" "$script_file"; then
                    # Verificar si es una variable de entorno común
                    case "$var" in
                        "HOME"|"USER"|"PATH"|"PWD"|"SHELL"|"TERM"|"LANG"|"LC_ALL")
                            log_info "  Variable de entorno: $var"
                            ;;
                        *)
                            log_warning "  Posible variable no definida: $var"
                            ;;
                    esac
                fi
            done
        else
            log_success "No se encontraron variables problemáticas en $(basename "$script_file")"
        fi
    fi
}

# Función para verificar comandos que pueden fallar
check_error_handling() {
    local script_file="$1"
    log_step "Verificando manejo de errores en: $(basename "$script_file")"
    
    if [[ -f "$script_file" ]]; then
        # Verificar si usa set -e
        if grep -q "^set -e" "$script_file"; then
            log_success "Usa 'set -e' para manejo de errores en $(basename "$script_file")"
        else
            log_warning "No usa 'set -e' en $(basename "$script_file")"
        fi
        
        # Verificar comandos peligrosos sin verificación
        local dangerous_commands=("rm -rf" "dd" "mkfs" "fdisk" "parted")
        
        for cmd in "${dangerous_commands[@]}"; do
            if grep -q "$cmd" "$script_file"; then
                log_warning "Comando peligroso encontrado: '$cmd' en $(basename "$script_file")"
            fi
        done
        
        # Verificar comandos de red sin timeout
        local network_commands=("wget" "curl" "git clone")
        
        for cmd in "${network_commands[@]}"; do
            if grep -q "$cmd" "$script_file"; then
                if ! grep -A1 -B1 "$cmd" "$script_file" | grep -q "timeout\|--timeout\|--connect-timeout"; then
                    log_warning "Comando de red sin timeout: '$cmd' en $(basename "$script_file")"
                fi
            fi
        done
    fi
}

# Función para verificar funciones definidas
check_function_definitions() {
    local script_file="$1"
    log_step "Verificando definiciones de funciones en: $(basename "$script_file")"
    
    if [[ -f "$script_file" ]]; then
        # Encontrar todas las funciones definidas
        local functions=$(grep -n '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*()' "$script_file" | \
                         sed 's/^[0-9]*:[[:space:]]*\([a-zA-Z_][a-zA-Z0-9_]*\)[[:space:]]*().*/\1/')
        
        if [[ -n "$functions" ]]; then
            log_info "Funciones encontradas en $(basename "$script_file"):"
            echo "$functions" | while read -r func; do
                log_info "  - $func()"
                
                # Verificar si la función tiene documentación
                local line_num=$(grep -n "^[[:space:]]*$func[[:space:]]*()" "$script_file" | cut -d: -f1)
                if [[ -n "$line_num" ]]; then
                    local prev_line=$((line_num - 1))
                    if sed -n "${prev_line}p" "$script_file" | grep -q "^[[:space:]]*#"; then
                        log_success "    Función documentada: $func"
                    else
                        log_warning "    Función sin documentación: $func"
                    fi
                fi
            done
        else
            log_info "No se encontraron funciones en $(basename "$script_file")"
        fi
    fi
}

# Función para verificar llamadas a funciones
check_function_calls() {
    local script_file="$1"
    log_step "Verificando llamadas a funciones en: $(basename "$script_file")"
    
    if [[ -f "$script_file" ]]; then
        # Encontrar funciones definidas
        local defined_functions=$(grep -o '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*()' "$script_file" | \
                                 sed 's/^[[:space:]]*\([a-zA-Z_][a-zA-Z0-9_]*\)[[:space:]]*().*/\1/')
        
        # Encontrar llamadas a funciones
        local function_calls=$(grep -o '[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*$\|[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*[^=]' "$script_file" | \
                              grep -v '^[[:space:]]*#' | \
                              sed 's/[[:space:]]*$//' | \
                              sort -u)
        
        if [[ -n "$function_calls" && -n "$defined_functions" ]]; then
            echo "$function_calls" | while read -r call; do
                if echo "$defined_functions" | grep -q "^$call$"; then
                    log_success "Llamada válida a función: $call"
                fi
            done
        fi
    fi
}

# Función para verificar dependencias de comandos
check_command_dependencies() {
    local script_file="$1"
    log_step "Verificando dependencias de comandos en: $(basename "$script_file")"
    
    if [[ -f "$script_file" ]]; then
        # Lista de comandos comunes que pueden no estar disponibles
        local commands=("wget" "curl" "git" "mysql" "apache2" "httpd" "systemctl" "service" "firewall-cmd" "ufw")
        
        for cmd in "${commands[@]}"; do
            if grep -q "\b$cmd\b" "$script_file"; then
                # Verificar si hay verificación de disponibilidad del comando
                if grep -q "command -v $cmd\|which $cmd\|type $cmd" "$script_file"; then
                    log_success "Comando verificado antes de uso: $cmd en $(basename "$script_file")"
                else
                    log_warning "Comando usado sin verificación: $cmd en $(basename "$script_file")"
                fi
            fi
        done
    fi
}

# Función para verificar rutas hardcodeadas
check_hardcoded_paths() {
    local script_file="$1"
    log_step "Verificando rutas hardcodeadas en: $(basename "$script_file")"
    
    if [[ -f "$script_file" ]]; then
        # Buscar rutas absolutas comunes
        local hardcoded_paths=$(grep -o '"/[^"]*"\|'"'/[^']*'" "$script_file" | sort -u)
        
        if [[ -n "$hardcoded_paths" ]]; then
            log_info "Rutas hardcodeadas encontradas en $(basename "$script_file"):"
            echo "$hardcoded_paths" | while read -r path; do
                # Filtrar rutas que son problemáticas
                case "$path" in
                    "/tmp/"*|"/var/log/"*|"/etc/"*|"/opt/"*|"/usr/"*)
                        log_info "  Ruta estándar: $path"
                        ;;
                    "/home/"*|"/Users/"*)
                        log_warning "  Ruta específica de usuario: $path"
                        ;;
                    *)
                        log_info "  Ruta encontrada: $path"
                        ;;
                esac
            done
        else
            log_success "No se encontraron rutas hardcodeadas problemáticas en $(basename "$script_file")"
        fi
    fi
}

# Función para verificar compatibilidad entre sistemas operativos
check_os_compatibility() {
    local script_file="$1"
    log_step "Verificando compatibilidad de SO en: $(basename "$script_file")"
    
    if [[ -f "$script_file" ]]; then
        # Verificar si detecta el sistema operativo
        if grep -q "uname\|/etc/os-release\|lsb_release" "$script_file"; then
            log_success "Detecta sistema operativo en $(basename "$script_file")"
        else
            log_warning "No detecta sistema operativo en $(basename "$script_file")"
        fi
        
        # Verificar comandos específicos de distribución
        local distro_commands=("apt-get" "yum" "dnf" "pacman" "zypper" "brew")
        local found_distros=()
        
        for cmd in "${distro_commands[@]}"; do
            if grep -q "\b$cmd\b" "$script_file"; then
                found_distros+=("$cmd")
            fi
        done
        
        if [[ ${#found_distros[@]} -gt 1 ]]; then
            log_success "Soporte multi-distribución en $(basename "$script_file"): ${found_distros[*]}"
        elif [[ ${#found_distros[@]} -eq 1 ]]; then
            log_warning "Soporte limitado a una distribución en $(basename "$script_file"): ${found_distros[0]}"
        else
            log_info "No se detectaron comandos específicos de distribución en $(basename "$script_file")"
        fi
    fi
}

# Función para verificar seguridad
check_security_issues() {
    local script_file="$1"
    log_step "Verificando problemas de seguridad en: $(basename "$script_file")"
    
    if [[ -f "$script_file" ]]; then
        # Verificar uso de sudo sin validación
        if grep -q "sudo" "$script_file"; then
            if grep -q "sudo -v\|sudo -n" "$script_file"; then
                log_success "Uso seguro de sudo en $(basename "$script_file")"
            else
                log_warning "Uso de sudo sin validación en $(basename "$script_file")"
            fi
        fi
        
        # Verificar descarga de archivos sin verificación
        if grep -q "wget\|curl" "$script_file"; then
            if grep -q "sha256sum\|md5sum\|gpg" "$script_file"; then
                log_success "Verificación de integridad de descargas en $(basename "$script_file")"
            else
                log_warning "Descargas sin verificación de integridad en $(basename "$script_file")"
            fi
        fi
        
        # Verificar contraseñas en texto plano
        if grep -i "password\|passwd" "$script_file" | grep -v "^[[:space:]]*#"; then
            log_warning "Posibles contraseñas en texto plano en $(basename "$script_file")"
        fi
        
        # Verificar permisos de archivos
        if grep -q "chmod 777\|chmod 666" "$script_file"; then
            log_error "Permisos inseguros (777/666) en $(basename "$script_file")"
        fi
    fi
}

# Función para analizar un script completo
analyze_script() {
    local script_file="$1"
    
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CYAN}📄 ANALIZANDO: $(basename "$script_file")${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    
    check_bash_syntax "$script_file"
    check_undefined_variables "$script_file"
    check_error_handling "$script_file"
    check_function_definitions "$script_file"
    check_function_calls "$script_file"
    check_command_dependencies "$script_file"
    check_hardcoded_paths "$script_file"
    check_os_compatibility "$script_file"
    check_security_issues "$script_file"
}

# Función para mostrar resumen del análisis
show_analysis_summary() {
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CYAN}📋 RESUMEN DEL ANÁLISIS DE CÓDIGO${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    echo -e "${GREEN}✅ Verificaciones exitosas: $SUCCESS_COUNT${NC}"
    echo -e "${YELLOW}⚠️  Advertencias: $WARNING_COUNT${NC}"
    echo -e "${RED}❌ Errores: $ERROR_COUNT${NC}"
    echo
    echo -e "${BLUE}📄 Log completo: $ANALYSIS_LOG${NC}"
    echo
    
    if [[ $ERROR_COUNT -eq 0 && $WARNING_COUNT -eq 0 ]]; then
        echo -e "${GREEN}🎉 CÓDIGO COMPLETAMENTE LIMPIO${NC}"
        echo "Todos los scripts están bien estructurados y sin errores detectados."
    elif [[ $ERROR_COUNT -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  CÓDIGO FUNCIONAL CON MEJORAS POSIBLES${NC}"
        echo "El código funciona pero hay algunas mejoras recomendadas."
    else
        echo -e "${RED}❌ CÓDIGO CON ERRORES${NC}"
        echo "Se encontraron errores que deben corregirse."
    fi
    
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
}

# Función principal
main() {
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CYAN}🔍 ANÁLISIS DE CÓDIGO - FUNCIONES DE WEBMIN Y VIRTUALMIN${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    
    log "Iniciando análisis de código..."
    log "Log de análisis: $ANALYSIS_LOG"
    log "Directorio de scripts: $SCRIPT_DIR"
    
    # Lista de scripts a analizar
    local scripts_to_analyze=(
        "$SCRIPT_DIR/instalacion_completa_automatica.sh"
        "$SCRIPT_DIR/instalacion_unificada.sh"
        "$SCRIPT_DIR/verificar_actualizaciones.sh"
        "$SCRIPT_DIR/monitoreo_sistema.sh"
        "$SCRIPT_DIR/test_instalacion_completa.sh"
    )
    
    # Analizar cada script
    for script in "${scripts_to_analyze[@]}"; do
        if [[ -f "$script" ]]; then
            analyze_script "$script"
        else
            log_warning "Script no encontrado: $(basename "$script")"
        fi
    done
    
    # Mostrar resumen
    show_analysis_summary
    
    log "Análisis de código completado"
    
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
