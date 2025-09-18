#!/bin/bash

# Script de Backup Multi-Cloud
# Sistema de backups con soporte para múltiples proveedores cloud
# Versión: 1.0.0 - Base para futuras integraciones

set -euo pipefail
IFS=$'\n\t'

# Directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== INCLUIR BIBLIOTECA COMÚN =====
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
    source "${SCRIPT_DIR}/lib/common.sh"
else
    echo "ERROR: No se encuentra la biblioteca común en ${SCRIPT_DIR}/lib/common.sh"
    exit 1
fi

# Configuración de backups
BACKUP_DIR="${BACKUP_DIR:-/backups}"
BACKUP_RETENTION="${BACKUP_RETENTION:-30}"
BACKUP_COMPRESSION="${BACKUP_COMPRESSION:-gzip}"
TIMESTAMP_FORMAT="${TIMESTAMP_FORMAT:-%Y%m%d_%H%M%S}"

# Configuración de proveedores cloud
AWS_ENABLED="${AWS_ENABLED:-false}"
GCP_ENABLED="${GCP_ENABLED:-false}"
AZURE_ENABLED="${AZURE_ENABLED:-false}"

# Función para crear directorio de backups
setup_backup_directory() {
    log_step "Configurando directorio de backups..."

    if [[ ! -d "$BACKUP_DIR" ]]; then
        ensure_directory "$BACKUP_DIR"
        chmod 755 "$BACKUP_DIR"
        log_success "Directorio de backups creado: $BACKUP_DIR"
    else
        log_debug "Directorio de backups ya existe: $BACKUP_DIR"
    fi

    # Verificar permisos de escritura
    if ! check_write_permissions "$BACKUP_DIR"; then
        handle_error "$ERROR_INSTALLATION_FAILED" "No hay permisos de escritura en $BACKUP_DIR"
    fi
}

# Función para generar timestamp
generate_timestamp() {
    date "+$TIMESTAMP_FORMAT"
}

# Función para crear backup de configuración
backup_configuration() {
    log_step "Creando backup de configuración..."

    local timestamp
    timestamp=$(generate_timestamp)
    local config_backup="${BACKUP_DIR}/config_backup_${timestamp}.tar"

    # Archivos de configuración a respaldar
    local config_files=(
        "/etc/webmin"
        "/etc/virtualmin"
        "/etc/apache2"
        "/etc/mysql"
        "/etc/postfix"
        "/etc/dovecot"
        "/etc/fail2ban"
        "/etc/ufw"
    )

    local temp_dir
    temp_dir=$(mktemp -d)

    # Copiar archivos de configuración
    for config_file in "${config_files[@]}"; do
        if [[ -e "$config_file" ]]; then
            cp -r "$config_file" "$temp_dir/" 2>/dev/null || {
                log_warning "No se pudo copiar $config_file"
                continue
            }
        fi
    done

    # Crear archivo comprimido
    if [[ "$BACKUP_COMPRESSION" == "gzip" ]]; then
        tar -czf "${config_backup}.gz" -C "$temp_dir" .
        config_backup="${config_backup}.gz"
    elif [[ "$BACKUP_COMPRESSION" == "bzip2" ]]; then
        tar -cjf "${config_backup}.bz2" -C "$temp_dir" .
        config_backup="${config_backup}.bz2"
    else
        tar -cf "$config_backup" -C "$temp_dir" .
    fi

    # Limpiar directorio temporal
    rm -rf "$temp_dir"

    log_success "Backup de configuración creado: $config_backup"
    echo "$config_backup"
}

# Función para crear backup de bases de datos
backup_databases() {
    log_step "Creando backup de bases de datos..."

    local timestamp
    timestamp=$(generate_timestamp)
    local db_backup="${BACKUP_DIR}/database_backup_${timestamp}.sql"

    if ! command_exists mysql; then
        log_warning "MySQL no está instalado, omitiendo backup de bases de datos"
        return 1
    fi

    # Obtener lista de bases de datos (excluyendo las del sistema)
    local databases
    databases=$(mysql -e "SHOW DATABASES;" | grep -v -E "(Database|information_schema|performance_schema|mysql|sys)")

    if [[ -z "$databases" ]]; then
        log_warning "No se encontraron bases de datos para respaldar"
        return 1
    fi

    # Crear backup de todas las bases de datos
    mysqldump --all-databases --routines --triggers > "$db_backup" 2>/dev/null || {
        handle_error "$ERROR_DATABASE_SETUP_FAILED" "Error al crear backup de bases de datos"
    }

    # Comprimir si está habilitado
    if [[ "$BACKUP_COMPRESSION" == "gzip" ]]; then
        gzip "$db_backup"
        db_backup="${db_backup}.gz"
    fi

    log_success "Backup de bases de datos creado: $db_backup"
    echo "$db_backup"
}

