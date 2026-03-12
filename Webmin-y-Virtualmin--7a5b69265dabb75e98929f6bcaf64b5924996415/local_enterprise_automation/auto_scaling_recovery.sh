#!/bin/bash

# Script de autoescalado y auto-recuperación para Virtualmin Enterprise
# Este script monitorea recursos del sistema y realiza acciones de escalado/recuperación

set -e

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables de configuración
INSTALL_DIR="/opt/virtualmin-enterprise"
LOG_FILE="/var/log/virtualmin-enterprise-auto-scaling.log"
CONFIG_FILE="$INSTALL_DIR/config/auto_scaling.conf"

# Umbrales de escalado
CPU_THRESHOLD_HIGH=80
CPU_THRESHOLD_CRITICAL=95
MEMORY_THRESHOLD_HIGH=80
MEMORY_THRESHOLD_CRITICAL=95
DISK_THRESHOLD_HIGH=85
DISK_THRESHOLD_CRITICAL=95
LOAD_THRESHOLD_HIGH=2.0
LOAD_THRESHOLD_CRITICAL=4.0

# Función para imprimir mensajes con colores
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Función para registrar mensajes en el log
log_message() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Función para verificar si el script se ejecuta como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_message $RED "Este script debe ejecutarse como root" >&2
        exit 1
    fi
}

# Función para crear directorio de configuración
create_config_dir() {
    if [ ! -d "$INSTALL_DIR/config" ]; then
        mkdir -p "$INSTALL_DIR/config"
    fi
}

# Función para crear archivo de configuración
create_config_file() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << EOF
# Configuración de autoescalado y auto-recuperación

# Umbral de CPU para escalar (porcentaje)
CPU_THRESHOLD_HIGH=$CPU_THRESHOLD_HIGH

# Umbral de CPU crítico (porcentaje)
CPU_THRESHOLD_CRITICAL=$CPU_THRESHOLD_CRITICAL

# Umbral de memoria para escalar (porcentaje)
MEMORY_THRESHOLD_HIGH=$MEMORY_THRESHOLD_HIGH

# Umbral de memoria crítico (porcentaje)
MEMORY_THRESHOLD_CRITICAL=$MEMORY_THRESHOLD_CRITICAL

# Umbral de disco para escalar (porcentaje)
DISK_THRESHOLD_HIGH=$DISK_THRESHOLD_HIGH

# Umbral de disco crítico (porcentaje)
DISK_THRESHOLD_CRITICAL=$DISK_THRESHOLD_CRITICAL

# Umbral de carga para escalar
LOAD_THRESHOLD_HIGH=$LOAD_THRESHOLD_HIGH

# Umbral de carga crítico
LOAD_THRESHOLD_CRITICAL=$LOAD_THRESHOLD_CRITICAL

# Habilitar autoescalado (true/false)
AUTO_SCALING_ENABLED=true

# Habilitar auto-recuperación (true/false)
AUTO_RECOVERY_ENABLED=true

# Acciones a realizar en caso de umbral alto
HIGH_THRESHOLD_ACTIONS=restart_services,clean_cache,clean_logs

# Acciones a realizar en caso de umbral crítico
CRITICAL_THRESHOLD_ACTIONS=kill_idle_processes,restart_system,send_alert
EOF
        log_message "Archivo de configuración creado: $CONFIG_FILE"
    fi
}

# Función para cargar configuración
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        log_message "Configuración cargada desde: $CONFIG_FILE"
    else
        log_message "ERROR: No se encontró archivo de configuración: $CONFIG_FILE"
        exit 1
    fi
}

# Función para obtener uso de CPU
get_cpu_usage() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    # Eliminar caracteres adicionales y convertir a número
    cpu_usage=${cpu_usage//,/.}
    echo "$cpu_usage"
}

# Función para obtener uso de memoria
get_memory_usage() {
    local memory_usage=$(free | grep Mem | awk '{printf "%.2f", $3/$2 * 100.0}')
    echo "$memory_usage"
}

# Función para obtener uso de disco
get_disk_usage() {
    local filesystem=$1
    local disk_usage=$(df -h "$filesystem" | awk 'NR==2 {print $5}' | cut -d'%' -f1)
    echo "$disk_usage"
}

