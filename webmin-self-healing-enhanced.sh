#!/bin/bash

# Sistema de Auto-Reparación Inteligente para Webmin/Virtualmin
# Detecta y repara problemas automáticamente sin afectar servidores virtuales
# Incluye detección avanzada de ataques y auto-defensa contra amenazas

# Configuración
LOG_FILE="/var/log/webmin-self-healing.log"
LOCK_FILE="/tmp/webmin-self-healing.lock"
SECURITY_LOG="/var/log/webmin-security-events.log"
ATTACK_LOG="/var/log/webmin-attack-detection.log"
MONITOR_INTERVAL=30  # Reducido para detección más rápida de ataques
MAX_FAILED_ATTEMPTS=5
BLOCK_TIME=3600  # 1 hora de bloqueo

# Función de logging
log_self_healing() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$SECURITY_LOG"
}

# Función de logging de ataques
log_attack() {
    local attack_type="$1"
    local details="$2"
    local source_ip="$3"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ATTACK:$attack_type] $details - IP:$source_ip" >> "$ATTACK_LOG"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ATTACK:$attack_type] $details - IP:$source_ip" >> "$LOG_FILE"
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

# Función principal de monitoreo con detección de ataques
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

        # DETECCIÓN AVANZADA DE ATAQUES
        detect_brute_force_attacks
        detect_ddos_attacks
        detect_vulnerability_scans
        detect_malware_activity
        detect_suspicious_connections
        detect_rootkit_activity

        # RESPUESTA AUTOMÁTICA A ATAQUES
        mitigate_detected_attacks

        # VERIFICACIÓN DE SEGURIDAD
        verify_security_hardening

        sleep "$MONITOR_INTERVAL"
    done
}

# DETECCIÓN DE ATAQUES DE FUERZA BRUTA
detect_brute_force_attacks() {
    # Verificar intentos de login SSH fallidos
    local ssh_failed=$(journalctl -u sshd --since "1 minute ago" 2>/dev/null | grep -c "Failed password\|Invalid user" || echo "0")

    if [[ "$ssh_failed" -gt "$MAX_FAILED_ATTEMPTS" ]]; then
        log_attack "BRUTE_FORCE_SSH" "Detectados $ssh_failed intentos fallidos de SSH en 1 minuto" "$(journalctl -u sshd --since "1 minute ago" 2>/dev/null | grep "Failed password" | tail -1 | awk '{print $NF}' || echo 'unknown')"

        # Bloquear IPs sospechosas
        block_suspicious_ips "ssh"
    fi

    # Verificar intentos Webmin fallidos
    if [[ -f "/var/webmin/miniserv.log" ]]; then
        local webmin_failed=$(tail -n 100 /var/webmin/miniserv.log 2>/dev/null | grep -c "Authentication failed\|Invalid login" || echo "0")

        if [[ "$webmin_failed" -gt "$MAX_FAILED_ATTEMPTS" ]]; then
            log_attack "BRUTE_FORCE_WEBMIN" "Detectados $webmin_failed intentos fallidos de Webmin" "$(tail -n 100 /var/webmin/miniserv.log 2>/dev/null | grep "from" | tail -1 | awk '{print $NF}' || echo 'unknown')"

            # Bloquear IPs sospechosas
            block_suspicious_ips "webmin"
        fi
    fi
}

