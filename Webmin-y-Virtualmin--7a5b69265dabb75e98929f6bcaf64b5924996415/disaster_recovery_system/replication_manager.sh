#!/bin/bash

# GESTOR DE REPLICACIÓN EN TIEMPO REAL
# Maneja la replicación automática de datos para el sistema DR

set -euo pipefail
IFS=$'\n\t'

# Cargar configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/dr_config.conf"
source "$CONFIG_FILE"

# Variables globales
LOG_FILE="$LOG_DIR/replication_manager.log"
PID_FILE="$DR_ROOT_DIR/replication.pid"
SYNC_STATUS_FILE="$DR_ROOT_DIR/sync_status.json"

# Funciones de logging
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [REPLICATION] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [REPLICATION-ERROR] $*" >&2 | tee -a "$LOG_FILE"
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [REPLICATION-SUCCESS] $*" | tee -a "$LOG_FILE"
}

# Función para verificar conectividad con servidor secundario
check_secondary_connectivity() {
    log_info "Verificando conectividad con servidor secundario: $SECONDARY_SERVER"

    if ping -c 3 -W 5 "$SECONDARY_SERVER" &>/dev/null; then
        log_success "Conectividad con servidor secundario verificada"
        return 0
    else
        log_error "No se puede conectar al servidor secundario: $SECONDARY_SERVER"
        return 1
    fi
}

# Función para configurar rsync daemon
setup_rsync_daemon() {
    log_info "Configurando rsync daemon para replicación..."

    local rsyncd_conf="/etc/rsyncd.conf"
    local rsyncd_secrets="/etc/rsyncd.secrets"

    # Crear configuración de rsync si no existe
    if [[ ! -f "$rsyncd_conf" ]]; then
        cat > "$rsyncd_conf" << EOF
# Configuración de rsync para DR
pid file = /var/run/rsyncd.pid
lock file = /var/run/rsync.lock
log file = /var/log/rsyncd.log

[dr_replication]
    path = /
    comment = Disaster Recovery Replication
    uid = root
    gid = root
    read only = false
    auth users = $REPLICATION_USER
    secrets file = $rsyncd_secrets
    hosts allow = $PRIMARY_SERVER, $SECONDARY_SERVER
    hosts deny = *
EOF
        chmod 600 "$rsyncd_conf"
    fi

    # Crear archivo de secrets
    if [[ ! -f "$rsyncd_secrets" ]]; then
        echo "$REPLICATION_USER:dr_replication_password" > "$rsyncd_secrets"
        chmod 600 "$rsyncd_secrets"
    fi

    # Iniciar rsync daemon
    if ! pgrep -x rsync &>/dev/null; then
        systemctl enable rsync &>/dev/null || true
        systemctl start rsync &>/dev/null || rsync --daemon
        log_success "Rsync daemon configurado e iniciado"
    else
        log_info "Rsync daemon ya está ejecutándose"
    fi
}

# Función para configurar SSH para replicación
setup_ssh_replication() {
    log_info "Configurando SSH para replicación segura..."

    local ssh_key="$DR_ROOT_DIR/ssh/dr_replication_key"

    mkdir -p "$DR_ROOT_DIR/ssh"

    # Generar clave SSH si no existe
    if [[ ! -f "${ssh_key}" ]]; then
        ssh-keygen -t rsa -b 4096 -f "$ssh_key" -N "" -C "DR Replication Key"
        chmod 600 "${ssh_key}"
        chmod 644 "${ssh_key}.pub"
        log_success "Clave SSH generada para replicación"
    fi

    # Copiar clave pública al servidor secundario (requiere configuración manual inicial)
    log_info "IMPORTANTE: Copie la clave pública al servidor secundario:"
    echo "ssh-copy-id -i ${ssh_key}.pub $REPLICATION_USER@$SECONDARY_SERVER"
}

