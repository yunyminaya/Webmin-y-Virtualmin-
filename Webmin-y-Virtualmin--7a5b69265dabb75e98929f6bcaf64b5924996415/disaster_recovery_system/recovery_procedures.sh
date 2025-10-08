#!/bin/bash

# PROCEDIMIENTOS DE RECUPERACIÓN AUTOMATIZADOS
# Gestiona la recuperación automática del sistema desde backups

set -euo pipefail
IFS=$'\n\t'

# Cargar configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/dr_config.conf"
source "$CONFIG_FILE"

# Variables globales
LOG_FILE="$LOG_DIR/recovery_procedures.log"
RECOVERY_STATUS_FILE="$DR_ROOT_DIR/recovery_status.json"
BACKUP_SYSTEM_SCRIPT="$SCRIPT_DIR/../../../auto_backup_system.sh"

# Funciones de logging
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [RECOVERY] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [RECOVERY-ERROR] $*" >&2 | tee -a "$LOG_FILE"
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [RECOVERY-SUCCESS] $*" | tee -a "$LOG_FILE"
}

# Función para determinar el tipo de recuperación basado en el daño
assess_damage() {
    log_info "Evaluando daño del sistema para determinar estrategia de recuperación..."

    local damage_assessment="partial"
    local critical_services_down=0
    local data_loss_detected=false

    # Verificar servicios críticos
    for service in "${CRITICAL_SERVICES[@]}"; do
        if ! systemctl is-active --quiet "$service" 2>/dev/null; then
            critical_services_down=$((critical_services_down + 1))
        fi
    done

    # Si más del 50% de servicios críticos están caídos, considerar recuperación completa
    if [[ $critical_services_down -gt $((${#CRITICAL_SERVICES[@]} / 2)) ]]; then
        damage_assessment="full"
        log_info "Daño severo detectado: $critical_services_down servicios críticos caídos"
    fi

    # Verificar pérdida de datos
    for dir in "${REALTIME_REPLICATION_DIRS[@]}"; do
        if [[ ! -d "$dir" ]] || [[ ! -r "$dir" ]]; then
            data_loss_detected=true
            log_warning "Pérdida de datos detectada en: $dir"
        fi
    done

    if [[ "$data_loss_detected" == "true" ]]; then
        damage_assessment="full"
    fi

    # Verificar corrupción de base de datos
    if command -v mysql &>/dev/null; then
        if ! mysql -e "SELECT 1;" &>/dev/null; then
            damage_assessment="full"
            log_warning "Corrupción de base de datos MySQL detectada"
        fi
    fi

    log_info "Evaluación de daño completada: $damage_assessment"
    echo "$damage_assessment"
}

# Función para seleccionar backup apropiado
select_backup() {
    local recovery_type=$1
    local backup_type=""

    case "$recovery_type" in
        "full")
            # Para recuperación completa, usar backup semanal o mensual más reciente
            backup_type="weekly"
            if [[ -d "$BACKUP_DIR/monthly" ]] && [[ $(find "$BACKUP_DIR/monthly" -type d -mtime -30 | wc -l) -gt 0 ]]; then
                backup_type="monthly"
            fi
            ;;
        "partial")
            # Para recuperación parcial, usar backup diario más reciente
            backup_type="daily"
            ;;
        "critical")
            # Para recuperación crítica, usar backup más reciente disponible
            if [[ -d "$BACKUP_DIR/daily" ]] && [[ $(find "$BACKUP_DIR/daily" -type d -mtime -1 | wc -l) -gt 0 ]]; then
                backup_type="daily"
            elif [[ -d "$BACKUP_DIR/weekly" ]] && [[ $(find "$BACKUP_DIR/weekly" -type d -mtime -7 | wc -l) -gt 0 ]]; then
                backup_type="weekly"
            else
                backup_type="monthly"
            fi
            ;;
    esac

    # Encontrar el backup más reciente del tipo seleccionado
    local backup_path=""
    if [[ -d "$BACKUP_DIR/$backup_type" ]]; then
        backup_path=$(find "$BACKUP_DIR/$backup_type" -type d -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
    fi

    if [[ -z "$backup_path" ]]; then
        log_error "No se encontró backup apropiado del tipo: $backup_type"
        return 1
    fi

    log_info "Backup seleccionado: $backup_path"
    echo "$backup_path"
}

# Función para ejecutar recuperación completa del sistema
execute_full_recovery() {
    log_info "=== INICIANDO RECUPERACIÓN COMPLETA DEL SISTEMA ==="

    local backup_path
    backup_path=$(select_backup "full")

    if [[ -z "$backup_path" ]]; then
        log_error "No se puede proceder sin backup válido"
        return 1
    fi

    local recovery_start=$(date +%s)
    update_recovery_status "full_recovery_in_progress" "$backup_path"

    # Paso 1: Detener todos los servicios
    log_info "Paso 1: Deteniendo servicios del sistema..."

    for service in "${CRITICAL_SERVICES[@]}"; do
        systemctl stop "$service" 2>/dev/null || true
    done

    # Paso 2: Crear punto de montaje temporal si es necesario
    local temp_mount="/mnt/system_recovery"
    mkdir -p "$temp_mount"

    # Paso 3: Restaurar sistema de archivos completo
    log_info "Paso 3: Restaurando sistema de archivos..."

    if [[ -f "$backup_path/system_full.tar.gz" ]]; then
        log_info "Restaurando desde backup completo: $backup_path/system_full.tar.gz"

        # Restaurar en directorio temporal primero
        cd "$temp_mount"
        if tar -xzf "$backup_path/system_full.tar.gz" 2>>"$LOG_FILE"; then
            log_success "Backup completo descomprimido exitosamente"
        else
            log_error "Error al descomprimir backup completo"
            return 1
        fi
    else
        log_warning "No se encontró backup completo, intentando restauración parcial"
        execute_partial_recovery
        return $?
    fi

    # Paso 4: Restaurar configuración crítica
    log_info "Paso 4: Restaurando configuración crítica..."

    restore_critical_config "$backup_path"

    # Paso 5: Restaurar bases de datos
    log_info "Paso 5: Restaurando bases de datos..."

    restore_databases "$backup_path"

    # Paso 6: Reiniciar servicios
    log_info "Paso 6: Reiniciando servicios del sistema..."

    for service in "${CRITICAL_SERVICES[@]}"; do
        if systemctl start "$service" 2>/dev/null; then
            log_success "Servicio $service iniciado"
        else
            log_error "Error al iniciar servicio $service"
        fi
    done

    # Paso 7: Verificar recuperación
    log_info "Paso 7: Verificando recuperación completa..."

    if verify_recovery; then
        local recovery_duration=$(( $(date +%s) - recovery_start ))
        update_recovery_status "full_recovery_completed" "$backup_path" "$recovery_duration"
        log_success "RECUPERACIÓN COMPLETA EXITOSA (${recovery_duration}s)"
        return 0
    else
        update_recovery_status "full_recovery_failed" "$backup_path"
        log_error "VERIFICACIÓN DE RECUPERACIÓN FALLÓ"
        return 1
    fi
}

# Función para ejecutar recuperación parcial
execute_partial_recovery() {
    log_info "=== INICIANDO RECUPERACIÓN PARCIAL ==="

    local backup_path
    backup_path=$(select_backup "partial")

    if [[ -z "$backup_path" ]]; then
        log_error "No se puede proceder sin backup válido"
        return 1
    fi

    local recovery_start=$(date +%s)
    update_recovery_status "partial_recovery_in_progress" "$backup_path"

    # Paso 1: Identificar componentes dañados
    local damaged_components=()
    for dir in "${REALTIME_REPLICATION_DIRS[@]}"; do
        if [[ ! -d "$dir" ]] || [[ ! -r "$dir" ]]; then
            damaged_components+=("$dir")
        fi
    done

    # Paso 2: Restaurar componentes dañados
    log_info "Paso 2: Restaurando componentes dañados: ${damaged_components[*]}"

    for component in "${damaged_components[@]}"; do
        restore_component "$component" "$backup_path"
    done

    # Paso 3: Restaurar configuración crítica si es necesario
    if [[ " ${damaged_components[*]} " =~ " /etc " ]]; then
        restore_critical_config "$backup_path"
    fi

    # Paso 4: Restaurar bases de datos si es necesario
    if [[ " ${damaged_components[*]} " =~ " /var/lib/mysql " ]]; then
        restore_databases "$backup_path"
    fi

    # Paso 5: Reiniciar servicios afectados
    log_info "Paso 5: Reiniciando servicios afectados..."

    for service in "${CRITICAL_SERVICES[@]}"; do
        systemctl restart "$service" 2>/dev/null || true
    done

    # Paso 6: Verificar recuperación
    log_info "Paso 6: Verificando recuperación parcial..."

    if verify_recovery; then
        local recovery_duration=$(( $(date +%s) - recovery_start ))
        update_recovery_status "partial_recovery_completed" "$backup_path" "$recovery_duration"
        log_success "RECUPERACIÓN PARCIAL EXITOSA (${recovery_duration}s)"
        return 0
    else
        update_recovery_status "partial_recovery_failed" "$backup_path"
        log_error "VERIFICACIÓN DE RECUPERACIÓN FALLÓ"
        return 1
    fi
}

# Función para restaurar componente específico
restore_component() {
    local component=$1
    local backup_path=$2

    log_info "Restaurando componente: $component"

    # Determinar archivo de backup apropiado
    local backup_file=""

    case "$component" in
        "/etc")
            backup_file="$backup_path/etc.tar.gz"
            ;;
        "/var/log")
            backup_file="$backup_path/logs.tar.gz"
            ;;
        "/var/www")
            backup_file="$backup_path/var.tar.gz"
            ;;
        "/var/lib/mysql")
            # Las bases de datos se restauran por separado
            return 0
            ;;
        *)
            log_warning "Componente no reconocido para restauración: $component"
            return 1
            ;;
    esac

    if [[ -f "$backup_file" ]]; then
        if tar -xzf "$backup_file" -C / 2>>"$LOG_FILE"; then
            log_success "Componente restaurado: $component"
            return 0
        else
            log_error "Error al restaurar componente: $component"
            return 1
        fi
    else
        log_warning "Archivo de backup no encontrado: $backup_file"
        return 1
    fi
}