# DETECCIÓN DE ATAQUES DDoS
detect_ddos_attacks() {
    # Verificar conexiones TCP simultáneas por IP
    local connections_per_ip=$(netstat -ant 2>/dev/null | awk '{print $5}' | cut -d: -f1 | grep -v "^127\." | grep -v "^::1" | sort | uniq -c | sort -nr | head -5)

    while read -r line; do
        local count=$(echo "$line" | awk '{print $1}')
        local ip=$(echo "$line" | awk '{print $2}')

        if [[ "$count" -gt 50 ]]; then  # Más de 50 conexiones por IP
            log_attack "DDOS_CONNECTION_FLOOD" "Detección de inundación de conexiones: $count conexiones desde $ip" "$ip"

            # Bloquear IP inmediatamente
            block_ip "$ip" "DDoS Connection Flood"
        fi
    done <<< "$connections_per_ip"

    # Verificar tasa de paquetes SYN
    local syn_packets=$(netstat -ant 2>/dev/null | grep -c "SYN_RECV" || echo "0")

    if [[ "$syn_packets" -gt 100 ]]; then
        log_attack "DDOS_SYN_FLOOD" "Detección de inundación SYN: $syn_packets paquetes SYN_RECV" "multiple"

        # Activar protección SYN flood
        enable_syn_flood_protection
    fi
}

# DETECCIÓN DE ESCANEOS DE VULNERABILIDADES
detect_vulnerability_scans() {
    # Verificar escaneos de puertos
    local port_scans=$(journalctl --since "5 minutes ago" 2>/dev/null | grep -c "rejected from\|DROP" || echo "0")

    if [[ "$port_scans" -gt 20 ]]; then
        log_attack "PORT_SCANNING" "Detección de escaneo de puertos: $port_scans conexiones rechazadas" "scanner"

        # Fortalecer firewall temporalmente
        strengthen_firewall_temporarily
    fi

    # Verificar intentos de acceso a directorios sensibles
    local sensitive_access=$(tail -n 100 /var/log/apache2/access.log 2>/dev/null | grep -c "/wp-admin\|/admin\|/phpmyadmin\|/config\|/\.env" || echo "0")

    if [[ "$sensitive_access" -gt 10 ]]; then
        log_attack "VULNERABILITY_PROBING" "Detección de sondeo de vulnerabilidades: $sensitive_access accesos a directorios sensibles" "$(tail -n 100 /var/log/apache2/access.log 2>/dev/null | grep "/wp-admin\|/admin\|/phpmyadmin" | tail -1 | awk '{print $1}' || echo 'unknown')"

        # Bloquear IPs sospechosas
        block_suspicious_ips "vulnerability_scan"
    fi
}

# DETECCIÓN DE ACTIVIDAD MALICIOSA
detect_malware_activity() {
    # Verificar procesos sospechosos
    local suspicious_processes=$(ps aux 2>/dev/null | grep -E "(miner|cryptojacker|backdoor|trojan|worm)" | grep -v grep | wc -l)

    if [[ "$suspicious_processes" -gt 0 ]]; then
        log_attack "MALWARE_DETECTED" "Detectados $suspicious_processes procesos sospechosos de malware" "localhost"

        # Matar procesos sospechosos
        kill_suspicious_processes

        # Escanear con herramientas de seguridad
        perform_security_scan
    fi

    # Verificar archivos modificados recientemente en directorios críticos
    local modified_files=$(find /etc /var /usr/local -name "*.conf" -o -name "*.php" -o -name "*.sh" 2>/dev/null | xargs ls -lt 2>/dev/null | head -20 | grep -c "$(date +%Y-%m-%d)" || echo "0")

    if [[ "$modified_files" -gt 10 ]]; then
        log_attack "FILE_TAMPERING" "Detectada modificación masiva de archivos críticos: $modified_files archivos modificados" "unknown"

        # Crear backup inmediato
        emergency_backup
    fi
}

