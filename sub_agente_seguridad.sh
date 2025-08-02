#!/bin/bash

# Sub-Agente de Seguridad
# Realiza verificaciones automáticas de seguridad del sistema

LOG_FILE="/var/log/sub_agente_seguridad.log"
SECURITY_REPORT="/var/log/reporte_seguridad_$(date +%Y%m%d_%H%M%S).txt"
CRITICAL_ALERT_FILE="/var/log/alertas_criticas_seguridad.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_security_alert() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$CRITICAL_ALERT_FILE"
    log_message "ALERTA DE SEGURIDAD [$level]: $message"
}

check_failed_logins() {
    log_message "=== VERIFICANDO INTENTOS DE LOGIN FALLIDOS ==="
    
    FAILED_LOGINS=$(journalctl --since "24 hours ago" | grep -i "failed\|failure" | grep -E "(ssh|login|authentication)" | wc -l)
    
    if [ "$FAILED_LOGINS" -gt 50 ]; then
        log_security_alert "CRÍTICO" "Muchos intentos de login fallidos: $FAILED_LOGINS en 24h"
    elif [ "$FAILED_LOGINS" -gt 20 ]; then
        log_security_alert "ADVERTENCIA" "Intentos de login fallidos sospechosos: $FAILED_LOGINS en 24h"
    else
        log_message "Intentos de login fallidos: $FAILED_LOGINS (normal)"
    fi
    
    # Mostrar IPs con más intentos fallidos
    journalctl --since "24 hours ago" | grep -i "failed" | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | sort | uniq -c | sort -nr | head -5 | while read count ip; do
        if [ "$count" -gt 10 ]; then
            log_security_alert "ADVERTENCIA" "IP sospechosa con $count intentos fallidos: $ip"
        fi
    done
}

check_root_access() {
    log_message "=== VERIFICANDO ACCESOS ROOT ==="
    
    ROOT_LOGINS=$(journalctl --since "24 hours ago" | grep -i "root" | grep -E "(login|session)" | wc -l)
    
    if [ "$ROOT_LOGINS" -gt 0 ]; then
        log_security_alert "ADVERTENCIA" "Detectados $ROOT_LOGINS accesos root en 24h"
        journalctl --since "24 hours ago" | grep -i "root" | grep -E "(login|session)" | tail -5 >> "$LOG_FILE"
    fi
    
    # Verificar usuarios con UID 0
    USERS_UID_0=$(awk -F: '$3 == 0 {print $1}' /etc/passwd | grep -v '^root$')
    if [ -n "$USERS_UID_0" ]; then
        log_security_alert "CRÍTICO" "Usuarios adicionales con UID 0 detectados: $USERS_UID_0"
    fi
}

check_open_ports() {
    log_message "=== VERIFICANDO PUERTOS ABIERTOS ==="
    
    OPEN_PORTS=$(netstat -tuln | grep LISTEN | awk '{print $4}' | cut -d: -f2 | sort -n | uniq)
    EXPECTED_PORTS=("22" "80" "443" "10000" "20000" "25" "53" "993" "995")
    
    for port in $OPEN_PORTS; do
        if [[ ! " ${EXPECTED_PORTS[@]} " =~ " ${port} " ]]; then
            log_security_alert "ADVERTENCIA" "Puerto no esperado abierto: $port"
        fi
    done
    
    log_message "Puertos abiertos: $(echo $OPEN_PORTS | tr '\n' ' ')"
}