# Función para restaurar configuración crítica
restore_critical_config() {
    local backup_path=$1

    log_info "Restaurando configuración crítica..."

    for config_file in "${CONFIG_FILES[@]}"; do
        local config_backup="$backup_path/configs/$(basename "$config_file")"

        if [[ -f "$config_backup" ]]; then
            cp "$config_backup" "$config_file" 2>>"$LOG_FILE" || true
            log_info "Configuración restaurada: $config_file"
        fi
    done

    log_success "Configuración crítica restaurada"
}

# Función para restaurar bases de datos
restore_databases() {
    local backup_path=$1

    log_info "Restaurando bases de datos..."

    local db_backup_dir="$backup_path/databases"

    if [[ -d "$db_backup_dir" ]]; then
        # Restaurar MySQL si existe backup
        if [[ -f "$db_backup_dir/mysql.sql" ]]; then
            log_info "Restaurando base de datos MySQL..."

            if systemctl is-active --quiet mysql; then
                systemctl stop mysql
            fi

            # Restaurar desde backup
            mysql < "$db_backup_dir/mysql.sql" 2>>"$LOG_FILE" || true

            systemctl start mysql 2>/dev/null || true
            log_success "Base de datos MySQL restaurada"
        fi

        # Aquí se podrían añadir otras bases de datos (PostgreSQL, etc.)
    else
        log_warning "Directorio de backups de base de datos no encontrado"
    fi
}

