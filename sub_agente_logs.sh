#!/bin/bash

# Sub-Agente de Análisis y Monitoreo de Logs
# Analiza logs del sistema, detecta patrones y genera alertas

LOG_FILE="/var/log/sub_agente_logs.log"
ANALYSIS_REPORT="/var/log/analisis_logs_$(date +%Y%m%d_%H%M%S).txt"
ALERT_THRESHOLD_ERRORS=100
ALERT_THRESHOLD_WARNINGS=500

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_alert() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ALERTA-$level] $message" | tee -a "/var/log/alertas_logs.log"
    log_message "ALERTA [$level]: $message"
}

analyze_system_logs() {
    log_message "=== ANALIZANDO LOGS DEL SISTEMA ==="
    
    # Analizar syslog
    if [ -f "/var/log/syslog" ]; then
        local errors_today=$(grep "$(date +%Y-%m-%d)" /var/log/syslog | grep -i error | wc -l)
        local warnings_today=$(grep "$(date +%Y-%m-%d)" /var/log/syslog | grep -i warning | wc -l)
        
        log_message "Errores en syslog hoy: $errors_today"
        log_message "Advertencias en syslog hoy: $warnings_today"
        
        if [ "$errors_today" -gt "$ALERT_THRESHOLD_ERRORS" ]; then
            log_alert "CRÍTICO" "Muchos errores en syslog: $errors_today"
        fi
        
        if [ "$warnings_today" -gt "$ALERT_THRESHOLD_WARNINGS" ]; then
            log_alert "ADVERTENCIA" "Muchas advertencias en syslog: $warnings_today"
        fi
        
        # Buscar patrones específicos de error
        local critical_patterns=("kernel panic" "out of memory" "filesystem full" "segfault" "core dumped")
        for pattern in "${critical_patterns[@]}"; do
            local count=$(grep -i "$pattern" /var/log/syslog | grep "$(date +%Y-%m-%d)" | wc -l)
            if [ "$count" -gt 0 ]; then
                log_alert "CRÍTICO" "Patrón crítico detectado '$pattern': $count ocurrencias"
            fi
        done
    fi
}

analyze_auth_logs() {
    log_message "=== ANALIZANDO LOGS DE AUTENTICACIÓN ==="
    
    if [ -f "/var/log/auth.log" ]; then
        # Analizar intentos de login fallidos
        local failed_ssh=$(grep "$(date +%Y-%m-%d)" /var/log/auth.log | grep "Failed password" | wc -l)
        local failed_sudo=$(grep "$(date +%Y-%m-%d)" /var/log/auth.log | grep "authentication failure" | wc -l)
        local successful_logins=$(grep "$(date +%Y-%m-%d)" /var/log/auth.log | grep "Accepted password" | wc -l)
        
        log_message "Intentos SSH fallidos hoy: $failed_ssh"
        log_message "Intentos sudo fallidos hoy: $failed_sudo"
        log_message "Logins exitosos hoy: $successful_logins"
        
        if [ "$failed_ssh" -gt 50 ]; then
            log_alert "ADVERTENCIA" "Muchos intentos SSH fallidos: $failed_ssh"
        fi
        
        # IPs con más intentos fallidos
        local top_failing_ips=$(grep "$(date +%Y-%m-%d)" /var/log/auth.log | grep "Failed password" | awk '{print $11}' | sort | uniq -c | sort -nr | head -5)
        if [ -n "$top_failing_ips" ]; then
            log_message "IPs con más intentos fallidos:"
            echo "$top_failing_ips" | while read count ip; do
                if [ "$count" -gt 10 ]; then
                    log_alert "ADVERTENCIA" "IP sospechosa: $ip con $count intentos fallidos"
                fi
                log_message "  $ip: $count intentos"
            done
        fi
        
        # Logins fuera de horario normal
        local night_logins=$(grep "$(date +%Y-%m-%d)" /var/log/auth.log | grep "Accepted password" | awk '{print $3}' | grep -E "(0[0-6]:|2[2-3]:)" | wc -l)
        if [ "$night_logins" -gt 0 ]; then
            log_alert "ADVERTENCIA" "Logins fuera de horario normal: $night_logins"
        fi
    fi
}