# Función para replicación inicial (full sync)
initial_replication() {
    log_info "Iniciando replicación inicial completa..."

    if ! check_secondary_connectivity; then
        return 1
    fi

    local start_time=$(date +%s)

    for dir in "${REALTIME_REPLICATION_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            log_info "Replicando directorio: $dir"

            # Crear comando rsync con opciones optimizadas
            local rsync_cmd=(
                rsync -avz --delete
                --exclude-from=<(printf '%s\n' "${REPLICATION_EXCLUDES[@]}")
                --bwlimit=5000  # Limitar ancho de banda a 5MB/s
                --timeout=300
                --stats
            )

            # Añadir compresión si está habilitada
            if [[ "$COMPRESSION_ENABLED" == "true" ]]; then
                rsync_cmd+=(--compress)
            fi

            # Ejecutar replicación
            if "${rsync_cmd[@]}" "$dir" "$REPLICATION_USER@$SECONDARY_SERVER:$dir" 2>>"$LOG_FILE"; then
                log_success "Directorio replicado exitosamente: $dir"
            else
                log_error "Error replicando directorio: $dir"
                return 1
            fi
        else
            log_warning "Directorio no existe, omitiendo: $dir"
        fi
    done

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_success "Replicación inicial completada en ${duration}s"

    # Actualizar estado de sincronización
    update_sync_status "initial_sync_completed" "$(date -Iseconds)"
}

# Función para replicación incremental en tiempo real
incremental_replication() {
    log_info "Iniciando replicación incremental en tiempo real..."

    if ! check_secondary_connectivity; then
        return 1
    fi

    # Usar inotifywait para monitoreo en tiempo real (si está disponible)
    if command -v inotifywait &>/dev/null; then
        log_info "Usando inotify para replicación en tiempo real"

        # Monitorear cambios en directorios críticos
        while true; do
            for dir in "${REALTIME_REPLICATION_DIRS[@]}"; do
                if [[ -d "$dir" ]]; then
                    inotifywait -r -e modify,create,delete,move "$dir" --timeout 60 2>/dev/null | while read -r directory events filename; do
                        if [[ -n "$filename" ]]; then
                            log_info "Cambio detectado: $events $directory$filename"

                            # Replicar el archivo/directorio específico
                            rsync -az --delete "$directory$filename" "$REPLICATION_USER@$SECONDARY_SERVER:$directory$filename" 2>>"$LOG_FILE" || true
                        fi
                    done
                fi
            done

            # Verificación periódica completa cada hora
            if [[ $(date +%M) == "00" ]]; then
                log_info "Ejecutando verificación completa horaria..."
                verify_replication
            fi
        done
    else
        # Fallback: replicación periódica cada 5 minutos
        log_info "Inotify no disponible, usando replicación periódica"

        while true; do
            for dir in "${REALTIME_REPLICATION_DIRS[@]}"; do
                if [[ -d "$dir" ]]; then
                    rsync -az --delete --exclude-from=<(printf '%s\n' "${REPLICATION_EXCLUDES[@]}") \
                        "$dir" "$REPLICATION_USER@$SECONDARY_SERVER:$dir" 2>>"$LOG_FILE" || true
                fi
            done

            update_sync_status "incremental_sync" "$(date -Iseconds)"
            sleep 300  # 5 minutos
        done
    fi
}

# Función para verificar integridad de replicación
verify_replication() {
    log_info "Verificando integridad de replicación..."

    local verification_errors=0

    for dir in "${REALTIME_REPLICATION_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            log_info "Verificando directorio: $dir"

            # Comparar checksums
            local local_checksum
            local remote_checksum

            local_checksum=$(find "$dir" -type f "${REPLICATION_EXCLUDES[@]/#/-not -path \"*\"}" -exec sha256sum {} \; | sort | sha256sum | cut -d' ' -f1)
            remote_checksum=$(ssh "$REPLICATION_USER@$SECONDARY_SERVER" "find '$dir' -type f ${REPLICATION_EXCLUDES[@]/#/-not -path \"*\"} -exec sha256sum {} \;" | sort | sha256sum | cut -d' ' -f1)

            if [[ "$local_checksum" == "$remote_checksum" ]]; then
                log_success "Verificación exitosa: $dir"
            else
                log_error "Verificación fallida: $dir"
                verification_errors=$((verification_errors + 1))
            fi
        fi
    done

    if [[ $verification_errors -eq 0 ]]; then
        update_sync_status "verification_passed" "$(date -Iseconds)"
        log_success "Verificación de replicación completada exitosamente"
        return 0
    else
        update_sync_status "verification_failed" "$(date -Iseconds)"
        log_error "Verificación de replicación fallida: $verification_errors errores"
        return 1
    fi
}

