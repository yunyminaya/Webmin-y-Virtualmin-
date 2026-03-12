#!/bin/bash

# Sistema de Backups Automáticos Enterprise
# Configura backups programados para todo el sistema
# Versión: Enterprise Professional 2025

set -euo pipefail
IFS=$'\n\t'

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/opt/enterprise_backups"
LOG_FILE="$SCRIPT_DIR/backup.log"
CONFIG_FILE="$SCRIPT_DIR/backup_config.conf"
CRON_FILE="$SCRIPT_DIR/enterprise_backup.cron"

# Funciones de validación de seguridad
validate_action() {
    local action=$1
    case "$action" in
        setup|daily|weekly|monthly|cleanup|verify|status)
            return 0
            ;;
        *)
            log_error "Acción no válida: $action"
            return 1
            ;;
    esac
}

validate_file_path() {
    local path=$1
    # Verificar que sea path absoluto y no contenga .. o caracteres peligrosos
    if [[ ! "$path" =~ ^/[^/]*$|^(/[a-zA-Z0-9._-]+)+$ ]] || [[ "$path" == *..* ]] || [[ "$path" == *[\;\|\&\`\$]* ]]; then
        log_error "Path no válido o peligroso: $path"
        return 1
    fi
    return 0
}

validate_db_name() {
    local db_name=$1
    # Solo permitir alfanuméricos, guiones bajos y guiones
    if [[ ! "$db_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Nombre de base de datos no válido: $db_name"
        return 1
    fi
    return 0
}

# Funciones de logging
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" >&2 | tee -a "$LOG_FILE"
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $*" | tee -a "$LOG_FILE"
}

log_backup() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [BACKUP] $*" | tee -a "$LOG_FILE"
}

# Verificar permisos de root (opcional para desarrollo)
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_info "Ejecutándose sin privilegios de root - Modo desarrollo"
        # En modo desarrollo, usar directorios locales
        BACKUP_DIR="$SCRIPT_DIR/enterprise_backups"
        CRON_FILE="$SCRIPT_DIR/enterprise_backup.cron"
    fi
}

# Crear directorios necesarios
create_backup_directories() {
    log_info "Creando directorios de backup..."

    mkdir -p "$BACKUP_DIR"/{daily,weekly,monthly,configs,databases,logs}
    mkdir -p "$BACKUP_DIR"/archives
    mkdir -p "$BACKUP_DIR"/temp

    # Configurar permisos (sin root si es necesario)
    if [[ $EUID -eq 0 ]]; then
        chown root:root "$BACKUP_DIR" 2>/dev/null || true
        chmod 700 "$BACKUP_DIR"
    else
        chmod 755 "$BACKUP_DIR"
    fi
    chmod 755 "$BACKUP_DIR"/* 2>/dev/null || true

    log_success "Directorios de backup creados"
}

# Crear archivo de configuración
create_config_file() {
    log_info "Creando archivo de configuración..."

    cat > "$CONFIG_FILE" << EOF
# Configuración de Backups Enterprise
# Generado automáticamente - $(date)

# Directorios de backup
BACKUP_ROOT="$BACKUP_DIR"
DAILY_DIR="\$BACKUP_ROOT/daily"
WEEKLY_DIR="\$BACKUP_ROOT/weekly"
MONTHLY_DIR="\$BACKUP_ROOT/monthly"
CONFIG_DIR="\$BACKUP_ROOT/configs"
DB_DIR="\$BACKUP_ROOT/databases"
LOG_DIR="\$BACKUP_ROOT/logs"

# Retención de backups (días)
DAILY_RETENTION=7
WEEKLY_RETENTION=30
MONTHLY_RETENTION=365

# Directorios a respaldar
BACKUP_DIRS=(
    "/etc"
    "/var/www"
    "/var/lib/mysql"
    "/var/log"
    "/opt"
    "/usr/local"
    "/home"
)

# Bases de datos a respaldar
DATABASES=(
    "mysql"
    "information_schema"
    "performance_schema"
)

# Archivos de configuración críticos
CONFIG_FILES=(
    "/etc/apache2/apache2.conf"
    "/etc/mysql/mysql.conf.d/mysqld.cnf"
    "/etc/ssh/sshd_config"
    "/etc/fstab"
    "/etc/crontab"
    "/etc/hosts"
    "/etc/resolv.conf"
)

# Opciones de compresión
COMPRESSION_LEVEL=6
COMPRESSION_TYPE="gzip"

# Opciones de encriptación
ENCRYPT_BACKUPS=true
ENCRYPTION_KEY_FILE="\$BACKUP_ROOT/.backup_key"

# Notificaciones
ENABLE_NOTIFICATIONS=true
NOTIFICATION_EMAIL="admin@enterprise.local"

# Exclusiones
EXCLUDE_PATTERNS=(
    "*.log"
    "*.tmp"
    "*.cache"
    "*/cache/*"
    "*/tmp/*"
    "*/.git/*"
)
EOF

    chmod 600 "$CONFIG_FILE"
    log_success "Archivo de configuración creado: $CONFIG_FILE"
}

# Generar clave de encriptación
generate_encryption_key() {
    log_info "Generando clave de encriptación..."

    local key_file="$BACKUP_DIR/.backup_key"

    if [[ ! -f "$key_file" ]]; then
        openssl rand -base64 32 > "$key_file"
        chmod 600 "$key_file"
        log_success "Clave de encriptación generada"
    else
        log_info "Clave de encriptación ya existe"
    fi
}

# Función de backup de archivos
backup_files() {
    local backup_type=$1
    local source_dir=$2
    local dest_file=$3

    # Validar paths
    if ! validate_file_path "$source_dir"; then
        return 1
    fi
    if ! validate_file_path "$dest_file"; then
        return 1
    fi

    log_backup "Iniciando backup de archivos: $source_dir -> $dest_file"

    # Crear archivo tar con compresión
    if tar -czf "$dest_file" \
        --exclude="*.log" \
        --exclude="*.tmp" \
        --exclude="*/cache/*" \
        --exclude="*/tmp/*" \
        --exclude="*/.git/*" \
        -C "$source_dir" . 2>/dev/null; then

        log_success "Backup de archivos completado: $dest_file"
        return 0
    else
        log_error "Error en backup de archivos: $source_dir"
        return 1
    fi
}

# Función de backup de base de datos
backup_database() {
    local db_name=$1
    local dest_file=$2

    # Validar nombre de DB
    if ! validate_db_name "$db_name"; then
        return 1
    fi

    log_backup "Iniciando backup de base de datos: $db_name"

    if command -v mysqldump &> /dev/null; then
        # Sanitizar db_name para prevenir inyección
        local safe_db_name=$(printf '%q' "$db_name")
        if mysqldump --single-transaction --routines --triggers "$safe_db_name" > "$dest_file" 2>/dev/null; then
            log_success "Backup de base de datos completado: $db_name"
            return 0
        else
            log_error "Error en backup de base de datos: $db_name"
            return 1
        fi
    else
        log_error "mysqldump no encontrado"
        return 1
    fi
}

# Función de backup diario
daily_backup() {
    log_backup "=== INICIANDO BACKUP DIARIO ==="

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local daily_dir="$BACKUP_DIR/daily/$timestamp"

    mkdir -p "$daily_dir"

    # Backup de archivos críticos
    backup_files "daily" "/etc" "$daily_dir/etc.tar.gz"
    backup_files "daily" "/var/log" "$daily_dir/logs.tar.gz"

    # Backup de bases de datos
    mkdir -p "$daily_dir/databases"
    backup_database "mysql" "$daily_dir/databases/mysql.sql"

    # Crear archivo de metadatos
    cat > "$daily_dir/metadata.txt" << EOF
Backup Diario - $(date)
Timestamp: $timestamp
Tipo: Diario
Servidor: $(hostname)
Sistema: $(uname -a)
EOF

    log_success "Backup diario completado: $daily_dir"
}

# Función de backup semanal
weekly_backup() {
    log_backup "=== INICIANDO BACKUP SEMANAL ==="

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local weekly_dir="$BACKUP_DIR/weekly/$timestamp"

    mkdir -p "$weekly_dir"

    # Backup completo del sistema
    backup_files "weekly" "/var" "$weekly_dir/var.tar.gz"
    backup_files "weekly" "/opt" "$weekly_dir/opt.tar.gz"
    backup_files "weekly" "/usr/local" "$weekly_dir/usr_local.tar.gz"

    # Backup completo de bases de datos
    mkdir -p "$weekly_dir/databases"
    backup_database "mysql" "$weekly_dir/databases/mysql_full.sql"

    log_success "Backup semanal completado: $weekly_dir"
}

# Función de backup mensual
monthly_backup() {
    log_backup "=== INICIANDO BACKUP MENSUAL ==="

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local monthly_dir="$BACKUP_DIR/monthly/$timestamp"

    mkdir -p "$monthly_dir"

    # Backup completo de todo el sistema
    backup_files "monthly" "/" "$monthly_dir/system_full.tar.gz"

    # Backup completo de bases de datos
    mkdir -p "$monthly_dir/databases"
    backup_database "mysql" "$monthly_dir/databases/mysql_full.sql"

    log_success "Backup mensual completado: $monthly_dir"
}

# Función de limpieza de backups antiguos
cleanup_old_backups() {
    log_backup "=== LIMPIANDO BACKUPS ANTIGUOS ==="

    # Limpiar backups diarios (mantener 7 días)
    find "$BACKUP_DIR/daily" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true

    # Limpiar backups semanales (mantener 4 semanas)
    find "$BACKUP_DIR/weekly" -type d -mtime +28 -exec rm -rf {} + 2>/dev/null || true

    # Limpiar backups mensuales (mantener 12 meses)
    find "$BACKUP_DIR/monthly" -type d -mtime +365 -exec rm -rf {} + 2>/dev/null || true

    log_success "Limpieza de backups antiguos completada"
}

# Configurar cron jobs
setup_cron_jobs() {
    log_info "Configurando trabajos programados..."

    cat > "$CRON_FILE" << EOF
# Backups Enterprise - Generado automáticamente
# $(date)

# Backup diario - 2:00 AM
0 2 * * * root $SCRIPT_DIR/auto_backup_system.sh daily

# Backup semanal - Domingos 3:00 AM
0 3 * * 0 root $SCRIPT_DIR/auto_backup_system.sh weekly

# Backup mensual - Primer día del mes 4:00 AM
0 4 1 * * root $SCRIPT_DIR/auto_backup_system.sh monthly

# Limpieza de backups antiguos - Diariamente 5:00 AM
0 5 * * * root $SCRIPT_DIR/auto_backup_system.sh cleanup
EOF

    chmod 600 "$CRON_FILE"

    # Recargar cron
    if command -v systemctl &> /dev/null; then
        systemctl reload cron 2>/dev/null || true
    fi

    log_success "Trabajos programados configurados"
}

# Función de verificación de integridad
verify_backups() {
    log_backup "=== VERIFICANDO INTEGRIDAD DE BACKUPS ==="

    local errors=0

    # Verificar que los directorios existen
    for dir in daily weekly monthly; do
        if [[ ! -d "$BACKUP_DIR/$dir" ]]; then
            log_error "Directorio de backup faltante: $dir"
            errors=$((errors + 1))
        fi
    done

    # Verificar archivos de configuración
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Archivo de configuración faltante: $CONFIG_FILE"
        errors=$((errors + 1))
    fi

    # Verificar clave de encriptación
    if [[ ! -f "$BACKUP_DIR/.backup_key" ]]; then
        log_error "Clave de encriptación faltante"
        errors=$((errors + 1))
    fi

    if [[ $errors -eq 0 ]]; then
        log_success "Verificación de integridad: PASSED"
        return 0
    else
        log_error "Verificación de integridad: FAILED ($errors errores)"
        return 1
    fi
}

# Función principal
main() {
    local action=${1:-"setup"}

    # Validar acción
    if ! validate_action "$action"; then
        echo "Uso: $0 {setup|daily|weekly|monthly|cleanup|verify|status}"
        exit 1
    fi

    echo "=========================================="
    echo "  SISTEMA DE BACKUPS AUTOMÁTICOS"
    echo "  Enterprise Webmin/Virtualmin"
    echo "=========================================="
    echo

    case "$action" in
        "setup")
            log_info "Configurando sistema de backups automáticos..."

            check_root
            create_backup_directories
            create_config_file
            generate_encryption_key
            setup_cron_jobs
            verify_backups

            echo
            echo "=========================================="
            echo "  ✅ SISTEMA DE BACKUPS CONFIGURADO"
            echo "=========================================="
            echo "Directorio de backups: $BACKUP_DIR"
            echo "Archivo de configuración: $CONFIG_FILE"
            echo "Archivo de cron: $CRON_FILE"
            echo
            log_success "Sistema de backups automáticos configurado exitosamente"
            ;;

        "daily")
            daily_backup
            cleanup_old_backups
            ;;

        "weekly")
            weekly_backup
            cleanup_old_backups
            ;;

        "monthly")
            monthly_backup
            cleanup_old_backups
            ;;

        "cleanup")
            cleanup_old_backups
            ;;

        "verify")
            verify_backups
            ;;

        "status")
            echo "=== ESTADO DEL SISTEMA DE BACKUPS ==="
            echo "Directorio de backups: $BACKUP_DIR"
            echo "Espacio usado: $(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)"
            echo "Backups diarios: $(find "$BACKUP_DIR/daily" -type d 2>/dev/null | wc -l)"
            echo "Backups semanales: $(find "$BACKUP_DIR/weekly" -type d 2>/dev/null | wc -l)"
            echo "Backups mensuales: $(find "$BACKUP_DIR/monthly" -type d 2>/dev/null | wc -l)"
            echo "Último backup diario: $(find "$BACKUP_DIR/daily" -type d -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)"
            echo "Archivo de configuración: $([[ -f "$CONFIG_FILE" ]] && echo "OK" || echo "FALTANTE")"
            echo "Trabajos programados: $([[ -f "$CRON_FILE" ]] && echo "OK" || echo "FALTANTE")"
            ;;

        *)
            echo "Uso: $0 {setup|daily|weekly|monthly|cleanup|verify|status}"
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"