analyze_web_logs() {
    log_message "=== ANALIZANDO LOGS WEB ==="
    
    # Apache logs
    if [ -f "/var/log/apache2/error.log" ]; then
        local apache_errors=$(grep "$(date +%Y-%m-%d)" /var/log/apache2/error.log | wc -l)
        log_message "Errores de Apache hoy: $apache_errors"
        
        if [ "$apache_errors" -gt 100 ]; then
            log_alert "ADVERTENCIA" "Muchos errores de Apache: $apache_errors"
        fi
        
        # Buscar errores críticos
        local critical_apache=$(grep "$(date +%Y-%m-%d)" /var/log/apache2/error.log | grep -i "critical\|emergency\|fatal" | wc -l)
        if [ "$critical_apache" -gt 0 ]; then
            log_alert "CRÍTICO" "Errores críticos en Apache: $critical_apache"
        fi
    fi
    
    # Nginx logs
    if [ -f "/var/log/nginx/error.log" ]; then
        local nginx_errors=$(grep "$(date +%Y-%m-%d)" /var/log/nginx/error.log | wc -l)
        log_message "Errores de Nginx hoy: $nginx_errors"
        
        if [ "$nginx_errors" -gt 100 ]; then
            log_alert "ADVERTENCIA" "Muchos errores de Nginx: $nginx_errors"
        fi
    fi
    
    # Analizar códigos de respuesta HTTP
    if [ -f "/var/log/apache2/access.log" ]; then
        local http_4xx=$(grep "$(date +%d/%b/%Y)" /var/log/apache2/access.log | awk '{print $9}' | grep "^4" | wc -l)
        local http_5xx=$(grep "$(date +%d/%b/%Y)" /var/log/apache2/access.log | awk '{print $9}' | grep "^5" | wc -l)
        
        log_message "Errores HTTP 4xx hoy: $http_4xx"
        log_message "Errores HTTP 5xx hoy: $http_5xx"
        
        if [ "$http_5xx" -gt 50 ]; then
            log_alert "ADVERTENCIA" "Muchos errores HTTP 5xx: $http_5xx"
        fi
    fi
}

analyze_database_logs() {
    log_message "=== ANALIZANDO LOGS DE BASES DE DATOS ==="
    
    # MySQL/MariaDB logs
    if [ -f "/var/log/mysql/error.log" ]; then
        local mysql_errors=$(grep "$(date +%Y-%m-%d)" /var/log/mysql/error.log | grep -i error | wc -l)
        local mysql_warnings=$(grep "$(date +%Y-%m-%d)" /var/log/mysql/error.log | grep -i warning | wc -l)
        
        log_message "Errores de MySQL hoy: $mysql_errors"
        log_message "Advertencias de MySQL hoy: $mysql_warnings"
        
        if [ "$mysql_errors" -gt 10 ]; then
            log_alert "ADVERTENCIA" "Errores en MySQL: $mysql_errors"
        fi
        
        # Buscar problemas específicos
        local connection_errors=$(grep "$(date +%Y-%m-%d)" /var/log/mysql/error.log | grep -i "connection.*failed\|too many connections" | wc -l)
        if [ "$connection_errors" -gt 0 ]; then
            log_alert "ADVERTENCIA" "Problemas de conexión MySQL: $connection_errors"
        fi
    fi
    
    # PostgreSQL logs
    if [ -d "/var/log/postgresql" ]; then
        local pg_log=$(find /var/log/postgresql -name "*.log" -type f | head -1)
        if [ -f "$pg_log" ]; then
            local pg_errors=$(grep "$(date +%Y-%m-%d)" "$pg_log" | grep -i error | wc -l)
            log_message "Errores de PostgreSQL hoy: $pg_errors"
            
            if [ "$pg_errors" -gt 10 ]; then
                log_alert "ADVERTENCIA" "Errores en PostgreSQL: $pg_errors"
            fi
        fi
    fi
}

analyze_webmin_logs() {
    log_message "=== ANALIZANDO LOGS DE WEBMIN ==="
    
    if [ -f "/usr/local/webmin/var/miniserv.log" ]; then
        local webmin_errors=$(grep "$(date +%d/%b/%Y)" /usr/local/webmin/var/miniserv.log | grep -i error | wc -l)
        local failed_logins=$(grep "$(date +%d/%b/%Y)" /usr/local/webmin/var/miniserv.log | grep "Failed login" | wc -l)
        local successful_logins=$(grep "$(date +%d/%b/%Y)" /usr/local/webmin/var/miniserv.log | grep "Successful login" | wc -l)
        
        log_message "Errores de Webmin hoy: $webmin_errors"
        log_message "Logins fallidos en Webmin hoy: $failed_logins"
        log_message "Logins exitosos en Webmin hoy: $successful_logins"
        
        if [ "$failed_logins" -gt 20 ]; then
            log_alert "ADVERTENCIA" "Muchos intentos de login fallidos en Webmin: $failed_logins"
        fi
        
        # IPs sospechosas en Webmin
        local suspicious_webmin_ips=$(grep "$(date +%d/%b/%Y)" /usr/local/webmin/var/miniserv.log | grep "Failed login" | awk '{print $1}' | sort | uniq -c | sort -nr | awk '$1 > 5 {print $2 " (" $1 " intentos)"}')
        if [ -n "$suspicious_webmin_ips" ]; then
            log_alert "ADVERTENCIA" "IPs sospechosas en Webmin: $suspicious_webmin_ips"
        fi
    fi
}