# Función para obtener carga del sistema
get_system_load() {
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    echo "$load_avg"
}

# Función para obtener carga por CPU
get_load_per_cpu() {
    local load_1min=$(get_system_load)
    local cpu_count=$(nproc)
    local load_per_cpu=$(echo "scale=2; $load_1min / $cpu_count" | bc)
    echo "$load_per_cpu"
}

# Función para limpiar caché
clean_cache() {
    log_message "Limpiando caché del sistema"
    
    # Limpiar caché de memoria
    sync
    echo 3 > /proc/sys/vm/drop_caches
    
    # Limpiar caché de apt (Debian/Ubuntu)
    if command -v apt-get &> /dev/null; then
        apt-get clean >> "$LOG_FILE" 2>&1
    fi
    
    # Limpiar caché de yum (RHEL/CentOS)
    if command -v yum &> /dev/null; then
        yum clean all >> "$LOG_FILE" 2>&1
    fi
    
    log_message "Caché limpiada"
}

# Función para limpiar logs antiguos
clean_logs() {
    log_message "Limpiando logs antiguos"
    
    # Limpiar logs de más de 7 días
    find /var/log -name "*.log" -type f -mtime +7 -delete >> "$LOG_FILE" 2>&1
    find /var/log -name "*.log.*" -type f -mtime +7 -delete >> "$LOG_FILE" 2>&1
    
    # Limpiar logs rotados de más de 7 días
    find /var/log -name "*.gz" -type f -mtime +7 -delete >> "$LOG_FILE" 2>&1
    
    log_message "Logs antiguos limpiados"
}

# Función para reiniciar servicios
restart_services() {
    log_message "Reiniciando servicios críticos"
    
    # Lista de servicios a reiniciar
    local services=("nginx" "apache2" "mysql" "postgresql" "redis-server" "memcached")
    
    # Para RHEL/CentOS, usar nombres de servicio diferentes
    if [ -f /etc/redhat-release ]; then
        services=("nginx" "httpd" "mariadb" "postgresql" "redis" "memcached")
    fi
    
    # Reiniciar cada servicio
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log_message "Reiniciando $service"
            systemctl restart "$service" >> "$LOG_FILE" 2>&1
            
            if [ $? -eq 0 ]; then
                log_message "$service reiniciado exitosamente"
            else
                log_message "ERROR: Falló el reinicio de $service"
            fi
        fi
    done
}

# Función para identificar y terminar procesos inactivos
kill_idle_processes() {
    log_message "Identificando y terminando procesos inactivos"
    
    # Identificar procesos con alto uso de CPU pero baja prioridad
    local high_cpu_processes=$(ps aux --sort=-%cpu | awk 'NR>1 && $3 > 50 && $8 != "Z" {print $2}')
    
    for pid in $high_cpu_processes; do
        # Verificar si el proceso es de baja prioridad (nice > 10)
        local nice_value=$(ps -p "$pid" -o nice= | tr -d ' ')
        
        if [ "$nice_value" -gt 10 ]; then
            log_message "Terminando proceso inactivo con alto uso de CPU: PID $pid"
            kill -TERM "$pid" >> "$LOG_FILE" 2>&1
        fi
    done
    
    # Identificar procesos con alto uso de memoria pero baja prioridad
    local high_mem_processes=$(ps aux --sort=-%mem | awk 'NR>1 && $4 > 50 && $8 != "Z" {print $2}')
    
    for pid in $high_mem_processes; do
        # Verificar si el proceso es de baja prioridad (nice > 10)
        local nice_value=$(ps -p "$pid" -o nice= | tr -d ' ')
        
        if [ "$nice_value" -gt 10 ]; then
            log_message "Terminando proceso inactivo con alto uso de memoria: PID $pid"
            kill -TERM "$pid" >> "$LOG_FILE" 2>&1
        fi
    done
    
    log_message "Procesos inactivos terminados"
}

