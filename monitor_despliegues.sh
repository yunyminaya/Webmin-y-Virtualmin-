#!/bin/bash

# Monitor de Despliegues para Agente DevOps Webmin/Virtualmin
# Supervisa el estado de despliegues y genera reportes de salud

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

# Directorio base
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_CONFIG="$BASE_DIR/monitor_config.json"
MONITOR_LOG="$BASE_DIR/monitor.log"
REPORTS_DIR="$BASE_DIR/reports"
ALERTS_LOG="$BASE_DIR/alerts.log"
STATUS_FILE="$BASE_DIR/deployment_status.json"
HEALTH_CHECK_INTERVAL=300  # 5 minutos
ALERT_COOLDOWN=3600       # 1 hora

# Función para mostrar encabezados
# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Fin de función duplicada

# Función para mostrar información
show_info() {
    echo -e "${YELLOW}[INFO]${NC} ℹ️  $1"
}

# Función para mostrar éxito
show_success() {
    echo -e "${GREEN}[SUCCESS]${NC} ✅ $1"
}

# Función para mostrar errores
# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Fin de función duplicada

# Función para mostrar advertencias
show_warning() {
    echo -e "${YELLOW}[WARNING]${NC} ⚠️  $1"
}

# Función para logging
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [${level}] ${message}" >> "$MONITOR_LOG"
    
    # También mostrar en pantalla si es crítico
    if [ "$level" = "CRITICAL" ] || [ "$level" = "ERROR" ]; then
        show_error "$message"
    fi
}

# Función para enviar alerta
send_alert() {
    local level="$1"
    local message="$2"
    local server="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Verificar cooldown de alertas
    local last_alert_file="$BASE_DIR/.last_alert_${server}_${level}"
    if [ -f "$last_alert_file" ]; then
        local last_alert=$(cat "$last_alert_file")
        local current_time=$(date +%s)
        if [ $((current_time - last_alert)) -lt $ALERT_COOLDOWN ]; then
            return 0  # Saltar alerta por cooldown
        fi
    fi
    
    # Registrar alerta
    echo "${timestamp} [${level}] ${server}: ${message}" >> "$ALERTS_LOG"
    log_message "ALERT" "${level} - ${server}: ${message}"
    
    # Actualizar timestamp de última alerta
    echo "$(date +%s)" > "$last_alert_file"
    
    # Aquí se pueden agregar integraciones con sistemas de alertas
    # como Slack, Discord, email, etc.
    
    case "$level" in
        "CRITICAL")
            show_error "🚨 ALERTA CRÍTICA - $server: $message"
            ;;
        "WARNING")
            show_warning "⚠️ ADVERTENCIA - $server: $message"
            ;;
        "INFO")
            show_info "📢 INFO - $server: $message"
            ;;
    esac
}