# Función para actualizar estado de sincronización
update_sync_status() {
    local status=$1
    local timestamp=$2

    cat > "$SYNC_STATUS_FILE" << EOF
{
    "replication_status": "$status",
    "last_sync": "$timestamp",
    "primary_server": "$PRIMARY_SERVER",
    "secondary_server": "$SECONDARY_SERVER",
    "replication_method": "$REPLICATION_METHOD",
    "replication_type": "$REPLICATION_TYPE"
}
EOF
}

# Función para replicación de base de datos
database_replication() {
    log_info "Configurando replicación de base de datos..."

    case "$REPLICATION_METHOD" in
        "mysql_replication")
            setup_mysql_replication
            ;;
        "postgresql_replication")
            setup_postgresql_replication
            ;;
        *)
            log_info "Replicación de base de datos no configurada para: $REPLICATION_METHOD"
            ;;
    esac
}

# Función para configurar replicación MySQL
setup_mysql_replication() {
    log_info "Configurando replicación MySQL..."

    # Verificar que MySQL esté ejecutándose
    if ! systemctl is-active --quiet mysql; then
        log_error "MySQL no está ejecutándose"
        return 1
    fi

    # Configurar servidor maestro
    mysql -e "
        STOP SLAVE;
        RESET SLAVE ALL;
        CHANGE MASTER TO
            MASTER_HOST='$SECONDARY_SERVER',
            MASTER_USER='replication_user',
            MASTER_PASSWORD='replication_password',
            MASTER_LOG_FILE='mysql-bin.000001',
            MASTER_LOG_POS=1;
        START SLAVE;
    "

    log_success "Replicación MySQL configurada"
}

# Función para configurar replicación PostgreSQL
setup_postgresql_replication() {
    log_info "Configurando replicación PostgreSQL..."

    # Configurar streaming replication
    cat >> "/etc/postgresql/13/main/postgresql.conf" << EOF
# Configuración de replicación DR
wal_level = replica
max_wal_senders = 3
wal_keep_segments = 64
EOF

    systemctl reload postgresql

    log_success "Replicación PostgreSQL configurada"
}

# Función para iniciar replicación
start_replication() {
    log_info "Iniciando servicios de replicación..."

    # Verificar conectividad
    if ! check_secondary_connectivity; then
        return 1
    fi

    # Configurar rsync daemon
    setup_rsync_daemon

    # Configurar SSH
    setup_ssh_replication

    # Replicación inicial si es la primera vez
    if [[ ! -f "$SYNC_STATUS_FILE" ]]; then
        initial_replication
    fi

    # Configurar replicación de base de datos
    database_replication

    # Iniciar replicación incremental en background
    incremental_replication &
    echo $! > "$PID_FILE"

    update_sync_status "active" "$(date -Iseconds)"

    log_success "Replicación iniciada exitosamente"
}

# Función para detener replicación
stop_replication() {
    log_info "Deteniendo servicios de replicación..."

    # Detener procesos de replicación
    if [[ -f "$PID_FILE" ]]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi

    # Detener rsync daemon
    systemctl stop rsync 2>/dev/null || pkill rsync

    update_sync_status "stopped" "$(date -Iseconds)"

    log_success "Replicación detenida"
}

# Función para mostrar estado de replicación
show_replication_status() {
    echo "=========================================="
    echo "  ESTADO DE REPLICACIÓN"
    echo "=========================================="

    if [[ -f "$SYNC_STATUS_FILE" ]]; then
        cat "$SYNC_STATUS_FILE" | jq . 2>/dev/null || cat "$SYNC_STATUS_FILE"
    else
        echo "Replicación no configurada"
    fi

    echo
    echo "Procesos de replicación activos:"
    pgrep -f "replication_manager.sh" | wc -l | xargs echo "Procesos:"

    echo
    echo "Últimos logs de replicación:"
    tail -10 "$LOG_FILE" 2>/dev/null || echo "No hay logs disponibles"
}

# Función principal
main() {
    local action=${1:-"status"}

    echo "=========================================="
    echo "  GESTOR DE REPLICACIÓN EN TIEMPO REAL"
    echo "=========================================="
    echo

    case "$action" in
        "start")
            start_replication
            ;;

        "stop")
            stop_replication
            ;;

        "verify")
            verify_replication
            ;;

        "initial")
            initial_replication
            ;;

        "status")
            show_replication_status
            ;;

        "setup")
            setup_rsync_daemon
            setup_ssh_replication
            log_success "Configuración de replicación completada"
            ;;

        *)
            echo "Uso: $0 {start|stop|verify|initial|status|setup}"
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"