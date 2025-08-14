#!/bin/bash

# =============================================================================
# CORRECCIÓN DE ADVERTENCIAS MENORES
# Script para aplicar las mejoras recomendadas en la revisión de funciones
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

# DUPLICADA: Función reemplazada por common_functions.sh
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

log_step() {
    echo -e "${PURPLE}[PASO]${NC} $1"
}

# Función para detectar sistema operativo
get_os_detection_function() {
    cat << 'EOF'
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
EOF
}

# Función para corregir verificar_actualizaciones.sh
correct_verificar_actualizaciones() {
    log_step "Corrigiendo verificar_actualizaciones.sh..."
    
    local script="./verificar_actualizaciones.sh"
    
    if [[ ! -f "$script" ]]; then
        log_warning "Script no encontrado: $script"
        return
    fi
    
    # Crear backup
    cp "$script" "${script}.backup"
    
    # Agregar detección de OS después de las variables iniciales
    if ! grep -q "detect_os()" "$script"; then
        # Encontrar línea después de las variables de color
        local insert_line=$(grep -n "NC='" "$script" | tail -1 | cut -d: -f1)
        if [[ -n "$insert_line" ]]; then
            insert_line=$((insert_line + 2))
            
            # Crear archivo temporal con la función de detección
            local temp_file=$(mktemp)
            
            # Copiar hasta la línea de inserción
            head -n "$insert_line" "$script" > "$temp_file"
            
            # Agregar función de detección de OS
            echo "" >> "$temp_file"
            get_os_detection_function >> "$temp_file"
            echo "" >> "$temp_file"
            
            # Copiar el resto del archivo
            tail -n +$((insert_line + 1)) "$script" >> "$temp_file"
            
            # Reemplazar archivo original
            mv "$temp_file" "$script"
            
            log_success "Agregada función detect_os() a verificar_actualizaciones.sh"
        else
            log_warning "No se pudo encontrar ubicación para insertar función"
        fi
    else
        log_info "detect_os() ya existe en verificar_actualizaciones.sh"
    fi
}

# Función para corregir test_instalacion_completa.sh
correct_test_instalacion() {
    log_step "Corrigiendo test_instalacion_completa.sh..."
    
    local script="./test_instalacion_completa.sh"
    
    if [[ ! -f "$script" ]]; then
        log_warning "Script no encontrado: $script"
        return
    fi
    
    # Crear backup
    cp "$script" "${script}.backup"
    
    # Agregar detección de OS si no existe
    if ! grep -q "detect_os()" "$script"; then
        # Encontrar línea después de las variables de color
        local insert_line=$(grep -n "NC='" "$script" | tail -1 | cut -d: -f1)
        if [[ -n "$insert_line" ]]; then
            insert_line=$((insert_line + 2))
            
            # Crear archivo temporal
            local temp_file=$(mktemp)
            
            # Copiar hasta la línea de inserción
            head -n "$insert_line" "$script" > "$temp_file"
            
            # Agregar función de detección de OS
            echo "" >> "$temp_file"
            get_os_detection_function >> "$temp_file"
            echo "" >> "$temp_file"
            
            # Copiar el resto del archivo
            tail -n +$((insert_line + 1)) "$script" >> "$temp_file"
            
            # Reemplazar archivo original
            mv "$temp_file" "$script"
            
            log_success "Agregada función detect_os() a test_instalacion_completa.sh"
        else
            log_warning "No se pudo encontrar ubicación para insertar función"
        fi
    else
        log_info "detect_os() ya existe en test_instalacion_completa.sh"
    fi
}