check_file_permissions() {
    log_message "=== VERIFICANDO PERMISOS DE ARCHIVOS CRÍTICOS ==="
    
    # Archivos que deben tener permisos específicos
    declare -A critical_files=(
        ["/etc/passwd"]="644"
        ["/etc/shadow"]="640"
        ["/etc/ssh/sshd_config"]="600"
        ["/etc/webmin/miniserv.conf"]="600"
        ["/etc/sudoers"]="440"
    )
    
    for file in "${!critical_files[@]}"; do
        if [ -f "$file" ]; then
            current_perms=$(stat -c "%a" "$file")
            expected_perms="${critical_files[$file]}"
            
            if [ "$current_perms" != "$expected_perms" ]; then
                log_security_alert "ADVERTENCIA" "Permisos incorrectos en $file: $current_perms (esperado: $expected_perms)"
            else
                log_message "✓ Permisos correctos en $file: $current_perms"
            fi
        fi
    done
    
    # Buscar archivos con permisos 777
    WORLD_WRITABLE=$(find /etc /usr/local /var/www -type f -perm 777 2>/dev/null | head -10)
    if [ -n "$WORLD_WRITABLE" ]; then
        log_security_alert "ADVERTENCIA" "Archivos con permisos 777 encontrados: $WORLD_WRITABLE"
    fi
}

check_unusual_processes() {
    log_message "=== VERIFICANDO PROCESOS INUSUALES ==="
    
    # Procesos que consumen mucha CPU
    HIGH_CPU_PROCESSES=$(ps aux --sort=-%cpu | head -10 | awk '$3 > 50 {print $11 " (" $3 "%)"}')
    if [ -n "$HIGH_CPU_PROCESSES" ]; then
        log_security_alert "ADVERTENCIA" "Procesos con alto uso de CPU: $HIGH_CPU_PROCESSES"
    fi
    
    # Procesos con nombres sospechosos
    SUSPICIOUS_NAMES=("nc" "netcat" "wget" "curl" "python -c" "perl -e" "bash -i")
    for name in "${SUSPICIOUS_NAMES[@]}"; do
        if pgrep -f "$name" >/dev/null; then
            log_security_alert "ADVERTENCIA" "Proceso sospechoso detectado: $name"
        fi
    done
    
    # Procesos ejecutándose desde /tmp o /var/tmp
    TEMP_PROCESSES=$(ps aux | grep -E "(\/tmp\/|\/var\/tmp\/)" | grep -v grep)
    if [ -n "$TEMP_PROCESSES" ]; then
        log_security_alert "ADVERTENCIA" "Procesos ejecutándose desde directorios temporales"
    fi
}

check_network_connections() {
    log_message "=== VERIFICANDO CONEXIONES DE RED ==="
    
    # Conexiones establecidas a puertos no estándar
    UNUSUAL_CONNECTIONS=$(netstat -tn | grep ESTABLISHED | awk '{print $5}' | cut -d: -f2 | sort | uniq -c | awk '$2 > 1024 && $2 < 65535 {print $2}' | head -5)
    
    if [ -n "$UNUSUAL_CONNECTIONS" ]; then
        log_security_alert "ADVERTENCIA" "Conexiones a puertos no estándar: $UNUSUAL_CONNECTIONS"
    fi
    
    # Verificar conexiones desde IPs externas
    EXTERNAL_CONNECTIONS=$(netstat -tn | grep ESTABLISHED | awk '{print $5}' | cut -d: -f1 | grep -v -E "(127\.0\.0\.1|10\.|192\.168\.|172\.)" | sort | uniq)
    
    if [ -n "$EXTERNAL_CONNECTIONS" ]; then
        log_message "Conexiones externas activas: $EXTERNAL_CONNECTIONS"
    fi
}

check_system_integrity() {
    log_message "=== VERIFICANDO INTEGRIDAD DEL SISTEMA ==="
    
    # Verificar si hay cambios en archivos críticos del sistema
    if command -v debsums >/dev/null 2>&1; then
        CHANGED_FILES=$(debsums -c 2>/dev/null | head -10)
        if [ -n "$CHANGED_FILES" ]; then
            log_security_alert "ADVERTENCIA" "Archivos del sistema modificados: $CHANGED_FILES"
        fi
    fi
    
    # Verificar montajes sospechosos
    SUSPICIOUS_MOUNTS=$(mount | grep -E "(noexec|nosuid)" | grep -v -E "(proc|sys|dev)")
    if [ -z "$SUSPICIOUS_MOUNTS" ]; then
        log_security_alert "ADVERTENCIA" "Faltan montajes con opciones de seguridad"
    fi
    
    # Verificar si el firewall está activo
    if command -v ufw >/dev/null 2>&1; then
        UFW_STATUS=$(ufw status | grep "Status:" | cut -d: -f2 | tr -d ' ')
        if [ "$UFW_STATUS" != "active" ]; then
            log_security_alert "ADVERTENCIA" "Firewall UFW no está activo"
        fi
    fi
}

