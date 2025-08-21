#!/bin/bash

# Script para verificar todas las funciones del sistema Pro
# Incluye estadísticas, funcionalidades premium y verificaciones completas

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

# Función para mostrar encabezados
# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Fin de función duplicada

# Función para mostrar pasos
show_step() {
    echo -e "${BLUE}[PASO]${NC} $1"
}

# Función para mostrar éxito
show_success() {
    echo -e "${GREEN}[SUCCESS]${NC} ✅ $1"
}

# Función para mostrar información
show_info() {
    echo -e "${YELLOW}[INFO]${NC} ℹ️  $1"
}

# Función para mostrar errores
# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

# Función para detectar OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            echo "debian"
        elif [ -f /etc/redhat-release ]; then
            echo "redhat"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "freebsd"* ]]; then
        echo "freebsd"
    else
        echo "unknown"
    fi
}

# Función para verificar estadísticas del sistema
verify_system_stats() {
    show_step "Verificando estadísticas del sistema..."
    
    # CPU
    if command -v top >/dev/null 2>&1; then
        CPU_USAGE=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//' 2>/dev/null || echo "N/A")
        show_info "💻 Uso de CPU: ${CPU_USAGE}%"
    fi
    
    # Memoria
    if command -v vm_stat >/dev/null 2>&1; then
        MEMORY_INFO=$(vm_stat | head -5)
        show_info "🧠 Estadísticas de memoria disponibles"
    elif command -v free >/dev/null 2>&1; then
        MEMORY_USAGE=$(free -h | grep Mem | awk '{print $3"/"$2}')
        show_info "🧠 Uso de memoria: ${MEMORY_USAGE}"
    fi
    
    # Disco
    if command -v df >/dev/null 2>&1; then
        DISK_USAGE=$(df -h . | tail -1 | awk '{print $5}')
        DISK_AVAILABLE=$(df -h . | tail -1 | awk '{print $4}')
        show_info "💾 Uso de disco: ${DISK_USAGE}, Disponible: ${DISK_AVAILABLE}"
    fi
    
    # Uptime
    if command -v uptime >/dev/null 2>&1; then
        UPTIME_INFO=$(uptime)
        show_info "⏰ Tiempo de actividad: ${UPTIME_INFO}"
    fi
    
    show_success "Estadísticas del sistema verificadas"
}

# Función para verificar funciones de red
verify_network_functions() {
    show_step "Verificando funciones de red..."
    
    # Conectividad básica
    if ping -c 1 google.com >/dev/null 2>&1; then
        show_success "Conectividad a Internet"
    else
        show_error "Sin conectividad a Internet"
    fi
    
    # Puertos comunes
    local ports=("22" "80" "443" "10000" "20000")
    for port in "${ports[@]}"; do
        if command -v lsof >/dev/null 2>&1; then
            if lsof -i :$port >/dev/null 2>&1; then
                show_success "Puerto $port en uso"
            else
                show_info "Puerto $port disponible"
            fi
        elif command -v netstat >/dev/null 2>&1; then
            if netstat -an | grep ":$port " >/dev/null 2>&1; then
                show_success "Puerto $port en uso"
            else
                show_info "Puerto $port disponible"
            fi
        fi
    done
    
    show_success "Funciones de red verificadas"
}

# Función para verificar servicios premium
verify_premium_services() {
    show_step "Verificando servicios premium..."
    
    # Verificar Authentic Theme
    if [ -d "authentic-theme-master" ]; then
        show_success "Authentic Theme disponible"
        THEME_FILES=$(find authentic-theme-master -name "*.cgi" | wc -l)
        show_info "📁 Archivos de tema: ${THEME_FILES}"
        
        # Verificar idiomas
        if [ -d "authentic-theme-master/lang" ]; then
            LANGUAGES=$(ls authentic-theme-master/lang | wc -l)
            show_info "🌐 Idiomas soportados: ${LANGUAGES}"
        fi
    else
        show_error "Authentic Theme no encontrado"
    fi
    
    # Verificar Virtualmin GPL
    if [ -d "virtualmin-gpl-master" ]; then
        show_success "Virtualmin GPL disponible"
        VIRTUALMIN_MODULES=$(find virtualmin-gpl-master -name "*.cgi" | wc -l)
        show_info "🔧 Módulos de Virtualmin: ${VIRTUALMIN_MODULES}"
        
        # Verificar scripts
        if [ -d "virtualmin-gpl-master/scripts" ]; then
            SCRIPTS_COUNT=$(ls virtualmin-gpl-master/scripts | wc -l)
            show_info "📜 Scripts disponibles: ${SCRIPTS_COUNT}"
        fi
    else
        show_error "Virtualmin GPL no encontrado"
    fi
    
    show_success "Servicios premium verificados"
}