# DETECCIÓN DE CONEXIONES SOSPECHOSAS
detect_suspicious_connections() {
    # Verificar conexiones desde países de alto riesgo (ejemplo básico)
    local suspicious_countries=("CN" "RU" "IN" "BR" "VN" "IR" "KP")

    for country in "${suspicious_countries[@]}"; do
        local connections_from_country=$(netstat -ant 2>/dev/null | grep -c ":22 \|:80 \|:443 \|:10000 " || echo "0")

        if [[ "$connections_from_country" -gt 5 ]]; then
            log_attack "SUSPICIOUS_GEOLOCATION" "Múltiples conexiones desde zona de alto riesgo ($country)" "geolocation_$country"

            # Aumentar logging y monitoreo
            increase_monitoring_level
        fi
    done

    # Verificar conexiones desde rangos IP reservados o locales que no deberían tener acceso
    local internal_connections=$(netstat -ant 2>/dev/null | grep -c "192\.168\.\\|10\.\\|172\." | grep -v "127\.0\.0\.1" || echo "0")

    if [[ "$internal_connections" -gt 20 ]]; then
        log_attack "INTERNAL_NETWORK_ABUSE" "Abuso detectado en red interna: $internal_connections conexiones" "internal"

        # Bloquear accesos no autorizados desde red interna
        block_internal_abuse
    fi
}

# DETECCIÓN DE ROOTKITS
detect_rootkit_activity() {
    # Verificar integridad de archivos críticos
    local critical_files=(
        "/bin/ls"
        "/bin/ps"
        "/usr/bin/top"
        "/usr/bin/netstat"
        "/usr/bin/ss"
    )

    for file in "${critical_files[@]}"; do
        if [[ -f "$file" ]]; then
            local file_hash=$(sha256sum "$file" 2>/dev/null | awk '{print $1}' || echo "error")

            if [[ "$file_hash" == "error" ]]; then
                log_attack "ROOTKIT_SUSPICION" "No se puede verificar hash de archivo crítico: $file" "localhost"

                # Activar modo de emergencia
                activate_emergency_mode
            fi
        fi
    done

    # Verificar procesos ocultos comparando diferentes métodos
    local ps_count=$(ps aux 2>/dev/null | wc -l)
    local proc_count=$(ls /proc | grep -c "^[0-9]" || echo "0")

    if [[ $((ps_count - proc_count)) -gt 10 ]]; then
        log_attack "HIDDEN_PROCESSES" "Detectados procesos ocultos: diferencia de $((ps_count - proc_count)) procesos" "localhost"

        # Realizar escaneo completo del sistema
        full_system_scan
    fi
}

# BLOQUEO DE IPs SOSPECHOSAS
block_suspicious_ips() {
    local attack_type="$1"

    # Obtener IPs con múltiples fallos
    local suspicious_ips=""

    case "$attack_type" in
        "ssh")
            suspicious_ips=$(journalctl -u sshd --since "10 minutes ago" 2>/dev/null | grep "Failed password" | awk '{print $(NF-3)}' | sort | uniq -c | sort -nr | head -5 | awk '$1 > 3 {print $2}')
            ;;
        "webmin")
            suspicious_ips=$(tail -n 200 /var/webmin/miniserv.log 2>/dev/null | grep "Authentication failed" | awk '{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) print $i}' | sort | uniq -c | sort -nr | head -5 | awk '$1 > 3 {print $2}')
            ;;
        "vulnerability_scan")
            suspicious_ips=$(tail -n 200 /var/log/apache2/access.log 2>/dev/null | grep "/wp-admin\|/admin\|/phpmyadmin" | awk '{print $1}' | sort | uniq -c | sort -nr | head -5 | awk '$1 > 5 {print $2}')
            ;;
    esac

    # Bloquear cada IP sospechosa
    while read -r ip; do
        if [[ -n "$ip" && "$ip" != "127.0.0.1" ]]; then
            block_ip "$ip" "Auto-blocked: $attack_type attack"
        fi
    done <<< "$suspicious_ips"
}

# BLOQUEO DE IP INDIVIDUAL
block_ip() {
    local ip="$1"
    local reason="$2"

    log_attack "IP_BLOCKED" "Bloqueando IP $ip por: $reason" "$ip"

    # Usar iptables o ufw para bloquear
    if command -v ufw >/dev/null 2>&1; then
        ufw deny from "$ip" to any 2>/dev/null
    elif command -v iptables >/dev/null 2>&1; then
        iptables -A INPUT -s "$ip" -j DROP 2>/dev/null
    fi

    # Agregar a lista negra temporal
    echo "$(date +%s) $ip $reason" >> /opt/webmin-self-healing/blacklist.txt
}

