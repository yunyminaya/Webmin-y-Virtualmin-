#!/bin/bash

# Coordinador Principal de Sub-Agentes
# Gestiona y coordina todos los sub-agentes del sistema

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/coordinador_sub_agentes.log"
CONFIG_FILE="/etc/webmin/sub_agentes_config.conf"
PID_FILE="/var/run/coordinador_sub_agentes.pid"

# Sub-agentes disponibles
SUBAGENTS=(
    "monitoreo:$SCRIPT_DIR/sub_agente_monitoreo.sh"
    "seguridad:$SCRIPT_DIR/sub_agente_seguridad.sh"
    "backup:$SCRIPT_DIR/sub_agente_backup.sh"
    "actualizaciones:$SCRIPT_DIR/sub_agente_actualizaciones.sh"
    "logs:$SCRIPT_DIR/sub_agente_logs.sh"
    "especialista:$SCRIPT_DIR/sub_agente_especialista_codigo.sh"
    "optimizador:$SCRIPT_DIR/sub_agente_optimizador.sh"
    "ingeniero:$SCRIPT_DIR/sub_agente_ingeniero_codigo.sh"
    "verificador-backup:$SCRIPT_DIR/sub_agente_verificador_backup.sh"
)

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [COORDINADOR] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" | tee -a "$LOG_FILE" >&2
}