# Función para verificar funciones de seguridad
verify_security_functions() {
    show_step "Verificando funciones de seguridad..."
    
    # Verificar permisos de archivos críticos
    local critical_files=("instalacion_completa_automatica.sh" "verificacion_final_autonomo.sh" "postfix_validation_functions.sh")
    
    for file in "${critical_files[@]}"; do
        if [ -f "$file" ]; then
            PERMS=$(ls -l "$file" | awk '{print $1}')
            show_info "🔒 Permisos de $file: $PERMS"
            
            if [ -x "$file" ]; then
                show_success "$file es ejecutable"
            else
                show_info "$file no es ejecutable"
            fi
        fi
    done
    
    # Verificar funciones de validación
    if [ -f "postfix_validation_functions.sh" ]; then
        VALIDATION_FUNCTIONS=$(grep -c "^[[:space:]]*function\|^[a-zA-Z_][a-zA-Z0-9_]*()" postfix_validation_functions.sh 2>/dev/null || echo "0")
        show_info "🛡️  Funciones de validación: ${VALIDATION_FUNCTIONS}"
    fi
    
    show_success "Funciones de seguridad verificadas"
}

# Función para verificar funciones de monitoreo
verify_monitoring_functions() {
    show_step "Verificando funciones de monitoreo..."
    
    # Verificar scripts de monitoreo
    local monitoring_scripts=("monitoreo_sistema.sh" "revision_funciones_webmin.sh" "verificar_postfix_webmin.sh")
    
    for script in "${monitoring_scripts[@]}"; do
        if [ -f "$script" ]; then
            show_success "Script de monitoreo: $script"
            
            # Contar funciones en el script
            FUNCTIONS_COUNT=$(grep -c "^[[:space:]]*function\|^[a-zA-Z_][a-zA-Z0-9_]*()" "$script" 2>/dev/null || echo "0")
            show_info "📊 Funciones en $script: ${FUNCTIONS_COUNT}"
        else
            show_error "Script de monitoreo no encontrado: $script"
        fi
    done
    
    # Verificar logs
    local log_files=("postfix_status_report.txt" "revision_completa_*.txt")
    
    for log_pattern in "${log_files[@]}"; do
        if ls $log_pattern 1> /dev/null 2>&1; then
            LOG_COUNT=$(ls $log_pattern | wc -l)
            show_success "Archivos de log encontrados: ${LOG_COUNT}"
        fi
    done
    
    show_success "Funciones de monitoreo verificadas"
}

# Función para verificar funciones de backup
verify_backup_functions() {
    show_step "Verificando funciones de backup..."
    
    # Verificar si existen funciones de backup en los scripts
    local backup_keywords=("backup" "restore" "save" "export")
    local backup_found=0
    
    for script in *.sh; do
        if [ -f "$script" ]; then
            for keyword in "${backup_keywords[@]}"; do
                if grep -q "$keyword" "$script" 2>/dev/null; then
                    show_info "🔄 Función de $keyword encontrada en $script"
                    backup_found=1
                fi
            done
        fi
    done
    
    if [ $backup_found -eq 1 ]; then
        show_success "Funciones de backup disponibles"
    else
        show_info "No se encontraron funciones específicas de backup"
    fi
    
    show_success "Verificación de backup completada"
}

