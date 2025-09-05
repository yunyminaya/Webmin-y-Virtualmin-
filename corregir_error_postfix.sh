#!/bin/bash

# =============================================================================
# CORRECCIÓN DE ERROR POSTFIX - COMANDO POSTCONF NO ENCONTRADO
# Script para corregir el error: /usr/sbin/postconf: not found
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

# Función para verificar si postconf existe
check_postconf_exists() {
    if command -v postconf >/dev/null 2>&1; then
        return 0
    elif [[ -x "/usr/sbin/postconf" ]]; then
        return 0
    elif [[ -x "/usr/bin/postconf" ]]; then
        return 0
    else
        return 1
    fi
}

# Función para obtener la ruta correcta de postconf
get_postconf_path() {
    if command -v postconf >/dev/null 2>&1; then
        command -v postconf
    elif [[ -x "/usr/sbin/postconf" ]]; then
        echo "/usr/sbin/postconf"
    elif [[ -x "/usr/bin/postconf" ]]; then
        echo "/usr/bin/postconf"
    else
        echo ""
    fi
}

# Función para generar código de validación de postconf
generate_postconf_validation() {
    cat << 'EOF'
# Función para verificar si postconf está disponible
check_postconf_available() {
    if command -v postconf >/dev/null 2>&1; then
        return 0
    elif [[ -x "/usr/sbin/postconf" ]]; then
        export PATH="$PATH:/usr/sbin"
        return 0
    elif [[ -x "/usr/bin/postconf" ]]; then
        export PATH="$PATH:/usr/bin"
        return 0
    else
        return 1
    fi
}

# Función para ejecutar postconf de forma segura
safe_postconf() {
    if check_postconf_available; then
        postconf "$@"
    else
        echo "ERROR: postconf no está disponible. Postfix no está instalado o no está en PATH." >&2
        return 1
    fi
}
EOF
}

# Función para corregir verificacion_final_autonomo.sh
correct_verificacion_final() {
    log_step "Corrigiendo verificacion_final_autonomo.sh..."
    
    local script="./verificacion_final_autonomo.sh"
    
    if [[ ! -f "$script" ]]; then
        log_warning "Script no encontrado: $script"
        return
    fi
    
    # Crear backup
    cp "$script" "${script}.backup"
    
    # Agregar funciones de validación si no existen
    if ! grep -q "check_postconf_available" "$script"; then
        # Encontrar línea después de las funciones de logging
        local insert_line=$(grep -n "log_step()" "$script" | tail -1 | cut -d: -f1)
        if [[ -n "$insert_line" ]]; then
            insert_line=$((insert_line + 4))
            
            # Crear archivo temporal
            local temp_file=$(mktemp)
            
            # Copiar hasta la línea de inserción
            head -n "$insert_line" "$script" > "$temp_file"
            
            # Agregar funciones de validación
            echo "" >> "$temp_file"
            generate_postconf_validation >> "$temp_file"
            echo "" >> "$temp_file"
            
            # Copiar el resto del archivo
            tail -n +$((insert_line + 1)) "$script" >> "$temp_file"
            
            # Reemplazar archivo original
            mv "$temp_file" "$script"
            
            log_success "Agregadas funciones de validación de postconf"
        else
            log_warning "No se pudo encontrar ubicación para insertar funciones"
        fi
    else
        log_info "Funciones de validación ya existen"
    fi
    
    # Reemplazar llamadas directas a postconf
    if grep -q "postconf mail_version" "$script"; then
        sed -i.bak 's/postconf mail_version/safe_postconf mail_version/g' "$script"
        log_success "Reemplazadas llamadas a postconf por safe_postconf"
    fi
    
    # Mejorar la verificación de Postfix
    if grep -q "if postconf mail_version" "$script"; then
        sed -i.bak2 's/if postconf mail_version >/if safe_postconf mail_version >/g' "$script"
        
        # Agregar verificación adicional
        local postfix_check_line=$(grep -n "Test de Postfix" "$script" | cut -d: -f1)
        if [[ -n "$postfix_check_line" ]]; then
            postfix_check_line=$((postfix_check_line + 2))
            
            # Crear nueva verificación
            local temp_file2=$(mktemp)
            head -n "$((postfix_check_line - 1))" "$script" > "$temp_file2"
            
            cat >> "$temp_file2" << 'EOF'
    # Verificar si Postfix está instalado
    if ! check_postconf_available; then
        log_warning "Postfix no está instalado o postconf no está disponible"
        log_info "Para instalar Postfix: sudo apt-get install postfix (Ubuntu/Debian) o sudo yum install postfix (CentOS/RHEL)"
        return
    fi
    
EOF
            
            tail -n +"$postfix_check_line" "$script" >> "$temp_file2"
            mv "$temp_file2" "$script"
            
            log_success "Mejorada verificación de instalación de Postfix"
        fi
    fi
}