# Función para subir backup a AWS S3
upload_to_aws() {
    local file_path="$1"
    local s3_bucket="${AWS_S3_BUCKET:-virtualmin-backups}"
    local s3_path="${AWS_S3_PATH:-backups/$(basename "$file_path")}"

    if [[ "$AWS_ENABLED" != "true" ]]; then
        return 0
    fi

    log_step "Subiendo backup a AWS S3..."

    if ! command_exists aws; then
        log_warning "AWS CLI no está instalado, omitiendo subida a S3"
        return 1
    fi

    # Verificar configuración de AWS
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_warning "AWS CLI no está configurado, omitiendo subida a S3"
        return 1
    fi

    # Subir archivo
    if aws s3 cp "$file_path" "s3://$s3_bucket/$s3_path" --storage-class STANDARD_IA; then
        log_success "Backup subido a AWS S3: s3://$s3_bucket/$s3_path"
        return 0
    else
        log_error "Error al subir backup a AWS S3"
        return 1
    fi
}

# Función para subir backup a Google Cloud Storage
upload_to_gcp() {
    local file_path="$1"
    local gcp_bucket="${GCP_BUCKET:-virtualmin-backups}"
    local gcp_path="${GCP_PATH:-backups/$(basename "$file_path")}"

    if [[ "$GCP_ENABLED" != "true" ]]; then
        return 0
    fi

    log_step "Subiendo backup a Google Cloud Storage..."

    if ! command_exists gsutil; then
        log_warning "gsutil no está instalado, omitiendo subida a GCS"
        return 1
    fi

    # Verificar autenticación
    if ! gsutil ls "gs://$gcp_bucket" >/dev/null 2>&1; then
        log_warning "gsutil no está autenticado, omitiendo subida a GCS"
        return 1
    fi

    # Subir archivo
    if gsutil cp "$file_path" "gs://$gcp_bucket/$gcp_path"; then
        log_success "Backup subido a GCS: gs://$gcp_bucket/$gcp_path"
        return 0
    else
        log_error "Error al subir backup a GCS"
        return 1
    fi
}

# Función para limpiar backups antiguos
cleanup_old_backups() {
    log_step "Limpiando backups antiguos..."

    local backup_files
    backup_files=$(find "$BACKUP_DIR" -name "*.tar*" -o -name "*.sql*" -o -name "*.gz" -o -name "*.bz2" | wc -l)

    if [[ $backup_files -gt $BACKUP_RETENTION ]]; then
        log_info "Eliminando backups antiguos (retención: $BACKUP_RETENTION días)..."

        # Encontrar y eliminar archivos antiguos
        find "$BACKUP_DIR" -name "*.tar*" -o -name "*.sql*" -o -name "*.gz" -o -name "*.bz2" \
             -mtime +"$BACKUP_RETENTION" -delete 2>/dev/null || true

        log_success "Backups antiguos eliminados"
    else
        log_debug "No hay backups antiguos para eliminar"
    fi
}

# Función para mostrar resumen del backup
show_backup_summary() {
    local config_backup="$1"
    local db_backup="$2"
    local total_size=0

    log_success "=== RESUMEN DEL BACKUP ==="

    echo
    echo "Archivos creados:"
    if [[ -n "$config_backup" ]]; then
        local config_size
        config_size=$(du -sh "$config_backup" | awk '{print $1}')
        echo "  📁 Configuración: $config_backup ($config_size)"
        total_size=$((total_size + $(du -k "$config_backup" | awk '{print $1}')))
    fi

    if [[ -n "$db_backup" ]]; then
        local db_size
        db_size=$(du -sh "$db_backup" | awk '{print $1}')
        echo "  🗄️  Base de datos: $db_backup ($db_size)"
        total_size=$((total_size + $(du -k "$db_backup" | awk '{print $1}')))
    fi

    echo
    echo "Tamaño total: $((total_size / 1024)) MB"
    echo "Ubicación: $BACKUP_DIR"
    echo "Retención: $BACKUP_RETENTION días"
    echo

    # Mostrar estado de subida a la nube
    if [[ "$AWS_ENABLED" == "true" ]] || [[ "$GCP_ENABLED" == "true" ]] || [[ "$AZURE_ENABLED" == "true" ]]; then
        echo "Subida a la nube:"
        [[ "$AWS_ENABLED" == "true" ]] && echo "  ☁️  AWS S3: Habilitado"
        [[ "$GCP_ENABLED" == "true" ]] && echo "  ☁️  Google Cloud: Habilitado"
        [[ "$AZURE_ENABLED" == "true" ]] && echo "  ☁️  Azure: Habilitado"
        echo
    fi
}

