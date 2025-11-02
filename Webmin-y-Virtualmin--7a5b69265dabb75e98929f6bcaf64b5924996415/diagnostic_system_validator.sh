#!/bin/bash

# Validador de Diagnóstico del Sistema Webmin/Virtualmin
# Detecta problemas reales mediante análisis sistemático

set -euo pipefail
IFS=$'\n\t'

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/diagnostic_validation.log"
REPORT_FILE="$SCRIPT_DIR/diagnostic_report.md"

# Funciones de logging
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" | tee -a "$LOG_FILE"
}

log_warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $*" | tee -a "$LOG_FILE"
}

# Validar sintaxis de scripts bash
validate_bash_syntax() {
    log_info "=== VALIDANDO SINTAXIS DE SCRIPTS BASH ==="
    
    local syntax_errors=0
    local total_scripts=0
    
    while IFS= read -r -d '' script; do
        if [[ "$script" == *.sh ]]; then
            total_scripts=$((total_scripts + 1))
            log_info "Verificando: $script"
            
            if bash -n "$script" 2>/dev/null; then
                log_success "✅ Sintaxis correcta: $script"
            else
                log_error "❌ Error de sintaxis en: $script"
                bash -n "$script" 2>&1 | tee -a "$LOG_FILE"
                syntax_errors=$((syntax_errors + 1))
            fi
        fi
    done < <(find "$SCRIPT_DIR" -name "*.sh" -print0 2>/dev/null)
    
    log_info "Total scripts analizados: $total_scripts"
    log_info "Errores de sintaxis encontrados: $syntax_errors"
    
    return $syntax_errors
}

# Detectar sistemas duplicados
detect_duplicate_systems() {
    log_info "=== DETECTANDO SISTEMAS DUPLICADOS ==="
    
    # Sistemas de monitoreo
    local monitoring_scripts=(
        "monitor_sistema.sh"
        "advanced_monitoring.sh"
        "monitor_sistema.sh"
        "webmin_virtualmin_monitor.sh"
        "enterprise_monitoring_setup.sh"
    )
    
    # Sistemas de backup
    local backup_scripts=(
        "auto_backup_system.sh"
        "intelligent_backup_system"
        "enterprise_backups"
    )
    
    # Sistemas de defensa
    local defense_scripts=(
        "ai_defense_system.sh"
        "ddos_shield_extreme.sh"
        "install_ai_protection.sh"
    )
    
    log_warning "SISTEMAS DE MONITOREO DUPLICADOS:"
    for script in "${monitoring_scripts[@]}"; do
        if [[ -f "$SCRIPT_DIR/$script" ]]; then
            log_warning "  📊 $script"
        fi
    done
    
    log_warning "SISTEMAS DE BACKUP DUPLICADOS:"
    for script in "${backup_scripts[@]}"; do
        if [[ -f "$SCRIPT_DIR/$script" || -d "$SCRIPT_DIR/$script" ]]; then
            log_warning "  💾 $script"
        fi
    done
    
    log_warning "SISTEMAS DE DEFENSA DUPLICADOS:"
    for script in "${defense_scripts[@]}"; do
        if [[ -f "$SCRIPT_DIR/$script" ]]; then
            log_warning "  🛡️ $script"
        fi
    done
}

# Validar conflictos de servicios systemd
validate_systemd_conflicts() {
    log_info "=== VALIDANDO CONFLICTOS DE SERVICIOS SYSTEMD ==="
    
    local services_found=()
    
    # Buscar servicios relacionados con monitoreo
    while IFS= read -r service; do
        if [[ -n "$service" ]]; then
            services_found+=("$service")
            log_info "Servicio encontrado: $service"
        fi
    done < <(find /etc/systemd/system -name "*monitoring*" -o -name "*backup*" -o -name "*defense*" 2>/dev/null)
    
    # Buscar servicios habilitados
    log_info "Servicios habilitados relacionados:"
    systemctl list-unit-files | grep -E "(monitoring|backup|defense)" | grep enabled | tee -a "$LOG_FILE" || true
    
    # Verificar servicios en ejecución
    log_info "Servicios en ejecución relacionados:"
    systemctl list-units --type=service --state=running | grep -E "(monitoring|backup|defense)" | tee -a "$LOG_FILE" || true
}

# Validar dependencias faltantes
validate_dependencies() {
    log_info "=== VALIDANDO DEPENDENCIAS FALTANTES ==="
    
    local required_commands=(
        "bash"
        "systemctl"
        "curl"
        "wget"
        "mysql"
        "sqlite3"
        "jq"
        "bc"
        "netstat"
        "top"
        "df"
        "free"
        "ps"
    )
    
    local missing_deps=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
            log_error "❌ Comando faltante: $cmd"
        else
            log_success "✅ Comando disponible: $cmd"
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Dependencias faltantes: ${missing_deps[*]}"
        return 1
    else
        log_success "Todas las dependencias básicas están disponibles"
        return 0
    fi
}

# Validar permisos de archivos
validate_file_permissions() {
    log_info "=== VALIDANDO PERMISOS DE ARCHIVOS ==="
    
    local permission_issues=0
    
    while IFS= read -r -d '' script; do
        if [[ "$script" == *.sh ]]; then
            if [[ ! -x "$script" ]]; then
                log_error "❌ Sin permisos de ejecución: $script"
                permission_issues=$((permission_issues + 1))
            else
                log_success "✅ Permisos correctos: $script"
            fi
        fi
    done < <(find "$SCRIPT_DIR" -name "*.sh" -print0 2>/dev/null)
    
    return $permission_issues
}