check_webmin_security() {
    log_message "=== VERIFICANDO SEGURIDAD DE WEBMIN ==="
    
    WEBMIN_CONFIG="/etc/webmin/miniserv.conf"
    if [ -f "$WEBMIN_CONFIG" ]; then
        # Verificar SSL habilitado
        if ! grep -q "ssl=1" "$WEBMIN_CONFIG"; then
            log_security_alert "CRÍTICO" "SSL no está habilitado en Webmin"
        fi
        
        # Verificar acceso desde cualquier IP
        if grep -q "allow=0.0.0.0" "$WEBMIN_CONFIG"; then
            log_security_alert "ADVERTENCIA" "Webmin permite acceso desde cualquier IP"
        fi
        
        # Verificar sesiones activas de Webmin
        WEBMIN_SESSIONS=$(find /var/webmin -name "*.acl" 2>/dev/null | wc -l)
        if [ "$WEBMIN_SESSIONS" -gt 5 ]; then
            log_security_alert "ADVERTENCIA" "Muchas sesiones activas de Webmin: $WEBMIN_SESSIONS"
        fi
    fi
}

generate_security_report() {
    log_message "=== GENERANDO REPORTE DE SEGURIDAD ==="
    
    {
        echo "=== REPORTE DE SEGURIDAD DEL SISTEMA ==="
        echo "Fecha: $(date)"
        echo "Servidor: $(hostname)"
        echo "Usuario: $(whoami)"
        echo ""
        echo "=== RESUMEN DE VERIFICACIONES ==="
        echo "- Intentos de login fallidos"
        echo "- Accesos root"
        echo "- Puertos abiertos"
        echo "- Permisos de archivos críticos"
        echo "- Procesos inusuales"
        echo "- Conexiones de red"
        echo "- Integridad del sistema"
        echo "- Seguridad de Webmin"
        echo ""
        echo "=== ALERTAS CRÍTICAS RECIENTES ==="
        if [ -f "$CRITICAL_ALERT_FILE" ]; then
            tail -20 "$CRITICAL_ALERT_FILE"
        else
            echo "Sin alertas críticas"
        fi
        echo ""
        echo "=== RECOMENDACIONES ==="
        echo "1. Revisar alertas críticas inmediatamente"
        echo "2. Verificar logs de acceso regularmente"
        echo "3. Mantener el sistema actualizado"
        echo "4. Configurar firewall apropiadamente"
        echo "5. Usar autenticación de dos factores cuando sea posible"
    } > "$SECURITY_REPORT"
    
    log_message "Reporte de seguridad generado: $SECURITY_REPORT"
}

main() {
    log_message "Iniciando verificación de seguridad..."
    
    check_failed_logins
    check_root_access
    check_open_ports
    check_file_permissions
    check_unusual_processes
    check_network_connections
    check_system_integrity
    check_webmin_security
    generate_security_report
    
    log_message "Verificación de seguridad completada."
}

case "${1:-}" in
    start)
        main
        ;;
    quick)
        log_message "Ejecutando verificación rápida de seguridad..."
        check_failed_logins
        check_root_access
        check_open_ports
        ;;
    full)
        main
        ;;
    report)
        generate_security_report
        ;;
    *)
        echo "Uso: $0 {start|quick|full|report}"
        echo "  start  - Verificación completa de seguridad"
        echo "  quick  - Verificación rápida (solo aspectos críticos)"
        echo "  full   - Igual que start"
        echo "  report - Generar solo reporte"
        exit 1
        ;;
esac