# Función para corregir monitoreo_sistema.sh
correct_monitoreo_sistema() {
    log_step "Corrigiendo monitoreo_sistema.sh..."
    
    local script="./monitoreo_sistema.sh"
    
    if [[ ! -f "$script" ]]; then
        log_warning "Script no encontrado: $script"
        return
    fi
    
    # Crear backup
    cp "$script" "${script}.backup"
    
    # Agregar set -e si no existe
    if ! grep -q "^set -e" "$script"; then
        # Encontrar línea del shebang
        local shebang_line=$(grep -n "^#!/bin/bash" "$script" | head -1 | cut -d: -f1)
        if [[ -n "$shebang_line" ]]; then
            local insert_line=$((shebang_line + 1))
            
            # Crear archivo temporal
            local temp_file=$(mktemp)
            
            # Copiar hasta después del shebang
            head -n "$shebang_line" "$script" > "$temp_file"
            
            # Agregar set -e
            echo "" >> "$temp_file"
            echo "set -e" >> "$temp_file"
            echo "" >> "$temp_file"
            
            # Copiar el resto del archivo
            tail -n +$((insert_line)) "$script" >> "$temp_file"
            
            # Reemplazar archivo original
            mv "$temp_file" "$script"
            
            log_success "Agregado 'set -e' a monitoreo_sistema.sh"
        else
            log_warning "No se pudo encontrar shebang en monitoreo_sistema.sh"
        fi
    else
        log_info "'set -e' ya existe en monitoreo_sistema.sh"
    fi
}

# Función para verificar correcciones
verify_corrections() {
    log_step "Verificando correcciones aplicadas..."
    
    local all_good=true
    
    # Verificar verificar_actualizaciones.sh
    if [[ -f "./verificar_actualizaciones.sh" ]]; then
        if grep -q "detect_os()" "./verificar_actualizaciones.sh"; then
            log_success "✓ detect_os() agregada a verificar_actualizaciones.sh"
        else
            log_warning "✗ detect_os() no encontrada en verificar_actualizaciones.sh"
            all_good=false
        fi
    fi
    
    # Verificar test_instalacion_completa.sh
    if [[ -f "./test_instalacion_completa.sh" ]]; then
        if grep -q "detect_os()" "./test_instalacion_completa.sh"; then
            log_success "✓ detect_os() agregada a test_instalacion_completa.sh"
        else
            log_warning "✗ detect_os() no encontrada en test_instalacion_completa.sh"
            all_good=false
        fi
    fi
    
    # Verificar monitoreo_sistema.sh
    if [[ -f "./monitoreo_sistema.sh" ]]; then
        if grep -q "^set -e" "./monitoreo_sistema.sh"; then
            log_success "✓ 'set -e' agregado a monitoreo_sistema.sh"
        else
            log_warning "✗ 'set -e' no encontrado en monitoreo_sistema.sh"
            all_good=false
        fi
    fi
    
    if [[ "$all_good" == true ]]; then
        log_success "🎉 Todas las correcciones aplicadas exitosamente"
        return 0
    else
        log_warning "⚠️ Algunas correcciones no se aplicaron correctamente"
        return 1
    fi
}

# Función para ejecutar nueva revisión
run_final_check() {
    log_step "Ejecutando revisión final..."
    
    if [[ -f "./revision_funciones_webmin.sh" ]]; then
        echo
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo -e "${CYAN}🔍 REVISIÓN FINAL DESPUÉS DE CORRECCIONES${NC}"
        echo "═══════════════════════════════════════════════════════════════════════════════"
        
        ./revision_funciones_webmin.sh
    else
        log_warning "Script de revisión no encontrado"
    fi
}

# Función principal
main() {
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CYAN}🔧 CORRECCIÓN DE ADVERTENCIAS MENORES${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    
    log_info "Aplicando correcciones para optimizar el código..."
    echo
    
    # Aplicar correcciones
    correct_verificar_actualizaciones
    correct_test_instalacion
    correct_monitoreo_sistema
    
    echo
    
    # Verificar correcciones
    if verify_corrections; then
        echo
        log_success "🎉 Todas las advertencias han sido corregidas"
        echo
        
        # Ejecutar revisión final
        run_final_check
    else
        log_error "❌ Algunas correcciones fallaron"
        exit 1
    fi
}

# Ejecutar función principal
main "$@"
