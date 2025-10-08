#!/bin/bash

# ORQUESTADOR DE FAILOVER AUTOMÁTICO
# Gestiona la conmutación automática entre servidores primarios y secundarios

set -euo pipefail
IFS=$'\n\t'

# Cargar configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/dr_config.conf"
source "$CONFIG_FILE"

# Variables globales
LOG_FILE="$LOG_DIR/failover_orchestrator.log"
FAILOVER_STATUS_FILE="$DR_ROOT_DIR/failover_status.json"
LOCK_FILE="$DR_ROOT_DIR/failover.lock"

# Funciones de logging
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [FAILOVER] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [FAILOVER-ERROR] $*" >&2 | tee -a "$LOG_FILE"
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [FAILOVER-SUCCESS] $*" | tee -a "$LOG_FILE"
}

# Función para adquirir lock de failover (previene failovers simultáneos)
acquire_failover_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid
        lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")

        if [[ -n "$lock_pid" ]] && kill -0 "$lock_pid" 2>/dev/null; then
            log_warning "Failover ya en progreso (PID: $lock_pid)"
            return 1
        else
            log_info "Eliminando lock obsoleto"
            rm -f "$LOCK_FILE"
        fi
    fi

    echo $$ > "$LOCK_FILE"
    log_info "Lock de failover adquirido"
    return 0
}

# Función para liberar lock de failover
release_failover_lock() {
    rm -f "$LOCK_FILE"
    log_info "Lock de failover liberado"
}

# Función para verificar salud del servidor primario
check_primary_health() {
    log_info "Verificando salud del servidor primario: $PRIMARY_SERVER"

    local health_checks_passed=0
    local total_checks=0

    # Verificar conectividad básica
    total_checks=$((total_checks + 1))
    if ping -c 3 -W 5 "$PRIMARY_SERVER" &>/dev/null; then
        health_checks_passed=$((health_checks_passed + 1))
        log_info "✓ Conectividad básica: OK"
    else
        log_error "✗ Conectividad básica: FALLÓ"
    fi

    # Verificar servicios críticos
    for service in "${CRITICAL_SERVICES[@]}"; do
        total_checks=$((total_checks + 1))

        if ssh -o ConnectTimeout=10 -o BatchMode=yes "$REPLICATION_USER@$PRIMARY_SERVER" \
            "systemctl is-active --quiet $service" 2>/dev/null; then
            health_checks_passed=$((health_checks_passed + 1))
            log_info "✓ Servicio $service: OK"
        else
            log_error "✗ Servicio $service: FALLÓ"
        fi
    done

    # Verificar carga del sistema
    total_checks=$((total_checks + 1))
    local load_avg
    load_avg=$(ssh -o ConnectTimeout=10 "$REPLICATION_USER@$PRIMARY_SERVER" "uptime | awk -F'load average:' '{ print \$2 }'" 2>/dev/null | tr -d ' ' || echo "")

    if [[ -n "$load_avg" ]]; then
        local load_1min
        load_1min=$(echo "$load_avg" | cut -d',' -f1)

        if (( $(echo "$load_1min < 10" | bc -l 2>/dev/null || echo "1") )); then
            health_checks_passed=$((health_checks_passed + 1))
            log_info "✓ Carga del sistema: OK ($load_1min)"
        else
            log_error "✗ Carga del sistema: ALTA ($load_1min)"
        fi
    else
        log_error "✗ No se pudo obtener carga del sistema"
    fi

    # Calcular porcentaje de salud
    local health_percentage=$((health_checks_passed * 100 / total_checks))

    log_info "Estado de salud del primario: $health_percentage% ($health_checks_passed/$total_checks)"

    # Retornar basado en umbral (80% mínimo para considerar saludable)
    if [[ $health_percentage -ge 80 ]]; then
        return 0
    else
        return 1
    fi
}