# Función para enviar alerta
send_alert() {
    local subject=$1
    local message=$2
    
    log_message "ALERTA: $subject - $message"
    
    # Aquí se puede agregar código para enviar alertas por email, Telegram, etc.
    # Por ejemplo, para enviar por email:
    # echo "$message" | mail -s "$subject" admin@example.com
    
    # O para enviar por Telegram (necesita configurar bot):
    # curl -s -X POST "https://api.telegram.org/bot<TOKEN>/sendMessage" -d "chat_id=<CHAT_ID>&text=$message"
}

# Función para realizar acciones de umbral alto
perform_high_threshold_actions() {
    log_message "Realizando acciones de umbral alto"
    
    # Convertir string a array
    IFS=',' read -ra ACTIONS <<< "$HIGH_THRESHOLD_ACTIONS"
    
    for action in "${ACTIONS[@]}"; do
        case $action in
            "restart_services")
                restart_services
                ;;
            "clean_cache")
                clean_cache
                ;;
            "clean_logs")
                clean_logs
                ;;
            *)
                log_message "Acción desconocida: $action"
                ;;
        esac
    done
}

# Función para realizar acciones de umbral crítico
perform_critical_threshold_actions() {
    log_message "Realizando acciones de umbral crítico"
    
    # Convertir string a array
    IFS=',' read -ra ACTIONS <<< "$CRITICAL_THRESHOLD_ACTIONS"
    
    for action in "${ACTIONS[@]}"; do
        case $action in
            "kill_idle_processes")
                kill_idle_processes
                ;;
            "restart_system")
                log_message "Reiniciando sistema en 60 segundos"
                send_alert "Reinicio del sistema" "El sistema se reiniciará en 60 segundos debido a recursos críticos"
                shutdown -r +60 "Reinicio automático debido a recursos críticos"
                ;;
            "send_alert")
                send_alert "Recursos críticos" "El sistema ha alcanzado umbrales críticos de recursos"
                ;;
            *)
                log_message "Acción desconocida: $action"
                ;;
        esac
    done
}

# Función para verificar y realizar autoescalado
check_auto_scaling() {
    if [ "$AUTO_SCALING_ENABLED" != "true" ]; then
        log_message "Autoescalado deshabilitado"
        return
    fi
    
    log_message "Verificando condiciones de autoescalado"
    
    # Obtener métricas actuales
    local cpu_usage=$(get_cpu_usage)
    local memory_usage=$(get_memory_usage)
    local disk_usage=$(get_disk_usage "/")
    local load_per_cpu=$(get_load_per_cpu)
    
    log_message "Métricas actuales - CPU: $cpu_usage%, Memoria: $memory_usage%, Disco: $disk_usage%, Carga por CPU: $load_per_cpu"
    
    # Verificar umbrales críticos
    local critical_threshold_reached=false
    
    if (( $(echo "$cpu_usage > $CPU_THRESHOLD_CRITICAL" | bc -l) )); then
        log_message "⚠ Umbral crítico de CPU alcanzado: $cpu_usage%"
        critical_threshold_reached=true
    fi
    
    if (( $(echo "$memory_usage > $MEMORY_THRESHOLD_CRITICAL" | bc -l) )); then
        log_message "⚠ Umbral crítico de memoria alcanzado: $memory_usage%"
        critical_threshold_reached=true
    fi
    
    if [ "$disk_usage" -gt "$DISK_THRESHOLD_CRITICAL" ]; then
        log_message "⚠ Umbral crítico de disco alcanzado: $disk_usage%"
        critical_threshold_reached=true
    fi
    
    if (( $(echo "$load_per_cpu > $LOAD_THRESHOLD_CRITICAL" | bc -l) )); then
        log_message "⚠ Umbral crítico de carga alcanzado: $load_per_cpu"
        critical_threshold_reached=true
    fi
    
    # Realizar acciones de umbral crítico
    if [ "$critical_threshold_reached" = true ]; then
        perform_critical_threshold_actions
        return
    fi
    
    # Verificar umbrales altos
    local high_threshold_reached=false
    
    if (( $(echo "$cpu_usage > $CPU_THRESHOLD_HIGH" | bc -l) )); then
        log_message "⚠ Umbral alto de CPU alcanzado: $cpu_usage%"
        high_threshold_reached=true
    fi
    
    if (( $(echo "$memory_usage > $MEMORY_THRESHOLD_HIGH" | bc -l) )); then
        log_message "⚠ Umbral alto de memoria alcanzado: $memory_usage%"
        high_threshold_reached=true
    fi
    
    if [ "$disk_usage" -gt "$DISK_THRESHOLD_HIGH" ]; then
        log_message "⚠ Umbral alto de disco alcanzado: $disk_usage%"
        high_threshold_reached=true
    fi
    
    if (( $(echo "$load_per_cpu > $LOAD_THRESHOLD_HIGH" | bc -l) )); then
        log_message "⚠ Umbral alto de carga alcanzado: $load_per_cpu"
        high_threshold_reached=true
    fi
    
    # Realizar acciones de umbral alto
    if [ "$high_threshold_reached" = true ]; then
        perform_high_threshold_actions
    fi
}

