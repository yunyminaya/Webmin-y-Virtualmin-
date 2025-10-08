#!/bin/bash

# Script de rollback automático para Webmin/Virtualmin
# Uso: ./rollback.sh [staging|production] [version|auto]

set -e

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../configs"

# Variables
ENVIRONMENT="${1:-production}"
ROLLBACK_TYPE="${2:-auto}"
BACKUP_DIR="/var/backups/webmin_virtualmin"
LOG_FILE="/var/log/webmin_rollback_$(date +%Y%m%d_%H%M%S).log"

# Función de logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

# Validar parámetros
validate_params() {
    case "$ENVIRONMENT" in
        staging|production)
            ;;
        *)
            log "❌ Error: Environment must be 'staging' or 'production'"
            exit 1
            ;;
    esac

    case "$ROLLBACK_TYPE" in
        auto|version)
            ;;
        *)
            log "❌ Error: Rollback type must be 'auto' or 'version'"
            exit 1
            ;;
    esac
}

# Encontrar backup más reciente
find_latest_backup() {
    local component="$1"
    local pattern="pre_deploy_${ENVIRONMENT}_*_${component}.tar.gz"

    local latest_backup=$(ls -t "$BACKUP_DIR"/$pattern 2>/dev/null | head -1)

    if [ -z "$latest_backup" ]; then
        log "⚠️ No backup found for $component in $ENVIRONMENT environment"
        return 1
    fi

    echo "$latest_backup"
}

# Verificar integridad del backup
verify_backup() {
    local backup_file="$1"

    if [ ! -f "$backup_file" ]; then
        log "❌ Backup file not found: $backup_file"
        return 1
    fi

    # Verificar que el archivo no esté corrupto
    if ! tar -tzf "$backup_file" >/dev/null 2>&1; then
        log "❌ Backup file is corrupted: $backup_file"
        return 1
    fi

    log "✅ Backup integrity verified: $backup_file"
    return 0
}

# Crear backup de estado actual antes del rollback
create_current_state_backup() {
    log "💾 Creating backup of current state before rollback..."

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="current_state_${ENVIRONMENT}_${timestamp}"

    # Backup de configuración actual
    if [ -d "/etc/webmin" ]; then
        tar -czf "$BACKUP_DIR/${backup_name}_webmin.tar.gz" -C / etc/webmin 2>/dev/null || true
        log "✅ Current Webmin configuration backed up"
    fi

    if [ -d "/etc/virtualmin" ]; then
        tar -czf "$BACKUP_DIR/${backup_name}_virtualmin.tar.gz" -C / etc/virtualmin 2>/dev/null || true
        log "✅ Current Virtualmin configuration backed up"
    fi
}

# Rollback de Webmin
rollback_webmin() {
    log "🔄 Rolling back Webmin..."

    local backup_file=$(find_latest_backup "webmin")

    if [ -z "$backup_file" ]; then
        log "❌ No Webmin backup available for rollback"
        return 1
    fi

    # Verificar backup
    if ! verify_backup "$backup_file"; then
        return 1
    fi

    # Detener servicio
    log "🛑 Stopping Webmin service..."
    systemctl stop webmin 2>/dev/null || true

    # Restaurar configuración
    log "📦 Restoring Webmin configuration from backup..."
    tar -xzf "$backup_file" -C / 2>/dev/null || {
        log "❌ Failed to restore Webmin configuration"
        return 1
    }

    # Iniciar servicio
    log "▶️ Starting Webmin service..."
    systemctl start webmin 2>/dev/null || {
        log "❌ Failed to start Webmin service after rollback"
        return 1
    }

    # Verificar que esté funcionando
    sleep 5
    if systemctl is-active --quiet webmin 2>/dev/null; then
        log "✅ Webmin rollback completed successfully"
        return 0
    else
        log "❌ Webmin service failed to start after rollback"
        return 1
    fi
}