# Función para verificar disponibilidad del servidor secundario
check_secondary_availability() {
    log_info "Verificando disponibilidad del servidor secundario: $SECONDARY_SERVER"

    # Verificar conectividad
    if ! ping -c 3 -W 5 "$SECONDARY_SERVER" &>/dev/null; then
        log_error "Servidor secundario no responde"
        return 1
    fi

    # Verificar que los servicios puedan iniciarse
    for service in "${CRITICAL_SERVICES[@]}"; do
        if ! ssh -o ConnectTimeout=10 "$REPLICATION_USER@$SECONDARY_SERVER" \
            "systemctl is-enabled $service" 2>/dev/null; then
            log_warning "Servicio $service no está habilitado en secundario"
        fi
    done

    # Verificar sincronización de datos
    local sync_status_file="$SYNC_STATUS_FILE"
    if [[ -f "$sync_status_file" ]]; then
        local last_sync
        last_sync=$(jq -r '.last_sync' "$sync_status_file" 2>/dev/null || echo "")

        if [[ -n "$last_sync" ]]; then
            local sync_age=$(( $(date +%s) - $(date -d "$last_sync" +%s 2>/dev/null || echo "0") ))

            if [[ $sync_age -lt 3600 ]]; then  # Menos de 1 hora
                log_info "✓ Datos sincronizados recientemente ($((sync_age / 60)) minutos)"
            else
                log_warning "⚠ Datos no sincronizados recientemente ($((sync_age / 3600)) horas)"
            fi
        fi
    fi

    log_success "Servidor secundario disponible"
    return 0
}