analyze_mail_logs() {
    log_message "=== ANALIZANDO LOGS DE CORREO ==="
    
    if [ -f "/var/log/mail.log" ]; then
        local mail_errors=$(grep "$(date +%Y-%m-%d)" /var/log/mail.log | grep -i error | wc -l)
        local rejected_mails=$(grep "$(date +%Y-%m-%d)" /var/log/mail.log | grep -i "reject\|bounce" | wc -l)
        local sent_mails=$(grep "$(date +%Y-%m-%d)" /var/log/mail.log | grep "status=sent" | wc -l)
        
        log_message "Errores de correo hoy: $mail_errors"
        log_message "Correos rechazados hoy: $rejected_mails"
        log_message "Correos enviados hoy: $sent_mails"
        
        if [ "$mail_errors" -gt 50 ]; then
            log_alert "ADVERTENCIA" "Muchos errores de correo: $mail_errors"
        fi
        
        # Detectar intentos de spam
        local spam_attempts=$(grep "$(date +%Y-%m-%d)" /var/log/mail.log | grep -i "spam\|blocked" | wc -l)
        if [ "$spam_attempts" -gt 100 ]; then
            log_alert "ADVERTENCIA" "Muchos intentos de spam detectados: $spam_attempts"
        fi
    fi
}

analyze_performance_logs() {
    log_message "=== ANALIZANDO LOGS DE RENDIMIENTO ==="
    
    # Analizar logs de journalctl para problemas de rendimiento
    local memory_issues=$(journalctl --since "24 hours ago" | grep -i "out of memory\|memory pressure" | wc -l)
    local disk_issues=$(journalctl --since "24 hours ago" | grep -i "no space left\|disk full" | wc -l)
    local cpu_issues=$(journalctl --since "24 hours ago" | grep -i "cpu.*stall\|soft lockup" | wc -l)
    
    log_message "Problemas de memoria en 24h: $memory_issues"
    log_message "Problemas de disco en 24h: $disk_issues"
    log_message "Problemas de CPU en 24h: $cpu_issues"
    
    if [ "$memory_issues" -gt 0 ]; then
        log_alert "CRÍTICO" "Problemas de memoria detectados: $memory_issues"
    fi
    
    if [ "$disk_issues" -gt 0 ]; then
        log_alert "CRÍTICO" "Problemas de espacio en disco: $disk_issues"
    fi
    
    if [ "$cpu_issues" -gt 0 ]; then
        log_alert "CRÍTICO" "Problemas de CPU detectados: $cpu_issues"
    fi
}

detect_security_patterns() {
    log_message "=== DETECTANDO PATRONES DE SEGURIDAD ==="
    
    # Buscar patrones de ataque conocidos en todos los logs
    local security_patterns=(
        "sql injection"
        "script injection"
        "directory traversal"
        "buffer overflow"
        "privilege escalation"
        "brute force"
        "ddos"
        "malware"
        "rootkit"
    )
    
    local total_security_events=0
    
    for pattern in "${security_patterns[@]}"; do
        local count=$(journalctl --since "24 hours ago" | grep -i "$pattern" | wc -l)
        if [ "$count" -gt 0 ]; then
            log_alert "CRÍTICO" "Patrón de seguridad detectado '$pattern': $count ocurrencias"
            total_security_events=$((total_security_events + count))
        fi
    done
    
    if [ "$total_security_events" -gt 0 ]; then
        log_alert "CRÍTICO" "Total de eventos de seguridad detectados: $total_security_events"
    else
        log_message "No se detectaron patrones de seguridad sospechosos"
    fi
}

generate_log_statistics() {
    log_message "=== GENERANDO ESTADÍSTICAS DE LOGS ==="
    
    local stats_file="/var/log/estadisticas_logs_$(date +%Y%m%d).txt"
    
    {
        echo "=== ESTADÍSTICAS DIARIAS DE LOGS ==="
        echo "Fecha: $(date)"
        echo ""
        echo "=== TAMAÑOS DE LOGS ==="
        find /var/log -name "*.log" -type f -exec ls -lh {} \; | awk '{print $9 " - " $5}' | sort
        echo ""
        echo "=== CRECIMIENTO DE LOGS ==="
        find /var/log -name "*.log" -type f -newer /var/log/estadisticas_logs_$(date -d yesterday +%Y%m%d).txt 2>/dev/null | wc -l
        echo ""
        echo "=== LOGS MÁS ACTIVOS ==="
        find /var/log -name "*.log" -type f -exec wc -l {} \; | sort -nr | head -10
    } > "$stats_file"
    
    log_message "Estadísticas de logs generadas: $stats_file"
}

