#!/bin/bash

# Sistema de Auto-Reparación Inteligente para Webmin/Virtualmin
# Detecta y repara problemas automáticamente sin afectar servidores virtuales

# Configuración
LOG_FILE="/var/log/webmin-self-healing.log"
LOCK_FILE="/tmp/webmin-self-healing.lock"
MONITOR_INTERVAL=60  # Segundos entre verificaciones

# Función de logging
log_self_healing() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$LOG_FILE"
}

# Verificar si ya está ejecutándose
if [[ -f "$LOCK_FILE" ]]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null)
    if kill -0 "$pid" 2>/dev/null; then
        exit 0
    else
        rm -f "$LOCK_FILE"
    fi
fi
echo $$ > "$LOCK_FILE"

# Función principal de monitoreo
monitor_and_repair() {
    while true; do
        # Verificar servicios críticos
        check_critical_services

        # Verificar integridad de servidores virtuales
        check_virtual_servers_integrity

        # Verificar conectividad de red
        check_network_connectivity

        # Verificar uso de recursos
        check_resource_usage

        # Verificar logs de errores
        check_error_logs

        sleep "$MONITOR_INTERVAL"
    done
}

# Verificar servicios críticos y reparar si es necesario
check_critical_services() {
    local critical_services=(
        "webmin"
        "apache2"
        "mysql"
        "postfix"
        "dovecot"
        "clamav-daemon"
        "fail2ban"
        "rsyslog"
        "cron"
        "sshd"
    )

    for service in "${critical_services[@]}"; do
        if ! systemctl is-active --quiet "$service" 2>/dev/null; then
            log_self_healing "WARNING" "Servicio $service no activo, intentando reiniciar"

            # Intentar reiniciar el servicio
            if systemctl restart "$service" 2>/dev/null; then
                log_self_healing "SUCCESS" "Servicio $service reiniciado exitosamente"

                # Verificar que se mantuvo activo después del reinicio
                sleep 5
                if systemctl is-active --quiet "$service" 2>/dev/null; then
                    log_self_healing "SUCCESS" "Servicio $service funcionando correctamente"
                else
                    log_self_healing "ERROR" "Servicio $service falló después del reinicio"
                fi
            else
                log_self_healing "ERROR" "No se pudo reiniciar el servicio $service"
            fi
        fi
    done
}

# Verificar integridad de servidores virtuales
check_virtual_servers_integrity() {
    if command -v virtualmin >/dev/null 2>&1; then
        # Verificar que Virtualmin responde
        if ! virtualmin list-domains >/dev/null 2>&1; then
            log_self_healing "WARNING" "Virtualmin no responde, intentando reparar"

            # Reiniciar servicios de Virtualmin
            systemctl restart webmin 2>/dev/null
            sleep 10

            if virtualmin list-domains >/dev/null 2>&1; then
                log_self_healing "SUCCESS" "Virtualmin reparado y funcionando"
            else
                log_self_healing "ERROR" "No se pudo reparar Virtualmin"
            fi
        fi

        # Verificar dominios virtuales
        local domain_count=$(virtualmin list-domains 2>/dev/null | grep -c "Domain:" || echo "0")
        if [[ "$domain_count" -gt 0 ]]; then
            log_self_healing "INFO" "Encontrados $domain_count dominios virtuales"
        fi
    fi
}

# Verificar conectividad de red
check_network_connectivity() {
    # Verificar conectividad básica
    if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        log_self_healing "WARNING" "Sin conectividad a internet"

        # Intentar reiniciar servicios de red
        systemctl restart networking 2>/dev/null
        systemctl restart NetworkManager 2>/dev/null

        sleep 5
        if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
            log_self_healing "SUCCESS" "Conectividad restaurada"
        fi
    fi
}

# Verificar uso de recursos
check_resource_usage() {
    # Verificar uso de disco
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ "$disk_usage" -gt 90 ]]; then
        log_self_healing "WARNING" "Uso de disco alto: $disk_usage%"

        # Limpiar archivos temporales
        find /tmp -type f -mtime +7 -delete 2>/dev/null
        find /var/tmp -type f -mtime +7 -delete 2>/dev/null

        # Limpiar cache de apt
        apt-get autoremove -y >/dev/null 2>&1
        apt-get autoclean >/dev/null 2>&1

        log_self_healing "INFO" "Limpieza de disco completada"
    fi

    # Verificar uso de memoria
    local mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    if [[ "$mem_usage" -gt 90 ]]; then
        log_self_healing "WARNING" "Uso de memoria alto: $mem_usage%"

        # Reiniciar servicios que puedan tener fugas de memoria
        systemctl restart apache2 2>/dev/null
        systemctl restart mysql 2>/dev/null
    fi
}

# Verificar logs de errores
check_error_logs() {
    local error_logs=(
        "/var/log/apache2/error.log"
        "/var/log/mysql/error.log"
        "/var/log/mail.err"
        "/var/log/webmin/miniserv.error"
        "/var/log/fail2ban.log"
    )

    for log_file in "${error_logs[@]}"; do
        if [[ -f "$log_file" ]]; then
            # Verificar errores recientes (últimos 5 minutos)
            local recent_errors=$(tail -n 50 "$log_file" 2>/dev/null | grep -i "error\|failed\|critical" | wc -l)
            if [[ "$recent_errors" -gt 10 ]]; then
                log_self_healing "WARNING" "Múltiples errores en $log_file: $recent_errors"

                # Rotar log si es muy grande
                local log_size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo "0")
                if [[ "$log_size" -gt 104857600 ]]; then  # 100MB
                    log_self_healing "INFO" "Rotando log grande: $log_file"
                    mv "$log_file" "$log_file.old" 2>/dev/null
                    touch "$log_file" 2>/dev/null
                    chmod 644 "$log_file" 2>/dev/null
                fi
            fi
        fi
    done
}

# Función de reparación de emergencia
emergency_repair() {
    log_self_healing "CRITICAL" "Ejecutando reparación de emergencia"

    # Detener servicios problemáticos
    systemctl stop apache2 2>/dev/null
    systemctl stop mysql 2>/dev/null

    # Reparar permisos críticos
    chown -R www-data:www-data /var/www 2>/dev/null
    chown -R mysql:mysql /var/lib/mysql 2>/dev/null

    # Reiniciar servicios esenciales
    systemctl start mysql 2>/dev/null
    systemctl start apache2 2>/dev/null

    log_self_healing "INFO" "Reparación de emergencia completada"
}

# Función de backup automático antes de reparaciones críticas
backup_before_repair() {
    local backup_dir="/var/backups/auto-repair-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"

    # Backup de configuraciones críticas
    cp -r /etc/webmin "$backup_dir/" 2>/dev/null
    cp -r /etc/apache2 "$backup_dir/" 2>/dev/null
    cp -r /etc/mysql "$backup_dir/" 2>/dev/null

    log_self_healing "INFO" "Backup automático creado en $backup_dir"
}

# Señal de limpieza
cleanup() {
    rm -f "$LOCK_FILE"
    log_self_healing "INFO" "Sistema de auto-reparación detenido"
}

trap cleanup EXIT

# Iniciar monitoreo
log_self_healing "INFO" "Sistema de auto-reparación inteligente iniciado"
monitor_and_repair