# Validar conflictos de rutas
validate_path_conflicts() {
    log_info "=== VALIDANDO CONFLICTOS DE RUTAS ==="
    
    local problematic_paths=(
        "/opt/enterprise_backups"
        "/var/lib/advanced_monitoring"
        "/etc/advanced_monitoring"
        "/var/log/advanced_monitoring"
        "/var/www/html/monitoring"
    )
    
    for path in "${problematic_paths[@]}"; do
        if [[ -e "$path" ]]; then
            log_info "📁 Ruta existente: $path"
            
            # Verificar permisos
            if [[ ! -r "$path" ]]; then
                log_error "❌ Sin permisos de lectura: $path"
            fi
            
            # Verificar espacio
            if [[ -d "$path" ]]; then
                local space_usage
                space_usage=$(du -sh "$path" 2>/dev/null | cut -f1 || echo "desconocido")
                log_info "   Espacio usado: $space_usage"
            fi
        else
            log_warning "⚠️  Ruta faltante: $path"
        fi
    done
}

# Validar integridad de configuración
validate_configuration_integrity() {
    log_info "=== VALIDANDO INTEGRIDAD DE CONFIGURACIÓN ==="
    
    local config_files=(
        "backup_config.conf"
        "backup_config.conf"
        "config.sh"
    )
    
    for config in "${config_files[@]}"; do
        if [[ -f "$SCRIPT_DIR/$config" ]]; then
            log_info "📄 Archivo de configuración encontrado: $config"
            
            # Verificar sintaxis si es un script
            if [[ "$config" == *.sh ]] && bash -n "$SCRIPT_DIR/$config" 2>/dev/null; then
                log_success "✅ Sintaxis correcta: $config"
            elif [[ "$config" == *.sh ]]; then
                log_error "❌ Error de sintaxis: $config"
            fi
        else
            log_warning "⚠️  Archivo de configuración faltante: $config"
        fi
    done
}

# Generar reporte final
generate_diagnostic_report() {
    log_info "=== GENERANDO REPORTE DE DIAGNÓSTICO ==="
    
    cat > "$REPORT_FILE" << EOF
# 📋 Reporte de Diagnóstico del Sistema Webmin/Virtualmin

**Fecha:** $(date)
**Sistema:** $(hostname)
**Versión:** $(uname -a)

## 🎯 Resumen Ejecutivo

Este reporte contiene el análisis completo de problemas detectados en el sistema Webmin/Virtualmin.

## 🔍 Problemas Detectados

### 1. Errores de Sintaxis
$(grep -c "ERROR.*Error de sintaxis" "$LOG_FILE" 2>/dev/null || echo "0") errores encontrados

### 2. Sistemas Duplicados
- **Monitoreo:** Múltiples scripts de monitoreo detectados
- **Backup:** Varios sistemas de backup concurrentes
- **Defensa:** Múltiples sistemas de defensa AI

### 3. Conflictos de Servicios
$(systemctl list-units --type=service --state=running | grep -E "(monitoring|backup|defense)" | wc -l) servicios en ejecución

### 4. Dependencias Faltantes
$(grep -c "Comando faltante" "$LOG_FILE" 2>/dev/null || echo "0") dependencias faltantes

### 5. Problemas de Permisos
$(grep -c "Sin permisos de ejecución" "$LOG_FILE" 2>/dev/null || echo "0") archivos sin permisos

## 📊 Métricas del Sistema

- **Total de scripts:** $(find "$SCRIPT_DIR" -name "*.sh" | wc -l)
- **Espacio en disco:** $(df -h / | tail -1 | awk '{print $4}')
- **Memoria disponible:** $(free -h | awk 'NR==2{print $7}')
- **Load average:** $(uptime | awk -F'load average:' '{print $2}')

## 🛠️ Recomendaciones

1. **Consolidar sistemas duplicados**
2. **Corregir errores de sintaxis**
3. **Instalar dependencias faltantes**
4. **Ajustar permisos de archivos**
5. **Optimizar configuración**

## 📝 Logs Completos

Ver archivo: \`$LOG_FILE\`

---

*Reporte generado automáticamente por el validador de diagnóstico*
EOF

    log_success "Reporte generado: $REPORT_FILE"
}

# Función principal
main() {
    echo "=========================================="
    echo "  🔍 VALIDADOR DE DIAGNÓSTICO"
    echo "  Webmin & Virtualmin System"
    echo "=========================================="
    echo
    
    # Crear archivo de log
    > "$LOG_FILE"
    
    # Ejecutar validaciones
    validate_bash_syntax
    detect_duplicate_systems
    validate_systemd_conflicts
    validate_dependencies
    validate_file_permissions
    validate_path_conflicts
    validate_configuration_integrity
    
    # Generar reporte
    generate_diagnostic_report
    
    echo
    echo "=========================================="
    echo "  ✅ DIAGNÓSTICO COMPLETADO"
    echo "=========================================="
    echo "Log detallado: $LOG_FILE"
    echo "Reporte: $REPORT_FILE"
    echo
    
    # Mostrar resumen
    local total_errors
    total_errors=$(grep -c "ERROR\|❌" "$LOG_FILE" 2>/dev/null || echo "0")
    local total_warnings
    total_warnings=$(grep -c "WARNING\|⚠️" "$LOG_FILE" 2>/dev/null || echo "0")
    
    echo "📊 Resumen:"
    echo "  Errores: $total_errors"
    echo "  Advertencias: $total_warnings"
    
    if [[ $total_errors -gt 0 ]]; then
        log_error "Se encontraron $total_errors errores que requieren atención"
        return 1
    else
        log_success "No se encontraron errores críticos"
        return 0
    fi
}

# Ejecutar función principal
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi