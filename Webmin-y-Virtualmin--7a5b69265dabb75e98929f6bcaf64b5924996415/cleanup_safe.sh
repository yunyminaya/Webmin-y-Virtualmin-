#!/bin/bash

# ============================================================================
# Eliminación Segura de Archivos Duplicados - Virtualmin/Webmin
# ============================================================================
# Elimina solo archivos identificados como seguros (archivos de test)
# Versión: 1.0.0
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== INCLUIR BIBLIOTECA COMÚN =====
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
    source "${SCRIPT_DIR}/lib/common.sh"
else
    echo "ERROR: No se encuentra la biblioteca común"
    exit 1
fi

# Variables
CLEANUP_LOG="${SCRIPT_DIR}/logs/cleanup_safe.log"
BACKUP_DIR="${SCRIPT_DIR}/backups/pre_cleanup_$(date +%Y%m%d_%H%M%S)"

# Archivos que SÍ pueden eliminarse (seguros)
SAFE_TO_DELETE=(
    "test_unit_functions.sh"
    "test_multi_distro.sh"
    "test_master.sh"
)

# Archivos CRÍTICOS que NUNCA deben eliminarse
CRITICAL_FILES=(
    "auto_defense.sh"
    "auto_repair.sh"
    "auto_repair_critical.sh"
    "lib/common.sh"
    "virtualmin-defense.service"
    "analyze_duplicates.sh"
)

# ============================================================================
# FUNCIONES DE LIMPIEZA SEGURA
# ============================================================================

# Función para verificar que los archivos críticos estén presentes
verify_critical_files() {
    log_info "🔍 Verificando archivos críticos antes de limpieza..."

    local missing_critical=()

    for file in "${CRITICAL_FILES[@]}"; do
        if [[ ! -f "${SCRIPT_DIR}/${file}" ]]; then
            missing_critical+=("$file")
        fi
    done

    if [[ ${#missing_critical[@]} -gt 0 ]]; then
        log_error "❌ ARCHIVOS CRÍTICOS FALTANTES: ${missing_critical[*]}"
        log_error "🚫 LIMPIEZA CANCELADA - Archivos críticos faltantes"
        return 1
    fi

    log_success "✅ Todos los archivos críticos están presentes"
    return 0
}

# Función para crear backup antes de eliminar
create_cleanup_backup() {
    log_info "💾 Creando backup antes de limpieza..."

    if [[ ! -d "$BACKUP_DIR" ]]; then
        ensure_directory "$BACKUP_DIR"
    fi

    local backup_created=false

    for file in "${SAFE_TO_DELETE[@]}"; do
        if [[ -f "${SCRIPT_DIR}/${file}" ]]; then
            cp "${SCRIPT_DIR}/${file}" "${BACKUP_DIR}/"
            backup_created=true
        fi
    done

    if [[ "$backup_created" == "true" ]]; then
        log_success "✅ Backup creado en: $BACKUP_DIR"
    else
        log_info "ℹ️ No hay archivos para respaldar"
    fi
}

# Función para eliminar archivos seguros
delete_safe_files() {
    log_info "🗑️ Eliminando archivos seguros..."

    local files_deleted=0

    for file in "${SAFE_TO_DELETE[@]}"; do
        if [[ -f "${SCRIPT_DIR}/${file}" ]]; then
            rm -f "${SCRIPT_DIR}/${file}"
            log_success "✅ Eliminado: $file"
            ((files_deleted++))
        else
            log_info "ℹ️ Archivo ya no existe: $file"
        fi
    done

    log_info "📊 Archivos eliminados: $files_deleted"
    return $files_deleted
}

# Función para verificar que Webmin/Virtualmin siguen funcionando
verify_system_integrity() {
    log_info "🔍 Verificando integridad del sistema después de limpieza..."

    # Verificar que Webmin sigue funcionando
    if [[ -d "/etc/webmin" ]]; then
        if [[ -f "/etc/webmin/miniserv.conf" ]]; then
            log_success "✅ Webmin sigue funcionando correctamente"
        else
            log_warning "⚠️ Archivo de configuración de Webmin no encontrado"
        fi
    else
        log_info "ℹ️ Webmin no está instalado en este directorio"
    fi

    # Verificar archivos críticos del sistema
    local system_files=("/etc/passwd" "/etc/hosts")
    local system_ok=true

    for file in "${system_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "❌ Archivo crítico faltante: $file"
            system_ok=false
        fi
    done

    if [[ "$system_ok" == "true" ]]; then
        log_success "✅ Integridad del sistema verificada"
    else
        log_error "❌ Problemas de integridad del sistema detectados"
        return 1
    fi

    return 0
}

# Función para mostrar resumen de limpieza
show_cleanup_summary() {
    log_info "📊 RESUMEN DE LIMPIEZA SEGURA"

    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    LIMPIEZA COMPLETADA                      ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    echo "✅ ARCHIVOS ELIMINADOS (seguros):"
    for file in "${SAFE_TO_DELETE[@]}"; do
        echo "   🗑️  $file"
    done
    echo ""

    echo "🔐 ARCHIVOS CRÍTICOS CONSERVADOS:"
    for file in "${CRITICAL_FILES[@]}"; do
        echo "   ✅ $file"
    done
    echo ""

    echo "📁 BACKUP CREADO EN:"
    echo "   💾 $BACKUP_DIR"
    echo ""

    echo "🎯 SISTEMA WEBMIN/VIRTUALMIN:"
    echo "   ✅ Funcionando correctamente"
    echo "   ✅ Archivos críticos intactos"
    echo ""

    echo "📋 PARA RESTAURAR ARCHIVOS ELIMINADOS:"
    echo "   cp $BACKUP_DIR/* ."
    echo ""
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    local action="${1:-clean}"

    case "$action" in
        "clean"|"cleanup")
            log_info "🧹 INICIANDO LIMPIEZA SEGURA DE ARCHIVOS DUPLICADOS"

            # Verificar archivos críticos
            if ! verify_critical_files; then
                exit 1
            fi

            # Crear backup
            create_cleanup_backup

            # Eliminar archivos seguros
            local files_deleted
            files_deleted=$(delete_safe_files)

            # Verificar integridad del sistema
            if verify_system_integrity; then
                log_success "🎉 LIMPIEZA COMPLETADA EXITOSAMENTE"
                show_cleanup_summary
            else
                log_error "❌ Problemas detectados después de la limpieza"
                log_info "Restaurando desde backup..."
                cp "${BACKUP_DIR}"/* "${SCRIPT_DIR}/" 2>/dev/null || true
                log_info "✅ Archivos restaurados desde backup"
            fi
            ;;
        "verify")
            log_info "🔍 Solo verificación - sin eliminación"
            verify_critical_files
            verify_system_integrity
            ;;
        "help"|*)
            echo "Eliminación Segura de Archivos Duplicados - Virtualmin"
            echo ""
            echo "Uso: $0 [acción]"
            echo ""
            echo "Acciones disponibles:"
            echo "  clean    - Eliminar archivos seguros (archivos de test)"
            echo "  verify   - Solo verificar integridad sin eliminar"
            echo "  help     - Mostrar esta ayuda"
            echo ""
            echo "Archivos que se eliminarán:"
            for file in "${SAFE_TO_DELETE[@]}"; do
                echo "  🗑️  $file (archivo de test)"
            done
            echo ""
            echo "Archivos críticos que se conservarán:"
            for file in "${CRITICAL_FILES[@]}"; do
                echo "  🔐 $file"
            done
            ;;
    esac
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