# Función para verificar conectividad de servidor
check_server_connectivity() {
    local host="$1"
    local user="$2"
    local port="$3"
    
    if timeout 10 ssh -o ConnectTimeout=5 -o BatchMode=yes -p "$port" "$user@$host" "echo 'OK'" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Función para verificar estado de Webmin
check_webmin_status() {
    local host="$1"
    local user="$2"
    local port="$3"
    
    local cmd="curl -k --silent --fail --max-time 10 https://127.0.0.1:10000/ >/dev/null 2>&1 && echo 'OK' || echo 'FAIL'"
    local result=$(ssh -o ConnectTimeout=10 -p "$port" "$user@$host" "$cmd" 2>/dev/null)
    
    if [ "$result" = "OK" ]; then
        return 0
    else
        return 1
    fi
}

# Función para verificar estado de servicios web
check_web_services() {
    local host="$1"
    local user="$2"
    local port="$3"
    local web_server="$4"
    
    local cmd="
        if [ '$web_server' = 'apache2' ]; then
            systemctl is-active apache2 >/dev/null 2>&1 && echo 'OK' || echo 'FAIL'
        else
            systemctl is-active nginx >/dev/null 2>&1 && echo 'OK' || echo 'FAIL'
        fi
    "
    
    local result=$(ssh -o ConnectTimeout=10 -p "$port" "$user@$host" "$cmd" 2>/dev/null)
    
    if [ "$result" = "OK" ]; then
        return 0
    else
        return 1
    fi
}

# Función para obtener métricas del sistema
get_system_metrics() {
    local host="$1"
    local user="$2"
    local port="$3"
    
    local cmd="
        echo '{'
        echo '  \"cpu_usage\": '\$(top -bn1 | grep 'Cpu(s)' | awk '{print \$2}' | cut -d'%' -f1 | tr -d ' ' || echo '0')','
        echo '  \"memory_usage\": '\$(free | grep Mem | awk '{printf \"%.1f\", \$3/\$2 * 100.0}' || echo '0')','
        echo '  \"disk_usage\": '\$(df / | tail -1 | awk '{print \$5}' | tr -d '%' || echo '0')','
        echo '  \"load_average\": \"'\$(uptime | awk -F'load average:' '{print \$2}' | tr -d ' ' || echo '0,0,0')'\"','
        echo '  \"uptime\": \"'\$(uptime -p 2>/dev/null || uptime | awk '{print \$3,\$4}' | tr -d ',')'\"'
        echo '}'
    "
    
    ssh -o ConnectTimeout=10 -p "$port" "$user@$host" "$cmd" 2>/dev/null
}

# Función para verificar vhosts
check_vhosts() {
    local host="$1"
    local user="$2"
    local port="$3"
    
    # Obtener lista de dominios
    local domains=$(ssh -o ConnectTimeout=10 -p "$port" "$user@$host" "sudo virtualmin list-domains --name-only 2>/dev/null" | grep -v '^$' || echo "")
    
    local total_domains=0
    local working_domains=0
    local failed_domains=()
    
    if [ -n "$domains" ]; then
        for domain in $domains; do
            total_domains=$((total_domains + 1))
            
            # Verificar dominio
            local check_cmd="curl -k --silent --fail --max-time 10 https://$domain/ >/dev/null 2>&1 || curl --silent --fail --max-time 10 http://$domain/ >/dev/null 2>&1"
            
            if ssh -o ConnectTimeout=10 -p "$port" "$user@$host" "$check_cmd" >/dev/null 2>&1; then
                working_domains=$((working_domains + 1))
            else
                failed_domains+=("$domain")
            fi
        done
    fi
    
    echo "{\"total\":$total_domains,\"working\":$working_domains,\"failed\":[\"$(IFS=\",\"; echo "${failed_domains[*]}")\"]}"
}

# Función para verificar estado de un servidor
check_server_health() {
    local server_config="$1"
    
    # Parsear configuración del servidor
    local host=$(echo "$server_config" | jq -r '.host')
    local user=$(echo "$server_config" | jq -r '.user')
    local port=$(echo "$server_config" | jq -r '.port')
    local web=$(echo "$server_config" | jq -r '.web')
    
    local timestamp=$(date -Iseconds)
    local status="OK"
    local issues=()
    
    log_message "INFO" "Verificando salud de $host"
    
    # Verificar conectividad
    if ! check_server_connectivity "$host" "$user" "$port"; then
        status="CRITICAL"
        issues+=("SSH connectivity failed")
        send_alert "CRITICAL" "No se puede conectar por SSH" "$host"
    else
        # Verificar Webmin
        if ! check_webmin_status "$host" "$user" "$port"; then
            status="WARNING"
            issues+=("Webmin not responding")
            send_alert "WARNING" "Webmin no responde" "$host"
        fi
        
        # Verificar servicios web
        if ! check_web_services "$host" "$user" "$port" "$web"; then
            status="CRITICAL"
            issues+=("Web server not running")
            send_alert "CRITICAL" "Servidor web no está ejecutándose" "$host"
        fi
        
        # Obtener métricas del sistema
        local metrics=$(get_system_metrics "$host" "$user" "$port")
        
        # Verificar uso de CPU
        local cpu_usage=$(echo "$metrics" | jq -r '.cpu_usage // 0' 2>/dev/null | cut -d'.' -f1)
        if [ "$cpu_usage" -gt 80 ]; then
            status="WARNING"
            issues+=("High CPU usage: ${cpu_usage}%")
            send_alert "WARNING" "Alto uso de CPU: ${cpu_usage}%" "$host"
        fi
        
        # Verificar uso de memoria
        local memory_usage=$(echo "$metrics" | jq -r '.memory_usage // 0' 2>/dev/null | cut -d'.' -f1)
        if [ "$memory_usage" -gt 85 ]; then
            status="WARNING"
            issues+=("High memory usage: ${memory_usage}%")
            send_alert "WARNING" "Alto uso de memoria: ${memory_usage}%" "$host"
        fi
        
        # Verificar uso de disco
        local disk_usage=$(echo "$metrics" | jq -r '.disk_usage // 0' 2>/dev/null)
        if [ "$disk_usage" -gt 90 ]; then
            status="CRITICAL"
            issues+=("High disk usage: ${disk_usage}%")
            send_alert "CRITICAL" "Alto uso de disco: ${disk_usage}%" "$host"
        fi
        
        # Verificar vhosts
        local vhosts_status=$(check_vhosts "$host" "$user" "$port")
        local failed_vhosts=$(echo "$vhosts_status" | jq -r '.failed[]' 2>/dev/null | wc -l)
        
        if [ "$failed_vhosts" -gt 0 ]; then
            status="WARNING"
            issues+=("$failed_vhosts vhosts failing")
            send_alert "WARNING" "$failed_vhosts vhosts no responden" "$host"
        fi
    fi
    
    # Generar reporte del servidor
    local server_report="{
        \"host\": \"$host\",
        \"timestamp\": \"$timestamp\",
        \"status\": \"$status\",
        \"issues\": [\"$(IFS=\",\"; echo "${issues[*]}")\"],
        \"metrics\": $metrics,
        \"vhosts\": $vhosts_status
    }"
    
    echo "$server_report"
}

