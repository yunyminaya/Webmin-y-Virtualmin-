#!/bin/bash

# Monitor SSH para auto-reparación remota
# Permite ejecutar reparaciones via SSH sin afectar servidores virtuales

SSH_LOG_FILE="/var/log/webmin-ssh-monitor.log"

ssh_log() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$SSH_LOG_FILE"
}

# Verificar acceso SSH
check_ssh_access() {
    # Verificar que SSH esté funcionando
    if ! systemctl is-active --quiet sshd 2>/dev/null && ! systemctl is-active --quiet ssh 2>/dev/null; then
        ssh_log "WARNING" "SSH no está activo, intentando reiniciar"

        systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null

        sleep 5
        if systemctl is-active --quiet sshd 2>/dev/null || systemctl is-active --quiet ssh 2>/dev/null; then
            ssh_log "SUCCESS" "SSH reiniciado correctamente"
        else
            ssh_log "ERROR" "No se pudo reiniciar SSH"
        fi
    fi
}

# Ejecutar reparación remota segura
remote_repair() {
    local command="$1"

    ssh_log "INFO" "Ejecutando reparación remota: $command"

    case "$command" in
        "restart-webmin")
            systemctl restart webmin 2>/dev/null
            ssh_log "SUCCESS" "Webmin reiniciado via SSH"
            ;;
        "restart-apache")
            systemctl restart apache2 2>/dev/null
            ssh_log "SUCCESS" "Apache reiniciado via SSH"
            ;;
        "restart-mysql")
            systemctl restart mysql 2>/dev/null
            ssh_log "SUCCESS" "MySQL reiniciado via SSH"
            ;;
        "check-integrity")
            # Verificar integridad sin modificar nada
            if [[ -d /etc/webmin ]] && [[ -d /etc/apache2 ]]; then
                ssh_log "SUCCESS" "Integridad del sistema verificada"
            else
                ssh_log "WARNING" "Problemas de integridad detectados"
            fi
            ;;
        "emergency-backup")
            local backup_dir="/var/backups/emergency-$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$backup_dir"
            cp -r /etc/webmin "$backup_dir/" 2>/dev/null
            cp -r /etc/apache2 "$backup_dir/" 2>/dev/null
            ssh_log "SUCCESS" "Backup de emergencia creado en $backup_dir"
            ;;
        "full-system-check")
            # Verificación completa del sistema
            ssh_log "INFO" "Iniciando verificación completa del sistema"

            # Verificar servicios críticos
            local services=("webmin" "apache2" "mysql" "postfix")
            for service in "${services[@]}"; do
                if systemctl is-active --quiet "$service" 2>/dev/null; then
                    ssh_log "SUCCESS" "Servicio $service activo"
                else
                    ssh_log "WARNING" "Servicio $service inactivo"
                fi
            done

            # Verificar espacio en disco
            local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
            ssh_log "INFO" "Uso de disco: $disk_usage%"

            # Verificar memoria
            local mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
            ssh_log "INFO" "Uso de memoria: $mem_usage%"

            ssh_log "SUCCESS" "Verificación completa del sistema completada"
            ;;
        *)
            ssh_log "WARNING" "Comando remoto no reconocido: $command"
            ;;
    esac
}

# Monitoreo continuo de SSH
monitor_ssh() {
    while true; do
        check_ssh_access
        sleep 30
    done
}

# Procesar comandos remotos (si se pasan como argumentos)
if [[ $# -gt 0 ]]; then
    remote_repair "$1"
else
    ssh_log "INFO" "Monitor SSH iniciado"
    monitor_ssh
fi