# Función para corregir otros scripts que usen postconf
correct_other_scripts() {
    log_step "Buscando otros scripts que usen postconf..."
    
    local scripts_with_postconf=()
    
    # Buscar scripts que contengan postconf
    while IFS= read -r -d '' file; do
        if [[ "$file" == *.sh ]] && grep -q "postconf" "$file" 2>/dev/null; then
            scripts_with_postconf+=("$file")
        fi
    done < <(find . -name "*.sh" -type f -print0)
    
    for script in "${scripts_with_postconf[@]}"; do
        if [[ "$script" != "./verificacion_final_autonomo.sh" ]] && [[ "$script" != "./corregir_error_postfix.sh" ]]; then
            log_info "Corrigiendo $script..."
            
            # Crear backup
            cp "$script" "${script}.backup"
            
            # Agregar validación de postconf si no existe
            if ! grep -q "check_postconf_available" "$script"; then
                # Agregar al inicio del script después del shebang
                local temp_file=$(mktemp)
                head -n 1 "$script" > "$temp_file"
                echo "" >> "$temp_file"
                generate_postconf_validation >> "$temp_file"
                echo "" >> "$temp_file"
                tail -n +2 "$script" >> "$temp_file"
                mv "$temp_file" "$script"
            fi
            
            # Reemplazar llamadas directas a postconf
            sed -i.bak 's/postconf /safe_postconf /g' "$script"
            
            log_success "✓ Corregido $script"
        fi
    done
}

# Función para crear script de instalación de Postfix
create_postfix_installer() {
    log_step "Creando script de instalación de Postfix..."
    
    cat > "./instalar_postfix.sh" << 'EOF'
#!/bin/bash

# Script para instalar Postfix si no está disponible

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

# DUPLICADA: log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; } # Usar common_functions.sh
# DUPLICADA: log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; } # Usar common_functions.sh
# DUPLICADA: log_error() { echo -e "${RED}[ERROR]${NC} $1"; } # Usar common_functions.sh

# Detectar sistema operativo
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS="$ID"
    elif [[ -f /etc/redhat-release ]]; then
        if grep -q "CentOS" /etc/redhat-release; then
            OS="centos"
        elif grep -q "Red Hat" /etc/redhat-release; then
            OS="rhel"
        fi
    else
        OS="unknown"
    fi
}

# Instalar Postfix según el sistema operativo
install_postfix() {
    detect_os
    
    log_info "Detectado sistema operativo: $OS"
    
    case "$OS" in
        "ubuntu"|"debian")
            log_info "Instalando Postfix en Ubuntu/Debian..."
            sudo apt-get update
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y postfix
            ;;
        "centos"|"rhel"|"fedora")
            log_info "Instalando Postfix en CentOS/RHEL/Fedora..."
            sudo yum install -y postfix || sudo dnf install -y postfix
            ;;
        "macos")
            log_info "En macOS, Postfix viene preinstalado pero puede estar deshabilitado"
            log_info "Para habilitar Postfix en macOS:"
            echo "  sudo launchctl load -w /System/Library/LaunchDaemons/org.postfix.master.plist"
            ;;
        *)
            log_error "Sistema operativo no soportado: $OS"
            exit 1
            ;;
    esac
    
    # Verificar instalación
    if command -v postconf >/dev/null 2>&1; then
        log_success "Postfix instalado correctamente"
        postconf mail_version
    else
        log_error "Error al instalar Postfix"
        exit 1
    fi
}