# Función para generar reporte de salud completo
generate_health_report() {
    show_header "GENERANDO REPORTE DE SALUD"
    
    if [ ! -f "$MONITOR_CONFIG" ]; then
        show_error "No hay configuración de monitoreo"
        return 1
    fi
    
    local timestamp=$(date -Iseconds)
    local report_file="$REPORTS_DIR/health_report_$(date +%Y%m%d_%H%M%S).json"
    
    mkdir -p "$REPORTS_DIR"
    
    local servers=$(jq -r '.servers[]' "$MONITOR_CONFIG" 2>/dev/null)
    local server_reports=()
    local global_status="OK"
    
    # Verificar cada servidor
    echo "$servers" | while read -r server; do
        if [ -n "$server" ]; then
            local server_report=$(check_server_health "$server")
            local server_status=$(echo "$server_report" | jq -r '.status')
            
            server_reports+=("$server_report")
            
            if [ "$server_status" = "CRITICAL" ]; then
                global_status="CRITICAL"
            elif [ "$server_status" = "WARNING" ] && [ "$global_status" = "OK" ]; then
                global_status="WARNING"
            fi
        fi
    done
    
    # Generar reporte final
    local final_report="{
        \"timestamp\": \"$timestamp\",
        \"global_status\": \"$global_status\",
        \"servers\": [$(IFS=','; echo "${server_reports[*]}")],
        \"summary\": {
            \"total_servers\": ${#server_reports[@]},
            \"healthy_servers\": $(echo "${server_reports[*]}" | grep -o '"status":"OK"' | wc -l),
            \"warning_servers\": $(echo "${server_reports[*]}" | grep -o '"status":"WARNING"' | wc -l),
            \"critical_servers\": $(echo "${server_reports[*]}" | grep -o '"status":"CRITICAL"' | wc -l)
        }
    }"
    
    echo "$final_report" > "$report_file"
    echo "$final_report" > "$STATUS_FILE"  # Estado actual
    
    show_success "Reporte generado: $report_file"
    
    # Mostrar resumen
    show_header "RESUMEN DE SALUD"
    echo -e "${CYAN}Estado global:${NC} $global_status"
    echo -e "${CYAN}Servidores totales:${NC} ${#server_reports[@]}"
    echo -e "${CYAN}Servidores saludables:${NC} $(echo "${server_reports[*]}" | grep -o '"status":"OK"' | wc -l)"
    echo -e "${CYAN}Servidores con advertencias:${NC} $(echo "${server_reports[*]}" | grep -o '"status":"WARNING"' | wc -l)"
    echo -e "${CYAN}Servidores críticos:${NC} $(echo "${server_reports[*]}" | grep -o '"status":"CRITICAL"' | wc -l)"
    
    return 0
}

# Función para monitoreo continuo
start_continuous_monitoring() {
    show_header "INICIANDO MONITOREO CONTINUO"
    
    show_info "Intervalo de verificación: $HEALTH_CHECK_INTERVAL segundos"
    show_info "Cooldown de alertas: $ALERT_COOLDOWN segundos"
    show_info "Presione Ctrl+C para detener"
    
    log_message "INFO" "Monitoreo continuo iniciado"
    
    # Trap para manejo de señales
    trap 'log_message "INFO" "Monitoreo continuo detenido"; exit 0' INT TERM
    
    while true; do
        generate_health_report >/dev/null 2>&1
        
        show_info "Verificación completada - $(date '+%Y-%m-%d %H:%M:%S')"
        
        sleep "$HEALTH_CHECK_INTERVAL"
    done
}