# Función para verificar y realizar auto-recuperación
check_auto_recovery() {
    if [ "$AUTO_RECOVERY_ENABLED" != "true" ]; then
        log_message "Auto-recuperación deshabilitada"
        return
    fi
    
    log_message "Verificando servicios para auto-recuperación"
    
    # Lista de servicios críticos
    local services=("nginx" "apache2" "mysql" "postgresql" "redis-server" "memcached")
    
    # Para RHEL/CentOS, usar nombres de servicio diferentes
    if [ -f /etc/redhat-release ]; then
        services=("nginx" "httpd" "mariadb" "postgresql" "redis" "memcached")
    fi
    
    # Verificar cada servicio
    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet "$service"; then
            log_message "✗ $service está inactivo, intentando recuperación"
            
            # Intentar reiniciar el servicio
            systemctl restart "$service" >> "$LOG_FILE" 2>&1
            
            # Verificar si el reinicio fue exitoso
            if systemctl is-active --quiet "$service"; then
                log_message "✓ $service recuperado exitosamente"
                send_alert "Servicio recuperado" "El servicio $service ha sido recuperado automáticamente"
            else
                log_message "✗ $service no se pudo recuperar"
                send_alert "Servicio no recuperado" "El servicio $service no se pudo recuperar automáticamente"
            fi
        fi
    done
    
    # Verificar acceso a Webmin
    if ! curl -s -k https://localhost:10000/ > /dev/null; then
        log_message "✗ Webmin no es accesible, intentando recuperación"
        
        # Intentar reiniciar Webmin
        systemctl restart webmin >> "$LOG_FILE" 2>&1
        
        # Verificar si el reinicio fue exitoso
        if curl -s -k https://localhost:10000/ > /dev/null; then
            log_message "✓ Webmin recuperado exitosamente"
            send_alert "Webmin recuperado" "Webmin ha sido recuperado automáticamente"
        else
            log_message "✗ Webmin no se pudo recuperar"
            send_alert "Webmin no recuperado" "Webmin no se pudo recuperar automáticamente"
        fi
    fi
}

# Función para configurar tarea cron
setup_cron() {
    log_message "Configurando tarea cron para autoescalado y auto-recuperación"
    
    # Crear tarea cron para ejecutar cada 5 minutos
    local cron_entry="*/5 * * * * $INSTALL_DIR/scripts/auto_scaling_recovery.sh >> $LOG_FILE 2>&1"
    
    # Verificar si la tarea ya existe
    if ! crontab -l 2>/dev/null | grep -q "auto_scaling_recovery.sh"; then
        # Agregar tarea cron
        (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
        log_message "Tarea cron configurada para ejecutar cada 5 minutos"
    else
        log_message "La tarea cron ya existe"
    fi
}

# Función principal
main() {
    print_message $GREEN "Iniciando sistema de autoescalado y auto-recuperación..."
    log_message "Iniciando sistema de autoescalado y auto-recuperación"
    
    check_root
    create_config_dir
    create_config_file
    load_config
    
    # Verificar y realizar autoescalado
    check_auto_scaling
    
    # Verificar y realizar auto-recuperación
    check_auto_recovery
    
    # Configurar tarea cron
    setup_cron
    
    print_message $GREEN "Sistema de autoescalado y auto-recuperación configurado"
    log_message "Sistema de autoescalado y auto-recuperación configurado"
}

# Ejecutar función principal
main "$@"