# Rollback de Virtualmin
rollback_virtualmin() {
    log "🔄 Rolling back Virtualmin..."

    local backup_file=$(find_latest_backup "virtualmin")

    if [ -z "$backup_file" ]; then
        log "❌ No Virtualmin backup available for rollback"
        return 1
    fi

    # Verificar backup
    if ! verify_backup "$backup_file"; then
        return 1
    fi

    # Restaurar configuración
    log "📦 Restoring Virtualmin configuration from backup..."
    tar -xzf "$backup_file" -C / 2>/dev/null || {
        log "❌ Failed to restore Virtualmin configuration"
        return 1
    }

    # Reiniciar servicios relacionados
    log "🔄 Restarting related services..."
    systemctl restart webmin 2>/dev/null || true
    systemctl restart apache2 2>/dev/null || true
    systemctl restart nginx 2>/dev/null || true
    systemctl restart postfix 2>/dev/null || true
    systemctl restart dovecot 2>/dev/null || true

    log "✅ Virtualmin rollback completed successfully"
    return 0
}

# Rollback de base de datos
rollback_database() {
    log "🗄️ Rolling back database..."

    local db_backup=$(ls -t "$BACKUP_DIR"/pre_deploy_${ENVIRONMENT}_*_databases.sql 2>/dev/null | head -1)

    if [ -z "$db_backup" ]; then
        log "⚠️ No database backup found, skipping database rollback"
        return 0
    fi

    # Verificar que mysql/mariadb esté disponible
    if ! command -v mysql >/dev/null 2>&1; then
        log "⚠️ MySQL client not available, skipping database rollback"
        return 0
    fi

    log "📦 Restoring database from backup..."
    if mysql < "$db_backup" 2>/dev/null; then
        log "✅ Database rollback completed successfully"
        return 0
    else
        log "❌ Database rollback failed"
        return 1
    fi
}

# Ejecutar pruebas post-rollback
run_post_rollback_tests() {
    log "🧪 Running post-rollback tests..."

    local test_results=0

    # Verificar servicios
    if ! systemctl is-active --quiet webmin 2>/dev/null; then
        log "❌ Webmin service is not running after rollback"
        test_results=1
    else
        log "✅ Webmin service is running"
    fi

    # Verificar conectividad
    if ! nc -z localhost 10000 2>/dev/null; then
        log "❌ Webmin is not responding on port 10000"
        test_results=1
    else
        log "✅ Webmin is responding on port 10000"
    fi

    # Verificar configuración
    if [ ! -d "/etc/webmin" ]; then
        log "❌ Webmin configuration not found after rollback"
        test_results=1
    else
        log "✅ Webmin configuration restored"
    fi

    return $test_results
}

# Notificar resultado del rollback
notify_rollback_result() {
    local success="$1"
    local details="$2"

    log "📢 Notifying rollback result..."

    # Aquí iría la lógica de notificación
    # - Slack notifications
    # - Email notifications
    # - Dashboard updates

    if [ "$success" = true ]; then
        log "✅ Rollback completed successfully"
    else
        log "❌ Rollback failed: $details"
    fi
}

# Función principal
main() {
    log "🔄 Starting Webmin/Virtualmin rollback"
    log "Environment: $ENVIRONMENT"
    log "Type: $ROLLBACK_TYPE"
    log "================================="

    # Validar parámetros
    validate_params

    # Crear backup del estado actual
    create_current_state_backup

    local rollback_success=true
    local error_details=""

    # Ejecutar rollbacks
    if ! rollback_webmin; then
        rollback_success=false
        error_details="Webmin rollback failed"
    fi

    if ! rollback_virtualmin; then
        rollback_success=false
        error_details="$error_details; Virtualmin rollback failed"
    fi

    if ! rollback_database; then
        rollback_success=false
        error_details="$error_details; Database rollback failed"
    fi

    # Ejecutar pruebas post-rollback
    if [ "$rollback_success" = true ]; then
        if run_post_rollback_tests; then
            log "🎉 Rollback completed successfully!"
        else
            log "⚠️ Rollback completed but post-rollback tests failed"
            rollback_success=false
            error_details="Post-rollback tests failed"
        fi
    fi

    # Notificar resultado
    notify_rollback_result "$rollback_success" "$error_details"

    # Limpiar archivos temporales
    log "🧹 Cleaning up temporary files..."
    # Aquí iría limpieza de archivos temporales

    if [ "$rollback_success" = true ]; then
        return 0
    else
        log "❌ Rollback failed: $error_details"
        return 1
    fi
}

# Manejo de señales
trap 'log "❌ Rollback interrupted by user"; exit 1' INT TERM

# Ejecutar función principal
main "$@"