# Función para configurar monitoreo
configure_monitoring() {
    show_header "CONFIGURACIÓN DE MONITOREO"
    
    # Verificar si existe configuración del agente DevOps
    local agent_config="$BASE_DIR/agente_devops_config.json"
    
    if [ -f "$agent_config" ]; then
        show_info "Usando configuración del agente DevOps existente"
        cp "$agent_config" "$MONITOR_CONFIG"
        show_success "Configuración copiada"
    else
        show_info "Configurando servidores manualmente"
        
        local servers_json="[]"
        local server_count=0
        
        while true; do
            server_count=$((server_count + 1))
            echo -e "\n${CYAN}Configurando servidor #$server_count${NC}"
            
            local host user port web
            
            echo -e "${BLUE}Host/IP del servidor:${NC} "
            read -r host
            
            echo -e "${BLUE}Usuario SSH [default: deploy]:${NC} "
            read -r user
            if [ -z "$user" ]; then
                user="deploy"
            fi
            
            echo -e "${BLUE}Puerto SSH [default: 22]:${NC} "
            read -r port
            if [ -z "$port" ]; then
                port=22
            fi
            
            echo -e "${BLUE}Servidor web [apache2/nginx, default: apache2]:${NC} "
            read -r web
            if [ -z "$web" ]; then
                web="apache2"
            fi
            
            # Agregar servidor
            local server_config="{\"host\":\"$host\",\"user\":\"$user\",\"port\":$port,\"web\":\"$web\"}"
            
            if [ $server_count -eq 1 ]; then
                servers_json="[$server_config]"
            else
                servers_json=$(echo "$servers_json" | jq ". + [$server_config]")
            fi
            
            echo -e "\n${BLUE}¿Agregar otro servidor? [y/N]:${NC} "
            read -r add_more
            if [[ ! "$add_more" =~ ^[Yy]$ ]]; then
                break
            fi
        done
        
        # Configurar intervalos
        echo -e "\n${BLUE}Intervalo de verificación en segundos [default: 300]:${NC} "
        read -r interval
        if [ -z "$interval" ]; then
            interval=300
        fi
        
        echo -e "${BLUE}Cooldown de alertas en segundos [default: 3600]:${NC} "
        read -r cooldown
        if [ -z "$cooldown" ]; then
            cooldown=3600
        fi
        
        # Generar configuración
        local config="{
            \"servers\": $servers_json,
            \"health_check_interval\": $interval,
            \"alert_cooldown\": $cooldown,
            \"created_at\": \"$(date -Iseconds)\"
        }"
        
        echo "$config" > "$MONITOR_CONFIG"
        
        HEALTH_CHECK_INTERVAL="$interval"
        ALERT_COOLDOWN="$cooldown"
    fi
    
    show_success "Configuración guardada en: $MONITOR_CONFIG"
}

# Función para mostrar estado actual
show_current_status() {
    show_header "ESTADO ACTUAL DEL SISTEMA"
    
    if [ -f "$STATUS_FILE" ]; then
        local status=$(cat "$STATUS_FILE")
        local global_status=$(echo "$status" | jq -r '.global_status')
        local timestamp=$(echo "$status" | jq -r '.timestamp')
        
        echo -e "${CYAN}Última verificación:${NC} $timestamp"
        echo -e "${CYAN}Estado global:${NC} $global_status"
        
        echo -e "\n${CYAN}Resumen por servidor:${NC}"
        echo "$status" | jq -r '.servers[] | "\(.host): \(.status)"' | while read -r line; do
            local server_host=$(echo "$line" | cut -d':' -f1)
            local server_status=$(echo "$line" | cut -d':' -f2 | tr -d ' ')
            
            case "$server_status" in
                "OK")
                    echo -e "  ${GREEN}✅ $server_host: $server_status${NC}"
                    ;;
                "WARNING")
                    echo -e "  ${YELLOW}⚠️  $server_host: $server_status${NC}"
                    ;;
                "CRITICAL")
                    echo -e "  ${RED}❌ $server_host: $server_status${NC}"
                    ;;
            esac
        done
        
        echo -e "\n${CYAN}Estadísticas:${NC}"
        echo "$status" | jq '.summary'
    else
        show_info "No hay estado actual. Ejecute una verificación primero."
    fi
}

# Función para mostrar alertas recientes
show_recent_alerts() {
    show_header "ALERTAS RECIENTES"
    
    if [ -f "$ALERTS_LOG" ]; then
        echo -e "${CYAN}Últimas 20 alertas:${NC}\n"
        tail -20 "$ALERTS_LOG" | while read -r line; do
            if [[ "$line" =~ CRITICAL ]]; then
                echo -e "${RED}$line${NC}"
            elif [[ "$line" =~ WARNING ]]; then
                echo -e "${YELLOW}$line${NC}"
            else
                echo -e "${BLUE}$line${NC}"
            fi
        done
    else
        show_info "No hay alertas registradas"
    fi
}