# Función para verificar recuperación exitosa
verify_recovery() {
    log_info "Verificando integridad de la recuperación..."

    local checks_passed=0
    local total_checks=0

    # Verificar servicios críticos
    for service in "${CRITICAL_SERVICES[@]}"; do
        total_checks=$((total_checks + 1))

        if systemctl is-active --quiet "$service" 2>/dev/null; then
            checks_passed=$((checks_passed + 1))
            log_info "✓ Servicio $service: OK"
        else
            log_error "✗ Servicio $service: FALLÓ"
        fi
    done

    # Verificar directorios críticos
    for dir in "${REALTIME_REPLICATION_DIRS[@]}"; do
        total_checks=$((total_checks + 1))

        if [[ -d "$dir" ]] && [[ -r "$dir" ]]; then
            checks_passed=$((checks_passed + 1))
            log_info "✓ Directorio $dir: OK"
        else
            log_error "✗ Directorio $dir: FALLÓ"
        fi
    done

    # Verificar conectividad básica
    total_checks=$((total_checks + 1))

    if ping -c 3 -W 5 "8.8.8.8" &>/dev/null; then
        checks_passed=$((checks_passed + 1))
        log_info "✓ Conectividad de red: OK"
    else
        log_error "✗ Conectividad de red: FALLÓ"
    fi

    local success_rate=$((checks_passed * 100 / total_checks))

    if [[ $success_rate -ge 80 ]]; then
        log_success "Verificación de recuperación exitosa: $success_rate%"
        return 0
    else
        log_error "Verificación de recuperación fallida: $success_rate%"
        return 1
    fi
}