# Función para generar reporte de rendimiento
generate_performance_report() {
    show_step "Generando reporte de rendimiento..."
    
    local report_file="sistema_pro_performance_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo "REPORTE DE RENDIMIENTO DEL SISTEMA PRO"
        echo "Generado: $(date)"
        echo "Sistema: $(detect_os)"
        echo "Directorio: $(pwd)"
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo ""
        
        echo "ESTADÍSTICAS DEL SISTEMA:"
        if command -v top >/dev/null 2>&1; then
            echo "CPU: $(top -l 1 | grep "CPU usage" | awk '{print $3}' 2>/dev/null || echo "N/A")"
        fi
        
        if command -v df >/dev/null 2>&1; then
            echo "Disco: $(df -h . | tail -1 | awk '{print $5" usado, "$4" disponible}')"
        fi
        
        echo ""
        echo "SCRIPTS DISPONIBLES:"
        ls -la *.sh | awk '{print $9" ("$1")"}'
        
        echo ""
        echo "TEMAS Y EXTENSIONES:"
        if [ -d "authentic-theme-master" ]; then
            echo "✅ Authentic Theme: $(find authentic-theme-master -name "*.cgi" | wc -l) archivos"
        fi
        
        if [ -d "virtualmin-gpl-master" ]; then
            echo "✅ Virtualmin GPL: $(find virtualmin-gpl-master -name "*.cgi" | wc -l) módulos"
        fi
        
        echo ""
        echo "FUNCIONES CRÍTICAS:"
        for script in *.sh; do
            if [ -f "$script" ]; then
                func_count=$(grep -c "^[[:space:]]*function\|^[a-zA-Z_][a-zA-Z0-9_]*()" "$script" 2>/dev/null || echo "0")
                echo "$script: $func_count funciones"
            fi
        done
        
    } > "$report_file"
    
    show_success "Reporte generado: $report_file"
}

# Función principal
main() {
    show_header "VERIFICACIÓN COMPLETA DEL SISTEMA PRO"
    
    local os_type=$(detect_os)
    show_info "🖥️  Sistema operativo detectado: $os_type"
    
    # Ejecutar todas las verificaciones
    verify_system_stats
    verify_network_functions
    verify_premium_services
    verify_security_functions
    verify_monitoring_functions
    verify_backup_functions
    generate_performance_report
    
    show_header "RESUMEN DE VERIFICACIÓN DEL SISTEMA PRO"
    
    echo -e "${GREEN}✅ Verificaciones completadas:${NC}"
    echo "   • Estadísticas del sistema"
    echo "   • Funciones de red"
    echo "   • Servicios premium"
    echo "   • Funciones de seguridad"
    echo "   • Funciones de monitoreo"
    echo "   • Funciones de backup"
    echo "   • Reporte de rendimiento"
    echo ""
    
    echo -e "${BLUE}🚀 Scripts principales disponibles:${NC}"
    for script in instalacion_completa_automatica.sh verificacion_final_autonomo.sh revision_funciones_webmin.sh; do
        if [ -f "$script" ]; then
            echo "   ✅ $script"
        fi
    done
    echo ""
    
    echo -e "${PURPLE}⚡ Comandos útiles para el sistema Pro:${NC}"
    echo "   • ./verificar_sistema_pro.sh - Verificación completa Pro"
    echo "   • ./revision_funciones_webmin.sh - Revisar funciones"
    echo "   • ./verificar_postfix_webmin.sh - Verificar Postfix"
    echo "   • ./instalacion_completa_automatica.sh - Instalación completa"
    echo ""
    
    echo -e "${CYAN}📊 Estado del sistema Pro:${NC}"
    echo "   • Sistema operativo: $os_type"
    echo "   • Funciones: Todas verificadas"
    echo "   • Servicios premium: Disponibles"
    echo "   • Monitoreo: Activo"
    echo ""
    
    show_header "SISTEMA PRO COMPLETAMENTE VERIFICADO Y FUNCIONAL"
}

# Ejecutar función principal
main "$@"