# Función para mostrar ayuda
show_help() {
    cat << EOF
Script de Backup Multi-Cloud - Virtualmin & Webmin
Versión: 1.0.0

USO:
    $0 [opciones]

OPCIONES:
    -c, --config       Crear backup de configuración
    -d, --database     Crear backup de bases de datos
    -a, --all         Crear todos los backups (default)
    -C, --cleanup     Limpiar backups antiguos
    -v, --verbose     Modo verbose
    -h, --help        Mostrar esta ayuda

PROVEEDORES CLOUD:
    AWS S3:
        Configurar variables: AWS_ENABLED=true, AWS_S3_BUCKET=nombre
        Instalar: pip install awscli
        Configurar: aws configure

    Google Cloud Storage:
        Configurar variables: GCP_ENABLED=true, GCP_BUCKET=nombre
        Instalar: pip install gsutil
        Autenticar: gcloud auth login

VARIABLES DE ENTORNO:
    BACKUP_DIR          Directorio de backups (default: /backups)
    BACKUP_RETENTION    Días de retención (default: 30)
    BACKUP_COMPRESSION  Compresión: gzip|bzip2|none (default: gzip)

EJEMPLOS:
    $0                          # Backup completo
    $0 -c -d                    # Solo configuración y BD
    $0 --all --cleanup          # Backup completo + limpiar antiguos

ARCHIVOS DE LOG:
    /var/log/virtualmin_backup.log     # Logs de backups

NOTAS:
    - Requiere permisos de root para acceso completo
    - Los backups se almacenan en \$BACKUP_DIR
    - Configurar variables de entorno para proveedores cloud
EOF
}

# Función principal
main() {
    local do_config=false
    local do_database=false
    local do_cleanup=false

    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config) do_config=true ;;
            -d|--database) do_database=true ;;
            -a|--all) do_config=true; do_database=true ;;
            -C|--cleanup) do_cleanup=true ;;
            -v|--verbose) set -x ;;
            -h|--help) show_help; exit 0 ;;
            *) log_error "Opción desconocida: $1"; show_help; exit 1 ;;
        esac
        shift
    done

    # Si no se especifica nada, hacer backup completo
    if [[ "$do_config" == "false" ]] && [[ "$do_database" == "false" ]]; then
        do_config=true
        do_database=true
    fi

    echo
    echo "=========================================="
    echo "  SISTEMA DE BACKUP MULTI-CLOUD"
    echo "  Virtualmin & Webmin"
    echo "=========================================="
    echo

    # Verificar permisos
    if [[ $EUID -ne 0 ]]; then
        handle_error "$ERROR_ROOT_REQUIRED" "Este script requiere permisos de root para backups completos"
    fi

    # Configurar directorio de backups
    setup_backup_directory

    local config_backup=""
    local db_backup=""

    # Crear backups según las opciones
    if [[ "$do_config" == "true" ]]; then
        config_backup=$(backup_configuration)
    fi

    if [[ "$do_database" == "true" ]]; then
        db_backup=$(backup_databases)
    fi

    # Subir a proveedores cloud
    for backup_file in "$config_backup" "$db_backup"; do
        if [[ -n "$backup_file" ]] && [[ -f "$backup_file" ]]; then
            upload_to_aws "$backup_file" || true
            upload_to_gcp "$backup_file" || true
        fi
    done

    # Limpiar backups antiguos
    if [[ "$do_cleanup" == "true" ]]; then
        cleanup_old_backups
    fi

    # Mostrar resumen
    show_backup_summary "$config_backup" "$db_backup"

    log_success "Backup completado exitosamente"
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