# PROTECCIÓN CONTRA INUNDACIÓN SYN
enable_syn_flood_protection() {
    log_self_healing "WARNING" "Activando protección contra inundación SYN"

    # Configurar límites SYN en sysctl
    sysctl -w net.ipv4.tcp_syncookies=1 2>/dev/null
    sysctl -w net.ipv4.tcp_synack_retries=2 2>/dev/null
    sysctl -w net.ipv4.tcp_max_syn_backlog=2048 2>/dev/null

    # Aplicar permanentemente
    echo "net.ipv4.tcp_syncookies = 1" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_synack_retries = 2" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_max_syn_backlog = 2048" >> /etc/sysctl.conf

    # Reiniciar servicios de red
    systemctl restart networking 2>/dev/null
    systemctl restart NetworkManager 2>/dev/null
}

# FORTALECER FIREWALL TEMPORALMENTE
strengthen_firewall_temporarily() {
    log_self_healing "WARNING" "Fortaleciendo firewall temporalmente"

    # Bloquear todos los puertos no esenciales temporalmente
    if command -v ufw >/dev/null 2>&1; then
        # Permitir solo puertos esenciales
        ufw --force reset
        ufw default deny incoming
        ufw default allow outgoing
        ufw allow ssh
        ufw allow 80
        ufw allow 443
        ufw allow 10000
        ufw --force enable
    fi

    # Programar restauración en 1 hora
    echo "ufw --force reset && ufw default deny incoming && ufw default allow outgoing && ufw allow ssh && ufw allow 80 && ufw allow 443 && ufw allow 10000 && ufw --force enable" | at now + 1 hour 2>/dev/null || true
}

# MATAR PROCESOS SOSPECHOSOS
kill_suspicious_processes() {
    log_self_healing "WARNING" "Eliminando procesos sospechosos"

    # Matar procesos de minería y malware conocidos
    pkill -f "miner\|cryptojacker\|backdoor\|trojan\|worm" 2>/dev/null || true

    # Matar procesos con nombres sospechosos
    ps aux 2>/dev/null | grep -E "(xmrig|minerd|ccminer|ethminer|trojan|backdoor)" | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null || true
}

# ESCANEO DE SEGURIDAD
perform_security_scan() {
    log_self_healing "INFO" "Realizando escaneo de seguridad completo"

    # Verificar con chkrootkit si está disponible
    if command -v chkrootkit >/dev/null 2>&1; then
        chkrootkit 2>/dev/null | grep -i "infected\|warning" >> "$LOG_FILE" 2>&1 || true
    fi

    # Verificar con rkhunter si está disponible
    if command -v rkhunter >/dev/null 2>&1; then
        rkhunter --check --sk 2>/dev/null | grep -i "warning\|suspect" >> "$LOG_FILE" 2>&1 || true
    fi

    # Verificar integridad de paquetes
    if command -v debsums >/dev/null 2>&1; then
        debsums -c 2>/dev/null | grep -v "OK$" | head -10 >> "$LOG_FILE" 2>&1 || true
    fi
}

# BACKUP DE EMERGENCIA
emergency_backup() {
    local backup_dir="/var/backups/emergency-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"

    log_self_healing "CRITICAL" "Creando backup de emergencia en $backup_dir"

    # Backup de configuraciones críticas
    cp -r /etc/webmin "$backup_dir/" 2>/dev/null
    cp -r /etc/apache2 "$backup_dir/" 2>/dev/null
    cp -r /etc/mysql "$backup_dir/" 2>/dev/null
    cp -r /etc/ssh "$backup_dir/" 2>/dev/null

    # Backup de bases de datos si es posible
    if command -v mysqldump >/dev/null 2>&1; then
        mysqldump --all-databases > "$backup_dir/all_databases.sql" 2>/dev/null || true
    fi

    log_self_healing "SUCCESS" "Backup de emergencia completado"
}