check_prerequisites() {
    log_message "=== VERIFICANDO PREREQUISITOS ==="
    
    # Verificar que existan todos los sub-agentes
    local missing_agents=()
    for agent_info in "${SUBAGENTS[@]}"; do
        local agent_name=$(echo "$agent_info" | cut -d':' -f1)
        local agent_script=$(echo "$agent_info" | cut -d':' -f2)
        
        if [ ! -f "$agent_script" ]; then
            missing_agents+=("$agent_name:$agent_script")
            log_error "Sub-agente faltante: $agent_script"
        else
            chmod +x "$agent_script" 2>/dev/null
            log_message "✓ Sub-agente $agent_name disponible"
        fi
    done
    
    if [ ${#missing_agents[@]} -gt 0 ]; then
        log_error "Faltan ${#missing_agents[@]} sub-agentes"
        return 1
    fi
    
    # Crear directorios necesarios
    local required_dirs=(
        "/var/log"
        "/var/backups"
        "/usr/local/webmin/var"
        "/etc/webmin"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir" 2>/dev/null
            log_message "Directorio creado: $dir"
        fi
    done
    
    log_message "Prerequisitos verificados correctamente"
    return 0
}

load_configuration() {
    log_message "=== CARGANDO CONFIGURACIÓN ==="
    
    # Crear configuración por defecto si no existe
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Configuración de Sub-Agentes Webmin/Virtualmin
# Habilitado (true/false) y frecuencia en segundos

# Sub-agente de monitoreo
MONITOREO_ENABLED=true
MONITOREO_INTERVAL=300

# Sub-agente de seguridad
SEGURIDAD_ENABLED=true
SEGURIDAD_INTERVAL=1800

# Sub-agente de backup
BACKUP_ENABLED=true
BACKUP_INTERVAL=86400

# Sub-agente de actualizaciones
ACTUALIZACIONES_ENABLED=true
ACTUALIZACIONES_INTERVAL=604800

# Sub-agente de logs
LOGS_ENABLED=true
LOGS_INTERVAL=3600

# Sub-agente especialista en código
ESPECIALISTA_ENABLED=false
ESPECIALISTA_INTERVAL=604800

# Sub-agente optimizador
OPTIMIZADOR_ENABLED=false
OPTIMIZADOR_INTERVAL=2592000

# Configuración global
ENABLE_ALERTS=true
ALERT_EMAIL=""
PARALLEL_EXECUTION=true
MAX_CONCURRENT_AGENTS=3
EOF
        log_message "Configuración por defecto creada: $CONFIG_FILE"
    fi
    
    # Cargar configuración
    source "$CONFIG_FILE"
    log_message "Configuración cargada desde: $CONFIG_FILE"
}

execute_agent() {
    local agent_name="$1"
    local agent_script="$2"
    local mode="${3:-start}"
    
    log_message "Ejecutando sub-agente: $agent_name (modo: $mode)"
    
    # Verificar si el agente está habilitado
    local enabled_var="${agent_name^^}_ENABLED"
    if [ "${!enabled_var}" != "true" ]; then
        log_message "Sub-agente $agent_name está deshabilitado"
        return 0
    fi
    
    # Ejecutar el sub-agente
    local start_time=$(date +%s)
    
    if "$agent_script" "$mode" >> "$LOG_FILE" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_message "✓ Sub-agente $agent_name completado en ${duration}s"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_error "✗ Sub-agente $agent_name falló después de ${duration}s"
        return 1
    fi
}

execute_all_agents() {
    local mode="${1:-start}"
    log_message "=== EJECUTANDO TODOS LOS SUB-AGENTES (modo: $mode) ==="
    
    local failed_agents=()
    local successful_agents=()
    
    if [ "$PARALLEL_EXECUTION" = "true" ]; then
        log_message "Ejecutando sub-agentes en paralelo (máximo: $MAX_CONCURRENT_AGENTS)"
        
        local pids=()
        local agent_names=()
        
        for agent_info in "${SUBAGENTS[@]}"; do
            local agent_name=$(echo "$agent_info" | cut -d':' -f1)
            local agent_script=$(echo "$agent_info" | cut -d':' -f2)
            
            # Esperar si hay muchos procesos en paralelo
            while [ ${#pids[@]} -ge "$MAX_CONCURRENT_AGENTS" ]; do
                for i in "${!pids[@]}"; do
                    if ! kill -0 "${pids[$i]}" 2>/dev/null; then
                        wait "${pids[$i]}"
                        local exit_code=$?
                        
                        if [ $exit_code -eq 0 ]; then
                            successful_agents+=("${agent_names[$i]}")
                        else
                            failed_agents+=("${agent_names[$i]}")
                        fi
                        
                        unset pids[$i]
                        unset agent_names[$i]
                    fi
                done
                sleep 1
            done
            
            # Ejecutar sub-agente en background
            execute_agent "$agent_name" "$agent_script" "$mode" &
            pids+=($!)
            agent_names+=("$agent_name")
        done
        
        # Esperar a que terminen todos los procesos
        for i in "${!pids[@]}"; do
            wait "${pids[$i]}"
            local exit_code=$?
            
            if [ $exit_code -eq 0 ]; then
                successful_agents+=("${agent_names[$i]}")
            else
                failed_agents+=("${agent_names[$i]}")
            fi
        done
        
    else
        log_message "Ejecutando sub-agentes secuencialmente"
        
        for agent_info in "${SUBAGENTS[@]}"; do
            local agent_name=$(echo "$agent_info" | cut -d':' -f1)
            local agent_script=$(echo "$agent_info" | cut -d':' -f2)
            
            if execute_agent "$agent_name" "$agent_script" "$mode"; then
                successful_agents+=("$agent_name")
            else
                failed_agents+=("$agent_name")
            fi
        done
    fi
    
    # Resumen de ejecución
    log_message "=== RESUMEN DE EJECUCIÓN ==="
    log_message "Sub-agentes exitosos (${#successful_agents[@]}): ${successful_agents[*]}"
    
    if [ ${#failed_agents[@]} -gt 0 ]; then
        log_error "Sub-agentes fallidos (${#failed_agents[@]}): ${failed_agents[*]}"
        return 1
    else
        log_message "Todos los sub-agentes se ejecutaron correctamente"
        return 0
    fi
}

daemon_mode() {
    log_message "=== INICIANDO MODO DAEMON ==="
    
    # Verificar si ya hay una instancia corriendo
    if [ -f "$PID_FILE" ]; then
        local old_pid=$(cat "$PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            log_error "Ya hay una instancia del coordinador corriendo (PID: $old_pid)"
            exit 1
        else
            rm -f "$PID_FILE"
        fi
    fi
    
    # Guardar PID
    echo $$ > "$PID_FILE"
    
    # Función para limpiar al salir
    cleanup() {
        log_message "Deteniendo coordinador de sub-agentes..."
        rm -f "$PID_FILE"
        exit 0
    }
    
    trap cleanup SIGTERM SIGINT
    
    log_message "Coordinador iniciado en modo daemon (PID: $$)"
    
    # Contadores para cada agente
    declare -A next_execution
    
    for agent_info in "${SUBAGENTS[@]}"; do
        local agent_name=$(echo "$agent_info" | cut -d':' -f1)
        next_execution["$agent_name"]=0
    done
    
    while true; do
        local current_time=$(date +%s)
        
        for agent_info in "${SUBAGENTS[@]}"; do
            local agent_name=$(echo "$agent_info" | cut -d':' -f1)
            local agent_script=$(echo "$agent_info" | cut -d':' -f2)
            
            # Verificar si es hora de ejecutar este agente
            local interval_var="${agent_name^^}_INTERVAL"
            local interval="${!interval_var}"
            
            if [ "$current_time" -ge "${next_execution[$agent_name]}" ]; then
                log_message "Programando ejecución de $agent_name"
                
                # Ejecutar en background para no bloquear otros agentes
                (execute_agent "$agent_name" "$agent_script" "start") &
                
                # Calcular próxima ejecución
                next_execution["$agent_name"]=$((current_time + interval))
            fi
        done
        
        # Dormir 60 segundos antes de la próxima verificación
        sleep 60
    done
}

generate_status_report() {
    log_message "=== GENERANDO REPORTE DE ESTADO ==="
    
    local status_report="/var/log/estado_sub_agentes_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== REPORTE DE ESTADO DE SUB-AGENTES ==="
        echo "Fecha: $(date)"
        echo "Servidor: $(hostname)"
        echo "Coordinador PID: $$"
        echo ""
        echo "=== CONFIGURACIÓN ACTUAL ==="
        cat "$CONFIG_FILE" | grep -v '^#' | grep -v '^$'
        echo ""
        echo "=== ESTADO DE SUB-AGENTES ==="
        
        for agent_info in "${SUBAGENTS[@]}"; do
            local agent_name=$(echo "$agent_info" | cut -d':' -f1)
            local agent_script=$(echo "$agent_info" | cut -d':' -f2)
            local enabled_var="${agent_name^^}_ENABLED"
            local interval_var="${agent_name^^}_INTERVAL"
            
            echo "Sub-agente: $agent_name"
            echo "  Archivo: $agent_script"
            echo "  Habilitado: ${!enabled_var}"
            echo "  Intervalo: ${!interval_var} segundos"
            echo "  Última ejecución: $(find /var/log -name "*${agent_name}*" -type f -exec stat -c '%Y %n' {} \; 2>/dev/null | sort -nr | head -1 | awk '{print strftime("%Y-%m-%d %H:%M:%S", $1)}')"
            echo ""
        done
        
        echo "=== LOGS RECIENTES ==="
        tail -20 "$LOG_FILE"
        
        echo ""
        echo "=== ESTADÍSTICAS DEL SISTEMA ==="
        echo "Uptime: $(uptime)"
        echo "Memoria: $(free -h | grep Mem)"
        echo "Disco: $(df -h / | tail -1)"
        echo "Procesos: $(ps aux | wc -l) procesos activos"
        
    } > "$status_report"
    
    log_message "Reporte de estado generado: $status_report"
}

stop_daemon() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_message "Deteniendo coordinador (PID: $pid)"
            kill -TERM "$pid"
            
            # Esperar a que termine
            local count=0
            while kill -0 "$pid" 2>/dev/null && [ $count -lt 30 ]; do
                sleep 1
                count=$((count + 1))
            done
            
            if kill -0 "$pid" 2>/dev/null; then
                log_message "Forzando detención del coordinador"
                kill -KILL "$pid"
            fi
            
            rm -f "$PID_FILE"
            log_message "Coordinador detenido"
        else
            log_message "No hay coordinador corriendo"
            rm -f "$PID_FILE"
        fi
    else
        log_message "No se encontró archivo PID"
    fi
}

install_service() {
    log_message "=== INSTALANDO SERVICIO SYSTEMD ==="
    
    local service_file="/etc/systemd/system/sub-agentes-webmin.service"
    
    cat > "$service_file" << EOF
[Unit]
Description=Coordinador de Sub-Agentes Webmin/Virtualmin
After=network.target

[Service]
Type=simple
User=root
ExecStart=$SCRIPT_DIR/coordinador_sub_agentes.sh daemon
ExecStop=$SCRIPT_DIR/coordinador_sub_agentes.sh stop
Restart=always
RestartSec=30
PIDFile=$PID_FILE

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable sub-agentes-webmin.service
    
    log_message "Servicio systemd instalado y habilitado"
    log_message "Usar: systemctl {start|stop|status} sub-agentes-webmin"
}

main() {
    log_message "Iniciando coordinador de sub-agentes..."
    
    if ! check_prerequisites; then
        log_error "Fallo en verificación de prerequisitos"
        exit 1
    fi
    
    load_configuration
    
    case "${1:-}" in
        start)
            execute_all_agents "start"
            ;;
        daemon)
            daemon_mode
            ;;
        stop)
            stop_daemon
            ;;
        restart)
            stop_daemon
            sleep 2
            daemon_mode
            ;;
        status)
            generate_status_report
            ;;
        install-service)
            install_service
            ;;
        test)
            log_message "=== MODO PRUEBA ==="
            execute_all_agents "check" 2>/dev/null || execute_all_agents "start"
            ;;
        monitoreo)
            execute_agent "monitoreo" "$SCRIPT_DIR/sub_agente_monitoreo.sh" "${2:-start}"
            ;;
        seguridad)
            execute_agent "seguridad" "$SCRIPT_DIR/sub_agente_seguridad.sh" "${2:-start}"
            ;;
        backup)
            execute_agent "backup" "$SCRIPT_DIR/sub_agente_backup.sh" "${2:-start}"
            ;;
        actualizaciones)
            execute_agent "actualizaciones" "$SCRIPT_DIR/sub_agente_actualizaciones.sh" "${2:-start}"
            ;;
        logs)
            execute_agent "logs" "$SCRIPT_DIR/sub_agente_logs.sh" "${2:-start}"
            ;;
        especialista)
            execute_agent "especialista" "$SCRIPT_DIR/sub_agente_especialista_codigo.sh" "${2:-audit}"
            ;;
        optimizador)
            execute_agent "optimizador" "$SCRIPT_DIR/sub_agente_optimizador.sh" "${2:-start}"
            ;;
        ingeniero)
            execute_agent "ingeniero" "$SCRIPT_DIR/sub_agente_ingeniero_codigo.sh" "${2:-start}"
            ;;
        verificador-backup)
            execute_agent "verificador-backup" "$SCRIPT_DIR/sub_agente_verificador_backup.sh" "${2:-start}"
            ;;
        check-backups)
            log_message "=== VERIFICACIÓN COMPLETA DE BACKUPS ==="
            execute_agent "verificador-backup" "$SCRIPT_DIR/sub_agente_verificador_backup.sh" "start"
            ;;
        refactor-all)
            log_message "=== MODO REFACTORIZACIÓN COMPLETA ==="
            execute_agent "ingeniero" "$SCRIPT_DIR/sub_agente_ingeniero_codigo.sh" "start"
            ;;
        repair-all)
            log_message "=== MODO REPARACIÓN COMPLETA ==="
            execute_agent "especialista" "$SCRIPT_DIR/sub_agente_especialista_codigo.sh" "repair"
            execute_agent "optimizador" "$SCRIPT_DIR/sub_agente_optimizador.sh" "start"
            ;;
        *)
            echo "Coordinador de Sub-Agentes Webmin/Virtualmin"
            echo "Uso: $0 {start|daemon|stop|restart|status|install-service|test}"
            echo ""
            echo "Comandos principales:"
            echo "  start           - Ejecutar todos los sub-agentes una vez"
            echo "  daemon          - Ejecutar en modo daemon continuo"
            echo "  stop            - Detener daemon"
            echo "  restart         - Reiniciar daemon"
            echo "  status          - Generar reporte de estado"
            echo "  install-service - Instalar como servicio systemd"
            echo "  test            - Modo de prueba"
            echo ""
            echo "Sub-agentes individuales:"
            echo "  monitoreo [modo]       - Solo sub-agente de monitoreo"
            echo "  seguridad [modo]       - Solo sub-agente de seguridad"
            echo "  backup [modo]          - Solo sub-agente de backup"
            echo "  actualizaciones [modo] - Solo sub-agente de actualizaciones"
            echo "  logs [modo]            - Solo sub-agente de logs"
            echo "  especialista [modo]    - Sub-agente especialista en código"
            echo "  optimizador [modo]     - Sub-agente optimizador de rendimiento"
            echo "  ingeniero [modo]       - Sub-agente ingeniero de código"
            echo "  verificador-backup [modo] - Sub-agente verificador de backups"
            echo ""
            echo "Comandos especiales:"
            echo "  repair-all             - Reparar y optimizar todo el sistema"
            echo "  refactor-all           - Refactorizar y optimizar código"
            echo "  check-backups          - Verificar sistemas de backup completos"
            echo ""
            echo "Configuración: $CONFIG_FILE"
            echo "Logs: $LOG_FILE"
            exit 1
            ;;
    esac
}

# Verificar si se ejecuta como root (recomendado)
if [ "$EUID" -ne 0 ]; then
    echo "ADVERTENCIA: Se recomienda ejecutar como root para acceso completo al sistema"
fi

main "$@"