rotate_old_logs() {
    log_message "=== ROTANDO LOGS ANTIGUOS ==="
    
    # Comprimir logs de más de 7 días
    find /var/log -name "*.log" -type f -mtime +7 ! -name "*.gz" -exec gzip {} \;
    
    # Eliminar logs comprimidos de más de 30 días
    find /var/log -name "*.log.gz" -type f -mtime +30 -delete
    
    # Limpiar logs propios del agente
    find /var/log -name "sub_agente_*.log" -type f -mtime +30 -delete
    find /var/log -name "analisis_logs_*.txt" -type f -mtime +30 -delete
    
    log_message "Rotación de logs completada"
}

generate_analysis_report() {
    log_message "=== GENERANDO REPORTE DE ANÁLISIS ==="
    
    {
        echo "=== REPORTE DE ANÁLISIS DE LOGS ==="
        echo "Fecha: $(date)"
        echo "Servidor: $(hostname)"
        echo ""
        echo "=== RESUMEN DE ANÁLISIS ==="
        echo "Logs analizados:"
        echo "- Sistema (syslog, auth.log)"
        echo "- Web (Apache, Nginx)"
        echo "- Bases de datos (MySQL, PostgreSQL)"
        echo "- Webmin/Virtualmin"
        echo "- Correo electrónico"
        echo "- Rendimiento del sistema"
        echo ""
        echo "=== ALERTAS CRÍTICAS DEL DÍA ==="
        if [ -f "/var/log/alertas_logs.log" ]; then
            grep "$(date +%Y-%m-%d)" /var/log/alertas_logs.log | tail -20
        else
            echo "Sin alertas críticas"
        fi
        echo ""
        echo "=== ESTADÍSTICAS PRINCIPALES ==="
        echo "Total de logs analizados: $(find /var/log -name "*.log" -type f | wc -l)"
        echo "Espacio total usado por logs: $(du -sh /var/log | cut -f1)"
        echo "Logs rotados hoy: $(find /var/log -name "*.gz" -type f -mtime -1 | wc -l)"
        echo ""
        echo "=== RECOMENDACIONES ==="
        echo "1. Revisar alertas críticas inmediatamente"
        echo "2. Monitorear patrones de acceso sospechosos"
        echo "3. Verificar espacio disponible para logs"
        echo "4. Actualizar reglas de detección según sea necesario"
    } > "$ANALYSIS_REPORT"
    
    log_message "Reporte de análisis generado: $ANALYSIS_REPORT"
}

main() {
    log_message "Iniciando análisis de logs..."
    
    analyze_system_logs
    analyze_auth_logs
    analyze_web_logs
    analyze_database_logs
    analyze_webmin_logs
    analyze_mail_logs
    analyze_performance_logs
    detect_security_patterns
    generate_log_statistics
    rotate_old_logs
    generate_analysis_report
    
    log_message "Análisis de logs completado."
}

case "${1:-}" in
    start|full)
        main
        ;;
    security)
        analyze_auth_logs
        detect_security_patterns
        ;;
    performance)
        analyze_performance_logs
        ;;
    web)
        analyze_web_logs
        ;;
    database)
        analyze_database_logs
        ;;
    system)
        analyze_system_logs
        ;;
    webmin)
        analyze_webmin_logs
        ;;
    stats)
        generate_log_statistics
        ;;
    rotate)
        rotate_old_logs
        ;;
    report)
        generate_analysis_report
        ;;
    *)
        echo "Uso: $0 {start|full|security|performance|web|database|system|webmin|stats|rotate|report}"
        echo "  start/full - Análisis completo de logs"
        echo "  security   - Solo análisis de seguridad"
        echo "  performance - Solo análisis de rendimiento"
        echo "  web        - Solo logs web (Apache/Nginx)"
        echo "  database   - Solo logs de bases de datos"
        echo "  system     - Solo logs del sistema"
        echo "  webmin     - Solo logs de Webmin"
        echo "  stats      - Generar estadísticas de logs"
        echo "  rotate     - Rotar logs antiguos"
        echo "  report     - Generar reporte de análisis"
        exit 1
        ;;
esac