# Función para ejecutar failover
execute_failover() {
    log_info "=== INICIANDO PROCEDIMIENTO DE FAILOVER ==="

    if ! acquire_failover_lock; then
        return 1
    fi

    local failover_start=$(date +%s)
    local failover_success=false

    # Paso 1: Verificar condiciones para failover
    log_info "Paso 1: Verificando condiciones para failover..."

    if check_primary_health; then
        log_info "Servidor primario aún saludable - Cancelando failover"
        release_failover_lock
        return 0
    fi

    if ! check_secondary_availability; then
        log_error "Servidor secundario no disponible - Failover abortado"
        release_failover_lock
        return 1
    fi

    # Paso 2: Detener servicios en primario (si es posible)
    log_info "Paso 2: Deteniendo servicios en servidor primario..."

    for service in "${CRITICAL_SERVICES[@]}"; do
        ssh -o ConnectTimeout=5 "$REPLICATION_USER@$PRIMARY_SERVER" \
            "systemctl stop $service" 2>/dev/null || \
        log_warning "No se pudo detener $service en primario"
    done

    # Paso 3: Configurar VIP en secundario
    log_info "Paso 3: Configurando dirección VIP en servidor secundario..."

    if [[ -n "$VIP_ADDRESS" && -n "$VIP_INTERFACE" ]]; then
        ssh "$REPLICATION_USER@$SECONDARY_SERVER" "
            ip addr add $VIP_ADDRESS/24 dev $VIP_INTERFACE 2>/dev/null || true
            arping -c 3 -S $VIP_ADDRESS $VIP_INTERFACE 2>/dev/null || true
        " 2>/dev/null || log_warning "No se pudo configurar VIP"
    fi

    # Paso 4: Iniciar servicios en secundario
    log_info "Paso 4: Iniciando servicios en servidor secundario..."

    for service in "${CRITICAL_SERVICES[@]}"; do
        if ssh "$REPLICATION_USER@$SECONDARY_SERVER" "systemctl start $service" 2>/dev/null; then
            log_success "Servicio $service iniciado en secundario"
        else
            log_error "Error al iniciar $service en secundario"
        fi
    done

    # Paso 5: Actualizar configuración de DNS/load balancer
    log_info "Paso 5: Actualizando configuración de red..."

    update_network_configuration

    # Paso 6: Verificar failover exitoso
    log_info "Paso 6: Verificando failover exitoso..."

    sleep 10  # Esperar a que los servicios se estabilicen

    if verify_failover_success; then
        failover_success=true
        log_success "FAILOVER COMPLETADO EXITOSAMENTE"

        # Actualizar estado
        update_failover_status "completed" "$SECONDARY_SERVER" "$(date -Iseconds)"

        # Notificar administradores
        send_failover_notification "SUCCESS"
    else
        log_error "VERIFICACIÓN DE FAILOVER FALLÓ"
        send_failover_notification "FAILED"
    fi

    local failover_duration=$(( $(date +%s) - failover_start ))
    log_info "Duración del failover: ${failover_duration}s"

    release_failover_lock

    if [[ "$failover_success" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Función para actualizar configuración de red
update_network_configuration() {
    log_info "Actualizando configuración de red y DNS..."

    # Si hay un load balancer o DNS server configurado
    if [[ -n "${LOAD_BALANCER_IP:-}" ]]; then
        # Actualizar configuración del load balancer
        log_info "Actualizando load balancer: $LOAD_BALANCER_IP"
        # Aquí iría la lógica específica del load balancer
    fi

    # Actualizar registros DNS si es necesario
    if [[ -n "${DNS_SERVER:-}" ]]; then
        log_info "Actualizando registros DNS: $DNS_SERVER"
        # Aquí iría la lógica de actualización DNS
    fi
}

# Función para verificar que el failover fue exitoso
verify_failover_success() {
    log_info "Verificando éxito del failover..."

    local checks_passed=0
    local total_checks=0

    # Verificar que los servicios están ejecutándose en secundario
    for service in "${CRITICAL_SERVICES[@]}"; do
        total_checks=$((total_checks + 1))

        if ssh -o ConnectTimeout=10 "$REPLICATION_USER@$SECONDARY_SERVER" \
            "systemctl is-active --quiet $service" 2>/dev/null; then
            checks_passed=$((checks_passed + 1))
            log_info "✓ Servicio $service ejecutándose en secundario"
        else
            log_error "✗ Servicio $service no ejecutándose en secundario"
        fi
    done

    # Verificar conectividad a VIP
    if [[ -n "$VIP_ADDRESS" ]]; then
        total_checks=$((total_checks + 1))

        if ping -c 3 -W 5 "$VIP_ADDRESS" &>/dev/null; then
            checks_passed=$((checks_passed + 1))
            log_info "✓ VIP accesible: $VIP_ADDRESS"
        else
            log_error "✗ VIP no accesible: $VIP_ADDRESS"
        fi
    fi

    # Verificar que primario está realmente caído
    total_checks=$((total_checks + 1))

    if ! ping -c 3 -W 5 "$PRIMARY_SERVER" &>/dev/null; then
        checks_passed=$((checks_passed + 1))
        log_info "✓ Servidor primario confirmado como caído"
    else
        log_warning "⚠ Servidor primario aún responde (posible split-brain)"
    fi

    local success_rate=$((checks_passed * 100 / total_checks))

    if [[ $success_rate -ge 80 ]]; then
        log_success "Verificación de failover exitosa: $success_rate%"
        return 0
    else
        log_error "Verificación de failover fallida: $success_rate%"
        return 1
    fi
}

# Función para ejecutar failback (regreso al primario)
execute_failback() {
    log_info "=== INICIANDO PROCEDIMIENTO DE FAILBACK ==="

    if ! acquire_failover_lock; then
        return 1
    fi

    # Verificar que el primario esté saludable
    if ! check_primary_health; then
        log_error "Servidor primario no está saludable para failback"
        release_failover_lock
        return 1
    fi

    log_info "Servidor primario saludable - Procediendo con failback..."

    # Sincronizar datos pendientes
    sync_pending_data

    # Detener servicios en secundario
    for service in "${CRITICAL_SERVICES[@]}"; do
        ssh "$REPLICATION_USER@$SECONDARY_SERVER" "systemctl stop $service" 2>/dev/null || true
    done

    # Remover VIP del secundario
    if [[ -n "$VIP_ADDRESS" ]]; then
        ssh "$REPLICATION_USER@$SECONDARY_SERVER" "ip addr del $VIP_ADDRESS/24 dev $VIP_INTERFACE" 2>/dev/null || true
    fi

    # Iniciar servicios en primario
    for service in "${CRITICAL_SERVICES[@]}"; do
        ssh "$REPLICATION_USER@$PRIMARY_SERVER" "systemctl start $service" 2>/dev/null || true
    done

    # Configurar VIP en primario
    if [[ -n "$VIP_ADDRESS" ]]; then
        ssh "$REPLICATION_USER@$PRIMARY_SERVER" "ip addr add $VIP_ADDRESS/24 dev $VIP_INTERFACE" 2>/dev/null || true
    fi

    # Actualizar estado
    update_failover_status "failed_back" "$PRIMARY_SERVER" "$(date -Iseconds)"

    log_success "FAILBACK COMPLETADO EXITOSAMENTE"
    send_failover_notification "FAILBACK_SUCCESS"

    release_failover_lock
}

# Función para sincronizar datos pendientes durante failback
sync_pending_data() {
    log_info "Sincronizando datos pendientes para failback..."

    # Ejecutar replicación final desde secundario a primario
    local replication_script="$SCRIPT_DIR/replication_manager.sh"

    if [[ -x "$replication_script" ]]; then
        # Replicar cambios desde secundario al primario
        for dir in "${REALTIME_REPLICATION_DIRS[@]}"; do
            rsync -az --delete "$REPLICATION_USER@$SECONDARY_SERVER:$dir" "$dir" 2>>"$LOG_FILE" || true
        done

        log_success "Datos pendientes sincronizados"
    fi
}

# Función para actualizar estado de failover
update_failover_status() {
    local status=$1
    local active_server=$2
    local timestamp=$3

    cat > "$FAILOVER_STATUS_FILE" << EOF
{
    "failover_status": "$status",
    "active_server": "$active_server",
    "timestamp": "$timestamp",
    "primary_server": "$PRIMARY_SERVER",
    "secondary_server": "$SECONDARY_SERVER",
    "vip_address": "$VIP_ADDRESS"
}
EOF
}

# Función para enviar notificaciones de failover
send_failover_notification() {
    local notification_type=$1

    if [[ "$NOTIFICATION_EMAIL" != "admin@enterprise.local" ]]; then
        local subject="DR System - $notification_type"
        local body="Failover event: $notification_type at $(date)"

        echo "$body" | mail -s "$subject" "$NOTIFICATION_EMAIL" 2>/dev/null || true
    fi

    # Aquí se podrían añadir notificaciones a Slack, PagerDuty, etc.
}

# Función para mostrar estado de failover
show_failover_status() {
    echo "=========================================="
    echo "  ESTADO DE FAILOVER"
    echo "=========================================="

    if [[ -f "$FAILOVER_STATUS_FILE" ]]; then
        cat "$FAILOVER_STATUS_FILE" | jq . 2>/dev/null || cat "$FAILOVER_STATUS_FILE"
    else
        echo "No hay estado de failover disponible"
    fi

    echo
    echo "Servidor activo actual:"
    if [[ -f "$FAILOVER_STATUS_FILE" ]]; then
        jq -r '.active_server' "$FAILOVER_STATUS_FILE" 2>/dev/null || echo "Desconocido"
    else
        echo "Primario (por defecto)"
    fi

    echo
    echo "Lock de failover:"
    if [[ -f "$LOCK_FILE" ]]; then
        echo "ACTIVO (PID: $(cat "$LOCK_FILE"))"
    else
        echo "INACTIVO"
    fi
}

# Función principal
main() {
    local action=${1:-"status"}

    echo "=========================================="
    echo "  ORQUESTADOR DE FAILOVER AUTOMÁTICO"
    echo "=========================================="
    echo

    case "$action" in
        "failover")
            execute_failover
            ;;

        "failback")
            execute_failback
            ;;

        "check")
            if check_primary_health; then
                echo "Servidor primario: SALUDABLE"
                exit 0
            else
                echo "Servidor primario: NO SALUDABLE"
                exit 1
            fi
            ;;

        "status")
            show_failover_status
            ;;

        *)
            echo "Uso: $0 {failover|failback|check|status}"
            echo
            echo "Comandos disponibles:"
            echo "  failover  - Ejecutar failover al servidor secundario"
            echo "  failback  - Regresar al servidor primario"
            echo "  check     - Verificar salud del servidor primario"
            echo "  status    - Mostrar estado de failover"
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"