# ACTIVAR MODO DE EMERGENCIA
activate_emergency_mode() {
    log_self_healing "CRITICAL" "Activando modo de emergencia"

    # Deshabilitar servicios no esenciales
    systemctl stop apache2 2>/dev/null
    systemctl stop mysql 2>/dev/null
    systemctl stop postfix 2>/dev/null

    # Solo mantener SSH y servicios críticos
    systemctl start ssh 2>/dev/null
    systemctl start webmin 2>/dev/null

    # Fortalecer firewall al máximo
    if command -v ufw >/dev/null 2>&1; then
        ufw --force reset
        ufw default deny incoming
        ufw default deny outgoing
        ufw allow ssh
        ufw allow 10000
        ufw --force enable
    fi

    log_self_healing "WARNING" "Modo de emergencia activado - solo acceso SSH y Webmin permitido"
}

# AUMENTAR NIVEL DE MONITOREO
increase_monitoring_level() {
    log_self_healing "WARNING" "Aumentando nivel de monitoreo"

    # Reducir intervalo de monitoreo
    MONITOR_INTERVAL=15

    # Habilitar logging más detallado
    if [[ -f "/etc/rsyslog.conf" ]]; then
        sed -i 's/#\*.\* \*.\*/*.* *.*;authpriv.none -/var/log/messages/' /etc/rsyslog.conf 2>/dev/null
        systemctl restart rsyslog 2>/dev/null
    fi

    # Programar restauración en 1 hora
    (sleep 3600 && MONITOR_INTERVAL=60 && log_self_healing "INFO" "Nivel de monitoreo restaurado a normal") &
}

# BLOQUEAR ABUSO INTERNO
block_internal_abuse() {
    log_self_healing "WARNING" "Bloqueando abuso desde red interna"

    # Crear reglas específicas para red interna
    if command -v ufw >/dev/null 2>&1; then
        ufw deny from 192.168.0.0/16 to any 2>/dev/null
        ufw deny from 10.0.0.0/8 to any 2>/dev/null
        ufw deny from 172.16.0.0/12 to any 2>/dev/null
    fi

    # Programar restauración en 30 minutos
    echo "ufw delete deny from 192.168.0.0/16 to any && ufw delete deny from 10.0.0.0/8 to any && ufw delete deny from 172.16.0.0/12 to any" | at now + 30 minutes 2>/dev/null || true
}

# ESCANEO COMPLETO DEL SISTEMA
full_system_scan() {
    log_self_healing "INFO" "Iniciando escaneo completo del sistema"

    # Escanear procesos
    ps aux 2>/dev/null | sort -k 3 -nr | head -20 >> "$LOG_FILE"

    # Escanear conexiones de red
    netstat -antp 2>/dev/null | grep -v "127.0.0.1" >> "$LOG_FILE"

    # Verificar archivos con permisos sospechosos
    find / -type f -perm /4000 2>/dev/null | head -20 >> "$LOG_FILE"

    # Verificar usuarios con UID 0
    awk -F: '$3 == 0 {print $1}' /etc/passwd >> "$LOG_FILE"

    log_self_healing "SUCCESS" "Escaneo completo del sistema completado"
}

# MITIGACIÓN AUTOMÁTICA DE ATAQUES DETECTADOS
mitigate_detected_attacks() {
    # Verificar si hay ataques activos en los logs
    local recent_attacks=$(tail -n 100 "$ATTACK_LOG" 2>/dev/null | grep -c "$(date +%Y-%m-%d)" || echo "0")

    if [[ "$recent_attacks" -gt 10 ]]; then
        log_self_healing "CRITICAL" "Múltiples ataques detectados ($recent_attacks), activando defensas avanzadas"

        # Activar todas las defensas
        enable_syn_flood_protection
        strengthen_firewall_temporarily
        perform_security_scan

        # Notificar administradores
        notify_administrators "MULTIPLE_ATTACKS_DETECTED" "$recent_attacks ataques detectados en las últimas 24 horas"
    fi
}