# Verificar si Postfix ya está instalado
if command -v postconf >/dev/null 2>&1; then
    log_success "Postfix ya está instalado"
    postconf mail_version
else
    log_info "Postfix no está instalado. Procediendo con la instalación..."
    install_postfix
fi
EOF
    
    chmod +x "./instalar_postfix.sh"
    log_success "Creado script de instalación: ./instalar_postfix.sh"
}

# Función para verificar correcciones
verify_corrections() {
    log_step "Verificando correcciones aplicadas..."
    
    local all_good=true
    
    # Verificar verificacion_final_autonomo.sh
    if [[ -f "./verificacion_final_autonomo.sh" ]]; then
        if grep -q "check_postconf_available" "./verificacion_final_autonomo.sh" && 
           grep -q "safe_postconf" "./verificacion_final_autonomo.sh"; then
            log_success "✓ verificacion_final_autonomo.sh corregido"
        else
            log_warning "✗ verificacion_final_autonomo.sh no corregido completamente"
            all_good=false
        fi
    fi
    
    # Verificar que se creó el instalador de Postfix
    if [[ -f "./instalar_postfix.sh" ]]; then
        log_success "✓ Script de instalación de Postfix creado"
    else
        log_warning "✗ Script de instalación de Postfix no creado"
        all_good=false
    fi
    
    if [[ "$all_good" == true ]]; then
        log_success "🎉 Todas las correcciones aplicadas exitosamente"
        return 0
    else
        log_warning "⚠️ Algunas correcciones no se aplicaron correctamente"
        return 1
    fi
}

# Función para mostrar resumen de la corrección
show_summary() {
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CYAN}📋 RESUMEN DE CORRECCIONES APLICADAS${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    echo -e "${GREEN}✅ CORRECCIONES REALIZADAS:${NC}"
    echo "   • Agregadas funciones de validación de postconf"
    echo "   • Reemplazadas llamadas directas por safe_postconf"
    echo "   • Mejorada detección de Postfix no instalado"
    echo "   • Creado script de instalación automática"
    echo
    echo -e "${YELLOW}🔧 ARCHIVOS MODIFICADOS:${NC}"
    echo "   • verificacion_final_autonomo.sh (con backup)"
    echo "   • Otros scripts que usan postconf (con backup)"
    echo
    echo -e "${BLUE}📁 ARCHIVOS CREADOS:${NC}"
    echo "   • instalar_postfix.sh - Instalador automático de Postfix"
    echo
    echo -e "${PURPLE}🚀 PRÓXIMOS PASOS:${NC}"
    echo "   1. Si Postfix no está instalado, ejecutar: ./instalar_postfix.sh"
    echo "   2. Ejecutar verificación: ./verificacion_final_autonomo.sh"
    echo "   3. Los scripts ahora manejan correctamente la ausencia de Postfix"
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
}

# Función principal
main() {
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CYAN}🔧 CORRECCIÓN DE ERROR POSTFIX${NC}"
    echo -e "${CYAN}   Solucionando: /usr/sbin/postconf: not found${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    
    log_info "Iniciando corrección del error de Postfix..."
    echo
    
    # Verificar estado actual de postconf
    if check_postconf_exists; then
        local postconf_path=$(get_postconf_path)
        log_success "postconf encontrado en: $postconf_path"
    else
        log_warning "postconf no está disponible - aplicando correcciones preventivas"
    fi
    
    echo
    
    # Aplicar correcciones
    correct_verificacion_final
    correct_other_scripts
    create_postfix_installer
    
    echo
    
    # Verificar correcciones
    if verify_corrections; then
        show_summary
    else
        log_error "❌ Algunas correcciones fallaron"
        exit 1
    fi
}

# Ejecutar función principal
main "$@"