# Función para limpiar reportes antiguos
clean_old_reports() {
    show_header "LIMPIEZA DE REPORTES ANTIGUOS"
    
    if [ -d "$REPORTS_DIR" ]; then
        local report_count=$(find "$REPORTS_DIR" -name "health_report_*.json" | wc -l)
        echo -e "${CYAN}Reportes actuales:${NC} $report_count"
        
        echo -e "${BLUE}¿Mantener solo los últimos N reportes? [default: 50]:${NC} "
        read -r keep_count
        if [ -z "$keep_count" ]; then
            keep_count=50
        fi
        
        # Eliminar reportes antiguos
        find "$REPORTS_DIR" -name "health_report_*.json" -type f | sort -r | tail -n +$((keep_count + 1)) | xargs -r rm
        
        local new_count=$(find "$REPORTS_DIR" -name "health_report_*.json" | wc -l)
        show_success "Reportes mantenidos: $new_count"
    else
        show_info "No hay directorio de reportes"
    fi
}

# Función para mostrar menú principal
show_menu() {
    show_header "MONITOR DE DESPLIEGUES WEBMIN/VIRTUALMIN"
    
    echo -e "${BLUE}Opciones disponibles:${NC}"
    echo -e "  ${YELLOW}1.${NC} Configurar monitoreo"
    echo -e "  ${YELLOW}2.${NC} Generar reporte de salud"
    echo -e "  ${YELLOW}3.${NC} Mostrar estado actual"
    echo -e "  ${YELLOW}4.${NC} Iniciar monitoreo continuo"
    echo -e "  ${YELLOW}5.${NC} Ver alertas recientes"
    echo -e "  ${YELLOW}6.${NC} Ver logs de monitoreo"
    echo -e "  ${YELLOW}7.${NC} Limpiar reportes antiguos"
    echo -e "  ${YELLOW}8.${NC} Salir"
    
    echo -e "\n${BLUE}Seleccione una opción${NC} ${YELLOW}[1-8]${NC}: "
    read -r choice
    
    case $choice in
        1)
            configure_monitoring
            ;;
        2)
            generate_health_report
            ;;
        3)
            show_current_status
            ;;
        4)
            start_continuous_monitoring
            ;;
        5)
            show_recent_alerts
            ;;
        6)
            if [ -f "$MONITOR_LOG" ]; then
                echo -e "${CYAN}Últimas 50 líneas del log:${NC}\n"
                tail -50 "$MONITOR_LOG"
            else
                show_info "No hay archivo de log"
            fi
            ;;
        7)
            clean_old_reports
            ;;
        8)
            show_success "¡Hasta luego!"
            exit 0
            ;;
        *)
            show_error "Opción inválida. Use 1-8"
            ;;
    esac
}

# Función principal
main() {
    # Crear directorios necesarios
    mkdir -p "$REPORTS_DIR"
    
    # Verificar dependencias
    if ! command -v jq >/dev/null 2>&1; then
        show_error "jq no está instalado. Instálelo con: brew install jq (macOS) o apt-get install jq (Ubuntu)"
        exit 1
    fi
    
    # Bucle principal del menú
    while true; do
        echo
        show_menu
        echo
        echo -e "${BLUE}Presione Enter para continuar...${NC}"
        read -r
    done
}

# Manejo de argumentos de línea de comandos
case "${1:-}" in
    --check)
        generate_health_report
        ;;
    --monitor)
        start_continuous_monitoring
        ;;
    --status)
        show_current_status
        ;;
    --alerts)
        show_recent_alerts
        ;;
    --help)
        echo "Monitor de Despliegues para Agente DevOps Webmin/Virtualmin"
        echo ""
        echo "Uso: $0 [opción]"
        echo ""
        echo "Opciones:"
        echo "  --check      Generar reporte de salud"
        echo "  --monitor    Iniciar monitoreo continuo"
        echo "  --status     Mostrar estado actual"
        echo "  --alerts     Mostrar alertas recientes"
        echo "  --help       Mostrar ayuda"
        echo ""
        echo "Sin argumentos: Mostrar menú interactivo"
        ;;
    "")
        main
        ;;
    *)
        show_error "Opción desconocida: $1"
        echo "Use --help para ver opciones disponibles"
        exit 1
        ;;
esac