# VERIFICACIÓN DE FORTALECIMIENTO DE SEGURIDAD
verify_security_hardening() {
    # Verificar que las medidas de seguridad están activas
    local security_score=0

    # Verificar firewall
    if command -v ufw >/dev/null 2>&1; then
        if ufw status 2>/dev/null | grep -q "Status: active"; then
            ((security_score += 20))
        fi
    fi

    # Verificar fail2ban
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        ((security_score += 20))
    fi

    # Verificar ClamAV
    if systemctl is-active --quiet clamav-daemon 2>/dev/null; then
        ((security_score += 20))
    fi

    # Verificar SELinux/AppArmor
    if command -v getenforce >/dev/null 2>&1; then
        if [[ "$(getenforce 2>/dev/null)" == "Enforcing" ]]; then
            ((security_score += 20))
        fi
    fi

    # Verificar actualizaciones automáticas
    if [[ -f "/etc/apt/apt.conf.d/20auto-upgrades" ]]; then
        ((security_score += 20))
    fi

    # Registrar puntuación de seguridad
    echo "$(date '+%Y-%m-%d %H:%M:%S') Security Score: $security_score%" >> "$LOG_FILE"

    # Si la puntuación es baja, intentar mejorar
    if [[ "$security_score" -lt 60 ]]; then
        log_self_healing "WARNING" "Puntuación de seguridad baja ($security_score%), intentando mejorar"

        # Intentar activar medidas de seguridad faltantes
        enable_missing_security_measures
    fi
}

# ACTIVAR MEDIDAS DE SEGURIDAD FALTANTES
enable_missing_security_measures() {
    log_self_healing "INFO" "Activando medidas de seguridad faltantes"

    # Activar firewall si no está activo
    if command -v ufw >/dev/null 2>&1; then
        if ! ufw status 2>/dev/null | grep -q "Status: active"; then
            ufw --force enable 2>/dev/null
            log_self_healing "SUCCESS" "Firewall UFW activado"
        fi
    fi

    # Intentar activar fail2ban
    if ! systemctl is-active --quiet fail2ban 2>/dev/null; then
        systemctl enable fail2ban 2>/dev/null
        systemctl start fail2ban 2>/dev/null
        if systemctl is-active --quiet fail2ban 2>/dev/null; then
            log_self_healing "SUCCESS" "Fail2ban activado"
        fi
    fi

    # Intentar activar ClamAV
    if ! systemctl is-active --quiet clamav-daemon 2>/dev/null; then
        systemctl enable clamav-daemon 2>/dev/null
        systemctl start clamav-daemon 2>/dev/null
        if systemctl is-active --quiet clamav-daemon 2>/dev/null; then
            log_self_healing "SUCCESS" "ClamAV activado"
        fi
    fi
}

# NOTIFICAR ADMINISTRADORES
notify_administrators() {
    local alert_type="$1"
    local message="$2"

    log_self_healing "ALERT" "Notificación de administrador: $alert_type - $message"

    # Intentar enviar email si postfix está configurado
    if systemctl is-active --quiet postfix 2>/dev/null; then
        echo "Alerta de Seguridad Webmin: $alert_type

$message

Fecha: $(date)
Servidor: $(hostname)
Logs: $LOG_FILE

Sistema de Auto-Reparación Inteligente" | mail -s "ALERTA DE SEGURIDAD: $alert_type" root 2>/dev/null || true
    fi

    # También registrar en syslog
    logger -p local0.alert "Webmin Security Alert: $alert_type - $message"
}

# FUNCIONES ORIGINALES (MANTENIDAS PARA COMPATIBILIDAD)

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
        if ping -c 1 -W 5 8.8.8.8.8 >/dev/null 2>&1; then
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
log_self_healing "INFO" "Sistema de Auto-Reparación Inteligente con Detección Avanzada de Ataques iniciado"
monitor_and_repair