# Función para ejecutar recuperación de emergencia
execute_emergency_recovery() {
    log_info "=== INICIANDO RECUPERACIÓN DE EMERGENCIA ==="

    # En recuperación de emergencia, intentar lo mínimo necesario para restaurar servicio
    update_recovery_status "emergency_recovery_in_progress" "latest_available"

    # Detener servicios problemáticos
    for service in "${CRITICAL_SERVICES[@]}"; do
        systemctl stop "$service" 2>/dev/null || true
    done

    # Intentar restaurar desde el backup más reciente disponible
    local latest_backup=""
    for backup_type in daily weekly monthly; do
        if [[ -d "$BACKUP_DIR/$backup_type" ]]; then
            local candidate
            candidate=$(find "$BACKUP_DIR/$backup_type" -type d -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
            if [[ -n "$candidate" ]]; then
                latest_backup="$candidate"
                break
            fi
        fi
    done

    if [[ -z "$latest_backup" ]]; then
        log_error "No se encontraron backups disponibles para recuperación de emergencia"
        return 1
    fi

    # Restaurar solo configuración crítica y bases de datos
    restore_critical_config "$latest_backup"
    restore_databases "$latest_backup"

    # Iniciar servicios mínimos
    for service in apache2 mysql; do
        systemctl start "$service" 2>/dev/null || true
    done

    if verify_recovery; then
        update_recovery_status "emergency_recovery_completed" "$latest_backup"
        log_success "RECUPERACIÓN DE EMERGENCIA EXITOSA"
        return 0
    else
        update_recovery_status "emergency_recovery_failed" "$latest_backup"
        log_error "RECUPERACIÓN DE EMERGENCIA FALLÓ"
        return 1
    fi
}

# Función para actualizar estado de recuperación
update_recovery_status() {
    local status=$1
    local backup_used=$2
    local duration=${3:-""}

    cat > "$RECOVERY_STATUS_FILE" << EOF
{
    "recovery_status": "$status",
    "backup_used": "$backup_used",
    "timestamp": "$(date -Iseconds)",
    "duration_seconds": "$duration",
    "rto_target": "$RTO_MINUTES",
    "rpo_target": "$RPO_SECONDS"
}
EOF
}

# Función para mostrar estado de recuperación
show_recovery_status() {
    echo "=========================================="
    echo "  ESTADO DE RECUPERACIÓN"
    echo "=========================================="

    if [[ -f "$RECOVERY_STATUS_FILE" ]]; then
        cat "$RECOVERY_STATUS_FILE" | jq . 2>/dev/null || cat "$RECOVERY_STATUS_FILE"
    else
        echo "No hay estado de recuperación disponible"
    fi

    echo
    echo "Objetivos de recuperación (RTO/RPO):"
    echo "RTO: ${RTO_MINUTES} minutos"
    echo "RPO: ${RPO_SECONDS} segundos"

    echo
    echo "Backups disponibles:"
    for backup_type in daily weekly monthly; do
        if [[ -d "$BACKUP_DIR/$backup_type" ]]; then
            local count
            count=$(find "$BACKUP_DIR/$backup_type" -type d 2>/dev/null | wc -l)
            echo "$backup_type: $count backups"
        fi
    done
}

# Función principal
main() {
    local action=${1:-"status"}

    echo "=========================================="
    echo "  PROCEDIMIENTOS DE RECUPERACIÓN DR"
    echo "=========================================="
    echo

    case "$action" in
        "recover")
            local recovery_type=${2:-"auto"}

            if [[ "$recovery_type" == "auto" ]]; then
                recovery_type=$(assess_damage)
            fi

            case "$recovery_type" in
                "full")
                    execute_full_recovery
                    ;;
                "partial")
                    execute_partial_recovery
                    ;;
                "emergency")
                    execute_emergency_recovery
                    ;;
                *)
                    log_error "Tipo de recuperación no válido: $recovery_type"
                    exit 1
                    ;;
            esac
            ;;

        "assess")
            assess_damage
            ;;

        "verify")
            verify_recovery && echo "Recuperación verificada" || echo "Problemas en recuperación"
            ;;

        "status")
            show_recovery_status
            ;;

        *)
            echo "Uso: $0 {recover|assess|verify|status} [tipo]"
            echo
            echo "Comandos disponibles:"
            echo "  recover [auto|full|partial|emergency] - Ejecutar recuperación"
            echo "  assess                               - Evaluar daño del sistema"
            echo "  verify                               - Verificar recuperación"
            echo "  status                               - Mostrar estado de recuperación"
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"